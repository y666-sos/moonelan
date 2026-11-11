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
  guard !text.contains("<!DOCTYPE") && !text.contains("<!ENTITY") else {
    raise Unsupported("DTD and entity declarations")
  }
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
        guard stack.length() <= limits.depth else {
          raise Budget("XML nesting too deep")
        }
      }
      @xml.End(_) => ignore(stack.pop())
      @xml.Text(s) | @xml.CData(s) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(s)
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
fn parse_milliseconds(s : String) -> Int32 raise EafError {
  guard !s.is_empty() && s.length() <= 10 else {
    raise Invalid("invalid millisecond number")
  }
  let mut n = 0
  for c in s.to_array() {
    guard c >= '0' && c <= '9' else {
      raise Invalid("nondecimal millisecond value")
    }
    let digit = c.to_int() - 48
    guard n <= (2147483647 - digit) / 10 else {
      raise Invalid("millisecond overflow")
    }
    n = n * 10 + digit
  }
  n
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
