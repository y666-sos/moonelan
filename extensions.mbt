///|
/// Standard EAF metadata retained as structured XML, not opaque source text.
pub(all) struct Element {
  name : String
  attributes : Array[(String, String)]
  text : String
  children : Array[Element]
} derive(Debug, Eq)

///|
/// Additional standard attributes belong to the identified model object.
pub(all) struct ObjectAttributes {
  id : String
  values : Array[(String, String)]
} derive(Debug, Eq)

///|
pub(all) struct Extensions {
  elements : Array[Element]
  header_attributes : Array[(String, String)]
  header_elements : Array[Element]
  media_attributes : Array[ObjectAttributes]
  tier_attributes : Array[ObjectAttributes]
  type_attributes : Array[ObjectAttributes]
  annotation_attributes : Array[ObjectAttributes]
} derive(Debug, Eq)

///|
pub extend Element with @debug.Debug::{to_repr}

///|
pub extend Element with Eq::{equal, not_equal}

///|
pub extend ObjectAttributes with @debug.Debug::{to_repr}

///|
pub extend ObjectAttributes with Eq::{equal, not_equal}

///|
pub extend Extensions with @debug.Debug::{to_repr}

///|
pub extend Extensions with Eq::{equal, not_equal}

///|
pub fn empty_extensions() -> Extensions {
  {
    elements: [],
    header_attributes: [],
    header_elements: [],
    media_attributes: [],
    tier_attributes: [],
    type_attributes: [],
    annotation_attributes: [],
  }
}

///|
fn element_copy(e : Element) -> Element {
  {
    ..e,
    attributes: e.attributes.copy(),
    children: e.children.map(element_copy),
  }
}

///|
fn copy_attributes(xs : Array[ObjectAttributes]) -> Array[ObjectAttributes] {
  xs.map(fn(x) { { ..x, values: x.values.copy(), } })
}

///|
fn copy_extensions(e : Extensions) -> Extensions {
  {
    elements: e.elements.map(element_copy),
    header_attributes: e.header_attributes.copy(),
    header_elements: e.header_elements.map(element_copy),
    media_attributes: copy_attributes(e.media_attributes),
    tier_attributes: copy_attributes(e.tier_attributes),
    type_attributes: copy_attributes(e.type_attributes),
    annotation_attributes: copy_attributes(e.annotation_attributes),
  }
}

///|
fn attr(xs : Array[(String, String)], name : String) -> String? {
  for (key, value) in xs {
    if key == name {
      return Some(value)
    }
  }
  None
}

///|
fn object_attrs(
  xs : Array[ObjectAttributes],
  id : String,
) -> Array[(String, String)] {
  for x in xs {
    if x.id == id {
      return x.values
    }
  }
  []
}

///|
fn extra_attrs(n : XmlNode, names : Array[String]) -> Array[(String, String)] {
  n.element.attributes
  .filter(fn(a) { names.contains(a.name) })
  .map(fn(a) { (a.name, a.value) })
}

///|
fn import_element(n : XmlNode) -> Element {
  {
    name: n.element.name,
    attributes: n.element.attributes.map(fn(a) { (a.name, a.value) }),
    text: n.text.to_string(),
    children: n.children.map(import_element),
  }
}

///|
fn write_element(w : @xml.Writer, e : Element) -> Unit raise @xml.WriterError {
  w.start_element(e.name, e.attributes)
  if !e.text.is_empty() {
    w.text(e.text)
  }
  for child in e.children {
    write_element(w, child)
  }
  w.end_element(e.name)
}

///|
fn check_attrs(
  xs : Array[(String, String)],
  allowed : Array[String],
  required : Array[String],
) -> Unit raise EafError {
  let seen : Map[String, Bool] = Map([])
  for (name, value) in xs {
    guard allowed.contains(name) else {
      raise Unsupported("metadata attribute \{name}")
    }
    guard !seen.contains(name) else {
      raise Invalid("duplicate metadata attribute")
    }
    seen[name] = true
    xml_text(value)
  }
  for name in required {
    guard seen.contains(name) else {
      raise Invalid("missing metadata attribute \{name}")
    }
  }
}

///|
fn metadata_shape(
  e : Element,
  version : String,
  depth : Int32,
  limits : Limits,
  count : Ref[Int32],
) -> Unit raise EafError {
  guard depth <= limits.depth else { raise Budget("metadata depth") }
  count.val += 1
  guard count.val <= limits.nodes else { raise Budget("metadata nodes") }
  let (allowed, required, children, textual) = match e.name {
    "LICENSE" => (["LICENSE_URL"], [], [], true)
    "LINKED_FILE_DESCRIPTOR" =>
      (
        [
          "LINK_URL", "RELATIVE_LINK_URL", "MIME_TYPE", "TIME_ORIGIN", "ASSOCIATED_WITH",
        ],
        ["LINK_URL", "MIME_TYPE"],
        [],
        false,
      )
    "LOCALE" =>
      (
        ["LANGUAGE_CODE", "COUNTRY_CODE", "VARIANT"],
        ["LANGUAGE_CODE"],
        [],
        false,
      )
    "LANGUAGE" =>
      (["LANG_ID", "LANG_DEF", "LANG_LABEL"], ["LANG_ID"], [], false)
    "CONTROLLED_VOCABULARY" =>
      (["CV_ID", "EXT_REF"], ["CV_ID"], ["DESCRIPTION", "CV_ENTRY_ML"], false)
    "DESCRIPTION" => (["LANG_REF"], ["LANG_REF"], [], true)
    "CV_ENTRY_ML" => (["CVE_ID", "EXT_REF"], ["CVE_ID"], ["CVE_VALUE"], false)
    "CVE_VALUE" => (["LANG_REF", "DESCRIPTION"], ["LANG_REF"], [], true)
    "LEXICON_REF" =>
      (
        [
          "LEX_REF_ID", "NAME", "TYPE", "URL", "LEXICON_ID", "LEXICON_NAME", "DATCAT_ID",
          "DATCAT_NAME",
        ],
        ["LEX_REF_ID", "NAME", "TYPE", "URL", "LEXICON_ID", "LEXICON_NAME"],
        [],
        false,
      )
    "EXTERNAL_REF" =>
      (
        ["EXT_REF_ID", "TYPE", "VALUE"],
        ["EXT_REF_ID", "TYPE", "VALUE"],
        [],
        false,
      )
    "REF_LINK_SET" => {
      guard version == "3.0" else {
        raise Unsupported("reference links require EAF 3.0")
      }
      (
        ["LINK_SET_ID", "LINK_SET_NAME", "EXT_REF", "LANG_REF", "CV_REF"],
        ["LINK_SET_ID"],
        ["CROSS_REF_LINK", "GROUP_REF_LINK"],
        false,
      )
    }
    "CROSS_REF_LINK" =>
      (
        [
          "REF_LINK_ID", "REF_LINK_NAME", "EXT_REF", "LANG_REF", "CVE_REF", "REF_TYPE",
          "REF1", "REF2", "DIRECTIONALITY",
        ],
        ["REF_LINK_ID", "REF1", "REF2"],
        [],
        true,
      )
    "GROUP_REF_LINK" =>
      (
        [
          "REF_LINK_ID", "REF_LINK_NAME", "EXT_REF", "LANG_REF", "CVE_REF", "REF_TYPE",
          "REFS",
        ],
        ["REF_LINK_ID", "REFS"],
        [],
        true,
      )
    _ => raise Unsupported("metadata element \{e.name}")
  }
  check_attrs(e.attributes, allowed, required)
  xml_text(e.text)
  guard textual || e.text.trim().is_empty() else {
    raise Invalid("text in structural metadata")
  }
  let mut entries_started = false
  for child in e.children {
    guard children.contains(child.name) else {
      raise Invalid("metadata child placement")
    }
    if e.name == "CONTROLLED_VOCABULARY" {
      if child.name == "CV_ENTRY_ML" {
        entries_started = true
      } else {
        guard !entries_started else {
          raise Invalid("vocabulary description follows entries")
        }
      }
    }
    metadata_shape(child, version, depth + 1, limits, count)
  }
  if e.name == "CV_ENTRY_ML" {
    guard !e.children.is_empty() else {
      raise Invalid("empty multilingual vocabulary entry")
    }
  }
  if e.name == "EXTERNAL_REF" {
    guard ["iso12620", "ecv", "cve_id", "lexen_id", "resource_url"].contains(
      attr(e.attributes, "TYPE").unwrap(),
    ) else {
      raise Invalid("external reference type")
    }
  }
  if attr(e.attributes, "DIRECTIONALITY") is Some(direction) {
    guard ["undirected", "unidirectional", "bidirectional"].contains(direction) else {
      raise Invalid("reference link direction")
    }
  }
  if attr(e.attributes, "TIME_ORIGIN") is Some(value) {
    ignore(parse_signed_milliseconds(value))
  }
}

///|
fn id_words(value : String) -> Array[String] {
  value
  .replace(old="\t", new=" ")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
  .split(" ")
  .map(fn(s) { s.to_owned() })
  .filter(fn(s) { !s.is_empty() })
  .collect()
}

///|
fn register_id(ids : Map[String, Bool], id : String) -> Unit raise EafError {
  validate_xml_id(id)
  guard !ids.contains(id) else { raise Invalid("XML ID collision in metadata") }
  ids[id] = true
}

///|
fn check_reference(
  attrs : Array[(String, String)],
  key : String,
  targets : Map[String, Bool],
  many~ : Bool = false,
) -> Unit raise EafError {
  if attr(attrs, key) is Some(value) {
    let refs = if many { id_words(value) } else { [value] }
    guard !refs.is_empty() else { raise Invalid("empty metadata reference") }
    for reference in refs {
      guard targets.contains(reference) else {
        raise Invalid("unresolved metadata reference \{key}")
      }
    }
  }
}

///|
fn validate_object_attrs(
  xs : Array[ObjectAttributes],
  targets : Map[String, Bool],
  allowed : Array[String],
) -> Unit raise EafError {
  let seen : Map[String, Bool] = Map([])
  for x in xs {
    guard targets.contains(x.id) && !seen.contains(x.id) else {
      raise Invalid("orphan or duplicate object metadata")
    }
    seen[x.id] = true
    check_attrs(x.values, allowed, [])
  }
}

///|
fn validate_extensions(
  d : Document,
  ix : GraphIndex,
  ids : Map[String, Bool],
  limits : Limits,
) -> Unit raise EafError {
  let e = d.extensions
  check_attrs(e.header_attributes, ["MEDIA_FILE"], [])
  let languages : Map[String, Bool] = Map([])
  let locales : Map[String, Bool] = Map([])
  let external : Map[String, Bool] = Map([])
  let lexicons : Map[String, Bool] = Map([])
  let vocabularies : Map[String, Bool] = Map([])
  let link_targets : Map[String, Bool] = Map([])
  let tiers : Map[String, Bool] = Map([])
  let types : Map[String, Bool] = Map([])
  let media : Map[String, Bool] = Map([])
  for id, _ in ix.annotations {
    link_targets[id] = true
  }
  for t in d.tiers {
    tiers[t.id] = true
  }
  for t in d.types {
    types[t.id] = true
  }
  for m in d.media {
    media[m.url] = true
  }
  let count = Ref(0)
  for node in e.header_elements {
    guard node.name == "LINKED_FILE_DESCRIPTOR" else {
      raise Invalid("header metadata placement")
    }
    metadata_shape(node, d.version, 1, limits, count)
  }
  for node in e.elements {
    guard [
      "LICENSE", "LOCALE", "LANGUAGE", "CONTROLLED_VOCABULARY", "LEXICON_REF", "REF_LINK_SET",
      "EXTERNAL_REF",
    ].contains(node.name) else {
      raise Invalid("root metadata placement")
    }
    metadata_shape(node, d.version, 1, limits, count)
    let (key, target) = match node.name {
      "LANGUAGE" => ("LANG_ID", languages)
      "LOCALE" => ("LANGUAGE_CODE", locales)
      "EXTERNAL_REF" => ("EXT_REF_ID", external)
      "LEXICON_REF" => ("LEX_REF_ID", lexicons)
      "REF_LINK_SET" => ("LINK_SET_ID", Map([]))
      "CONTROLLED_VOCABULARY" => {
        let id = attr(node.attributes, "CV_ID").unwrap()
        guard !id.is_empty() && !vocabularies.contains(id) else {
          raise Invalid("duplicate or empty vocabulary ID")
        }
        vocabularies[id] = true
        continue
      }
      _ => continue
    }
    let id = attr(node.attributes, key).unwrap()
    register_id(ids, id)
    target[id] = true
    if node.name == "REF_LINK_SET" {
      for link in node.children {
        let id = attr(link.attributes, "REF_LINK_ID").unwrap()
        register_id(ids, id)
        link_targets[id] = true
      }
    }
  }
  validate_object_attrs(e.media_attributes, media, ["EXTRACTED_FROM"])
  validate_object_attrs(e.tier_attributes, tiers, [
    "DEFAULT_LOCALE", "EXT_REF", "LANG_REF",
  ])
  validate_object_attrs(e.type_attributes, types, [
    "CONTROLLED_VOCABULARY_REF", "EXT_REF", "LEXICON_REF", "GRAPHIC_REFERENCES",
  ])
  let annotations : Map[String, Bool] = Map([])
  for id, _ in ix.annotations {
    annotations[id] = true
  }
  validate_object_attrs(e.annotation_attributes, annotations, [
    "EXT_REF", "LANG_REF", "CVE_REF", "SVG_REF",
  ])
  for x in e.tier_attributes {
    check_reference(x.values, "DEFAULT_LOCALE", locales)
    check_reference(x.values, "LANG_REF", languages)
    check_reference(x.values, "EXT_REF", external)
  }
  for x in e.type_attributes {
    check_reference(x.values, "CONTROLLED_VOCABULARY_REF", vocabularies)
    check_reference(x.values, "LEXICON_REF", lexicons)
    check_reference(x.values, "EXT_REF", external)
    if attr(x.values, "GRAPHIC_REFERENCES") is Some(value) {
      ignore(parse_boolean(value))
    }
  }
  for x in e.annotation_attributes {
    check_reference(x.values, "LANG_REF", languages)
    check_reference(x.values, "EXT_REF", external, many=true)
    let (ti, ai) = ix.annotations.get(x.id).unwrap()
    if attr(x.values, "SVG_REF") != None {
      guard d.tiers[ti].annotations[ai] is Aligned(_, _, _, _) else {
        raise Invalid("SVG_REF on reference annotation")
      }
    }
    if attr(x.values, "CVE_REF") is Some(entry) {
      validate_cv_binding(d, ti, ai, entry)
    }
  }
  for node in e.elements {
    check_reference(
      node.attributes,
      "EXT_REF",
      external,
      many=node.name == "REF_LINK_SET",
    )
    check_reference(node.attributes, "LANG_REF", languages)
    check_reference(node.attributes, "CV_REF", vocabularies)
    if node.name == "CONTROLLED_VOCABULARY" {
      let entries : Map[String, Bool] = Map([])
      let descriptions : Map[String, Bool] = Map([])
      let mut entry_count = 0
      for child in node.children {
        check_reference(child.attributes, "EXT_REF", external)
        if child.name == "DESCRIPTION" {
          check_reference(child.attributes, "LANG_REF", languages)
          let language = attr(child.attributes, "LANG_REF").unwrap()
          guard !descriptions.contains(language) else {
            raise Invalid("duplicate vocabulary description language")
          }
          descriptions[language] = true
        } else {
          let entry = attr(child.attributes, "CVE_ID").unwrap()
          guard !entry.is_empty() && !entries.contains(entry) else {
            raise Invalid("duplicate vocabulary entry")
          }
          entries[entry] = true
          entry_count += 1
          let seen : Map[String, Bool] = Map([])
          for value in child.children {
            check_reference(value.attributes, "LANG_REF", languages)
            let lang = attr(value.attributes, "LANG_REF").unwrap()
            guard !seen.contains(lang) else {
              raise Invalid("duplicate vocabulary entry language")
            }
            seen[lang] = true
          }
        }
      }
      guard entry_count == 0 || attr(node.attributes, "EXT_REF") == None else {
        raise Invalid("external vocabulary also has internal entries")
      }
    }
    if node.name == "REF_LINK_SET" {
      for link in node.children {
        check_reference(link.attributes, "EXT_REF", external, many=true)
        check_reference(link.attributes, "LANG_REF", languages)
        check_reference(link.attributes, "REF1", link_targets)
        check_reference(link.attributes, "REF2", link_targets)
        check_reference(link.attributes, "REFS", link_targets, many=true)
      }
    }
  }
}
