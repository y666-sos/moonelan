///|
/// EAF reuses the ecosystem XML reader; DTDs are rejected before expansion.
priv struct XmlNode {
  element : @xml.XmlElement
  children : Array[XmlNode]
  text : StringBuilder
}

///|
fn attribute(n : XmlNode, key : String) -> String? {
  n.element.get(key)
}

///|
fn required(n : XmlNode, key : String) -> String raise EafError {
  match attribute(n, key) {
    Some(s) => {
      guard !s.is_empty() else {
        raise Invalid("empty required attribute \{key}")
      }
      s
    }
    None => raise Invalid("missing attribute \{key}")
  }
}

///|
fn xml_tree(text : String, limits : Limits) -> XmlNode raise EafError {
  guard limits.input_units > 0 && limits.nodes > 0 && limits.depth > 0 else {
    raise Budget("invalid XML limits")
  }
  guard text.length() <= limits.input_units else {
    raise Budget("XML input too large")
  }
  reject_dtd(text)
  let reader = @xml.Reader::from_string(text)
  let stack : Array[XmlNode] = []
  let roots : Array[XmlNode] = []
  let mut count = 0
  while true {
    let ev = reader.read_event() catch { _ => raise Xml("malformed XML") }
    count += 1
    guard count <= limits.nodes else {
      raise Budget("XML node/event budget exceeded")
    }
    match ev.kind {
      @xml.Start(e) | @xml.Empty(e) => {
        guard !e.name.contains(":") else {
          raise Unsupported("namespaced EAF elements")
        }
        let n = XmlNode::{ element: e, children: [], text: StringBuilder(), }
        if stack.is_empty() {
          roots.push(n)
        } else {
          stack[stack.length() - 1].children.push(n)
        }
        if ev.kind is @xml.Start(_) {
          stack.push(n)
        }
        guard stack.length() + (if ev.kind is @xml.Empty(_) { 1 } else { 0 }) <=
          limits.depth else {
          raise Budget("XML nesting too deep")
        }
      }
      @xml.End(_) => ignore(stack.pop())
      @xml.Text(s) | @xml.CData(s) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(s)
        } else {
          guard xml_space(s) else { raise Xml("text outside root") }
        }
      @xml.DocType(_) => raise Unsupported("DTD")
      @xml.Decl(encoding~, ..) =>
        match encoding {
          Some(enc) => {
            guard enc == "UTF-8" || enc == "utf-8" else {
              raise Unsupported("XML encoding; supply decoded UTF-8")
            }
          }
          None => ()
        }
      @xml.Eof => break
      _ => ()
    }
  }
  guard roots.length() == 1 else { raise Invalid("expected one document root") }
  roots[0]
}

///|
fn attrs_only(n : XmlNode, allowed : Array[String]) -> Unit raise EafError {
  for a in n.element.attributes {
    guard allowed.contains(a.name) else {
      raise Unsupported("attribute \{a.name}")
    }
  }
}

///|
fn structural(n : XmlNode) -> Unit raise EafError {
  guard n.text.to_string().trim().is_empty() else {
    raise Invalid("text outside ANNOTATION_VALUE or PROPERTY")
  }
}

///|
fn leaf(n : XmlNode) -> Unit raise EafError {
  guard n.children.is_empty() else {
    raise Invalid("nested content in leaf element")
  }
}

///|
fn parse_milliseconds(s : String) -> Int64 raise EafError {
  let value = parse_signed_milliseconds(s)
  guard value >= 0L && value <= 4294967295L else {
    raise Invalid("TIME_VALUE outside xsd:unsignedInt")
  }
  value
}

///|
/// Public structural probe for editors that need root recognition before import.
pub fn is_eaf_xml(text : String) -> Bool {
  try {
    let n = xml_tree(text, default_limits())
    attrs_only(n, [
      "AUTHOR", "DATE", "FORMAT", "VERSION", "xmlns:xsi", "xsi:noNamespaceSchemaLocation",
    ])
    structural(n)
    n.element.name == "ANNOTATION_DOCUMENT"
  } catch {
    _ => false
  }
}

///|
fn parse_boolean(value : String) -> Bool raise EafError {
  match value {
    "true" | "1" => true
    "false" | "0" => false
    _ => raise Invalid("invalid boolean")
  }
}

///|
fn parse_signed_milliseconds(value : String) -> Int64 raise EafError {
  let cs = schema_token(value).to_array()
  guard !cs.is_empty() else { raise Invalid("empty signed time") }
  let negative = cs[0] == '-'
  let start = if negative || cs[0] == '+' { 1 } else { 0 }
  guard start < cs.length() else { raise Invalid("invalid signed time") }
  // Accumulate negatively so MIN_INT64 is representable without negation overflow.
  let limit = if negative {
    -9223372036854775808L
  } else {
    -9223372036854775807L
  }
  let mut n = 0L
  for i = start; i < cs.length(); i = i + 1 {
    guard cs[i].is_ascii_digit() else {
      raise Invalid("nondecimal signed time")
    }
    let digit = (cs[i].to_int() - 48).to_int64()
    guard n >= limit / 10L else { raise Invalid("signed time overflow") }
    n *= 10L
    guard n >= limit + digit else { raise Invalid("signed time overflow") }
    n -= digit
  }
  if negative {
    n
  } else {
    -n
  }
}

///|
fn xml_space(value : String) -> Bool {
  for c in value.to_array() {
    if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
      return false
    }
  }
  true
}

///|
fn markup_at(cs : Array[Char], pos : Int32, token : Array[Char]) -> Bool {
  if pos + token.length() > cs.length() {
    return false
  }
  for i, c in token {
    if cs[pos + i] != c {
      return false
    }
  }
  true
}

///|
/// Refuse declarations BEFORE the XML reader can expand them, not literals in
/// comments, CDATA or processing instructions. Input is already size-budgeted.
fn reject_dtd(text : String) -> Unit raise EafError {
  let cs = text.to_array()
  let openers = ["<!--".to_array(), "<![CDATA[".to_array(), "<?".to_array()]
  let closers = ["-->".to_array(), "]]>".to_array(), "?>".to_array()]
  let dtd = "<!DOCTYPE".to_array()
  let entity = "<!ENTITY".to_array()
  let mut pos = 0
  while pos < cs.length() {
    let mut skipped = false
    for i, opener in openers {
      if markup_at(cs, pos, opener) {
        pos += opener.length()
        while pos < cs.length() && !markup_at(cs, pos, closers[i]) {
          pos += 1
        }
        guard pos < cs.length() else { raise Xml("unterminated XML literal") }
        pos += closers[i].length()
        skipped = true
        break
      }
    }
    if skipped {
      continue
    }
    guard !markup_at(cs, pos, dtd) && !markup_at(cs, pos, entity) else {
      raise Unsupported("DTD and entity declarations")
    }
    pos += 1
  }
}
