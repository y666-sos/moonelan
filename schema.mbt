///|
priv struct SchemaAttribute {
  name : String
  kind : String
  required : Bool
  choices : Array[String]
}

///|
priv struct SchemaChild {
  names : Array[String]
  minimum : Int32
  maximum : Int32
}

///|
priv struct SchemaRule {
  type_name : String
  attributes : Array[SchemaAttribute]
  children : Array[SchemaChild]
  textual : Bool
}

///|
fn schema_token(value : String) -> String {
  id_words(value).join(" ")
}

///|
fn schema_shape(
  e : Element,
  depth : Int32,
  limits : Limits,
  count : Ref[Int32],
  ids : Map[String, Bool],
  refs : Array[String],
  inherited : Map[String, String],
) -> Unit raise EafError {
  guard depth <= limits.depth else { raise Budget("EAF depth") }
  count.val += 1
  guard count.val <= limits.nodes else { raise Budget("EAF nodes") }
  let rule = match eaf30_rule(e.name) {
    Some(rule) => rule
    None => raise Unsupported("element outside EAF 3.0: \{e.name}")
  }
  let namespaces = inherited.copy()
  for (name, value) in e.attributes {
    if name.has_prefix("xmlns:") {
      let prefix = name[6:].to_owned()
      validate_xml_id(prefix)
      guard !value.is_empty() &&
        prefix != "xmlns" &&
        (prefix != "xml" || value == "http://www.w3.org/XML/1998/namespace") else {
        raise Invalid("namespace binding")
      }
      namespaces[prefix] = value
    }
  }
  let seen : Map[String, Bool] = Map([])
  for (name, value) in e.attributes {
    guard !seen.contains(name) else { raise Invalid("duplicate attribute") }
    seen[name] = true
    xml_text(value)
    if name == "xmlns" {
      guard value == "" else { raise Invalid("EAF has no target namespace") }
      continue
    }
    if name.has_prefix("xmlns:") {
      continue
    }
    if name.contains(":") {
      let parts = name.split(":").map(fn(s) { s.to_owned() }).collect()
      guard parts.length() == 2 &&
        namespaces.get(parts[0]) ==
        Some("http://www.w3.org/2001/XMLSchema-instance") else {
        raise Invalid("unbound or foreign instance attribute")
      }
      match parts[1] {
        "noNamespaceSchemaLocation" => ()
        "schemaLocation" => {
          guard id_words(value).length() % 2 == 0 else {
            raise Invalid("schemaLocation pairs")
          }
        }
        "nil" => raise Invalid("EAF elements are not nillable")
        "type" => {
          let qname = schema_token(value)
            .split(":")
            .map(fn(s) { s.to_owned() })
            .collect()
          let expected = rule.type_name
            .split(":")
            .map(fn(s) { s.to_owned() })
            .collect()
          guard !rule.type_name.is_empty() else {
            raise Invalid("anonymous EAF type cannot be overridden")
          }
          if expected.length() == 1 {
            guard qname.length() == 1 && qname[0] == expected[0] else {
              raise Invalid("incompatible EAF type")
            }
          } else {
            guard qname.length() == 2 &&
              qname[1] == expected[1] &&
              namespaces.get(qname[0]) ==
              Some("http://www.w3.org/2001/XMLSchema") else {
              raise Invalid("incompatible XML Schema type")
            }
          }
        }
        _ => raise Invalid("unknown schema instance attribute")
      }
      continue
    }
    let spec = match
      rule.attributes.iter().find_first(fn(a) { a.name == name }) {
      Some(spec) => spec
      None => raise Invalid("attribute outside EAF 3.0: \{name}")
    }
    let token = schema_token(value)
    if !spec.choices.is_empty() {
      guard spec.choices.contains(value) else {
        raise Invalid("EAF enumeration")
      }
    }
    match spec.kind {
      "boolean" => ignore(parse_boolean(token))
      "unsignedInt" => ignore(parse_milliseconds(token))
      "long" => ignore(parse_signed_milliseconds(token))
      "dateTime" => validate_date(token)
      "ID" => {
        validate_xml_id(token)
        guard !ids.contains(token) else { raise Invalid("duplicate XML ID") }
        ids[token] = true
      }
      "IDREF" => {
        validate_xml_id(token)
        refs.push(token)
      }
      "IDREFS" => {
        let words = id_words(value)
        guard !words.is_empty() else { raise Invalid("empty IDREFS") }
        for id in words {
          validate_xml_id(id)
          refs.push(id)
        }
      }
      "string" | "anyURI" => ()
      _ => raise Invalid("unimplemented schema datatype")
    }
  }
  for spec in rule.attributes {
    guard !spec.required || seen.contains(spec.name) else {
      raise Invalid("missing EAF attribute \{spec.name}")
    }
  }
  xml_text(e.text)
  guard rule.textual || xml_space(e.text) else {
    raise Invalid("text in structural EAF element")
  }
  let mut pos = 0
  for group in rule.children {
    let mut found = 0
    while pos < e.children.length() &&
          group.names.contains(e.children[pos].name) {
      found += 1
      pos += 1
    }
    guard found >= group.minimum &&
      (group.maximum < 0 || found <= group.maximum) else {
      raise Invalid("EAF child cardinality")
    }
  }
  guard pos == e.children.length() else {
    raise Invalid("EAF child placement or sequence")
  }
  for child in e.children {
    schema_shape(child, depth + 1, limits, count, ids, refs, namespaces)
  }
}

///|
fn schema_select(e : Element, path : Array[String]) -> Array[Element] {
  let mut nodes = [e]
  for name in path {
    let next : Array[Element] = []
    for n in nodes {
      for c in n.children {
        if c.name == name {
          next.push(c)
        }
      }
    }
    nodes = next
  }
  nodes
}

///|
fn schema_key(
  e : Element,
  path : Array[String],
  field : String,
) -> Map[String, Bool] raise EafError {
  let keys : Map[String, Bool] = Map([])
  for n in schema_select(e, path) {
    let key = match attr(n.attributes, field) {
      Some(value) =>
        if ["TIER_ID", "LINGUISTIC_TYPE_ID", "CV_ID", "CVE_ID"].contains(field) {
          value
        } else {
          schema_token(value)
        }
      None => raise Invalid("missing key field")
    }
    guard !keys.contains(key) else {
      raise Invalid("duplicate EAF key \{field}")
    }
    keys[key] = true
  }
  keys
}

///|
fn schema_keyrefs(
  e : Element,
  path : Array[String],
  field : String,
  keys : Map[String, Bool],
  token~ : Bool = false,
) -> Unit raise EafError {
  for n in schema_select(e, path) {
    if attr(n.attributes, field) is Some(value) {
      let key = if token { schema_token(value) } else { value }
      guard keys.contains(key) else {
        raise Invalid("unresolved EAF key reference \{field}")
      }
    }
  }
}

///|
fn schema_relations(root : Element) -> Unit raise EafError {
  if root.name == "ANNOTATION_DOCUMENT" {
    let tiers = schema_key(root, ["TIER"], "TIER_ID")
    schema_keyrefs(root, ["TIER"], "PARENT_REF", tiers)
    let types = schema_key(root, ["LINGUISTIC_TYPE"], "LINGUISTIC_TYPE_ID")
    schema_keyrefs(root, ["TIER"], "LINGUISTIC_TYPE_REF", types)
    let cvs = schema_key(root, ["CONTROLLED_VOCABULARY"], "CV_ID")
    schema_keyrefs(root, ["LINGUISTIC_TYPE"], "CONTROLLED_VOCABULARY_REF", cvs)
    let lexicons = schema_key(root, ["LEXICON_REF"], "LEX_REF_ID")
    schema_keyrefs(
      root,
      ["LINGUISTIC_TYPE"],
      "LEXICON_REF",
      lexicons,
      token=true,
    )
    let languages = schema_key(root, ["LANGUAGE"], "LANG_ID")
    for
      path in [
        ["CONTROLLED_VOCABULARY", "DESCRIPTION"],
        ["CONTROLLED_VOCABULARY", "CV_ENTRY_ML", "CVE_VALUE"],
        ["TIER"],
        ["TIER", "ANNOTATION", "ALIGNABLE_ANNOTATION"],
        ["TIER", "ANNOTATION", "REF_ANNOTATION"],
      ] {
      schema_keyrefs(root, path, "LANG_REF", languages, token=true)
    }
    let slots = schema_key(root, ["TIME_ORDER", "TIME_SLOT"], "TIME_SLOT_ID")
    for field in ["TIME_SLOT_REF1", "TIME_SLOT_REF2"] {
      schema_keyrefs(
        root,
        ["TIER", "ANNOTATION", "ALIGNABLE_ANNOTATION"],
        field,
        slots,
        token=true,
      )
    }
    let aligned = schema_key(
      root,
      ["TIER", "ANNOTATION", "ALIGNABLE_ANNOTATION"],
      "ANNOTATION_ID",
    )
    let references = schema_key(
      root,
      ["TIER", "ANNOTATION", "REF_ANNOTATION"],
      "ANNOTATION_ID",
    )
    schema_keyrefs(
      root,
      ["TIER", "ANNOTATION", "REF_ANNOTATION"],
      "PREVIOUS_ANNOTATION",
      references,
      token=true,
    )
    let links : Map[String, Bool] = Map([])
    for k, _ in aligned {
      links[k] = true
    }
    for k, _ in references {
      links[k] = true
    }
    for name in ["CROSS_REF_LINK", "GROUP_REF_LINK"] {
      for k, _ in schema_key(root, ["REF_LINK_SET", name], "REF_LINK_ID") {
        links[k] = true
      }
    }
    // The upstream XSD link keyrefs omit '@'. Check the intended union explicitly.
    for n in schema_select(root, ["REF_LINK_SET", "CROSS_REF_LINK"]) {
      for field in ["REF1", "REF2"] {
        guard links.contains(schema_token(attr(n.attributes, field).unwrap())) else {
          raise Invalid("dangling cross link")
        }
      }
    }
    for n in schema_select(root, ["REF_LINK_SET", "GROUP_REF_LINK"]) {
      for id in id_words(attr(n.attributes, "REFS").unwrap()) {
        guard links.contains(id) else { raise Invalid("dangling group link") }
      }
    }
    let annotation_targets : Map[String, Bool] = Map([])
    for k, _ in aligned {
      annotation_targets[k] = true
    }
    for k, _ in references {
      annotation_targets[k] = true
    }
    schema_keyrefs(
      root,
      ["TIER", "ANNOTATION", "REF_ANNOTATION"],
      "ANNOTATION_REF",
      annotation_targets,
      token=true,
    )
  }
  for cv in root.children.filter(fn(n) { n.name == "CONTROLLED_VOCABULARY" }) {
    ignore(schema_key(cv, ["CV_ENTRY_ML"], "CVE_ID"))
  }
}

///|
/// EAF 3.0 grammar plus resolvable typed references; graph editing policies are separate.
pub fn validate_file(
  file : EafFile,
  limits~ : Limits = default_limits(),
) -> Unit raise EafError {
  guard ["ANNOTATION_DOCUMENT", "CV_RESOURCE"].contains(file.root.name) else {
    raise Invalid("EAF root")
  }
  if file.root.name == "ANNOTATION_DOCUMENT" {
    guard attr(file.root.attributes, "VERSION") == Some("3.0") else {
      raise Unsupported("conformance endpoint requires VERSION 3.0")
    }
    if attr(file.root.attributes, "FORMAT") is Some(version) {
      guard version == "3.0" else {
        raise Unsupported("conformance endpoint requires FORMAT 3.0")
      }
    }
  }
  let ids : Map[String, Bool] = Map([])
  let refs : Array[String] = []
  schema_shape(file.root, 1, limits, Ref(0), ids, refs, Map([]))
  for id in refs {
    guard ids.contains(id) else { raise Invalid("dangling XML IDREF") }
  }
  schema_relations(file.root)
}
