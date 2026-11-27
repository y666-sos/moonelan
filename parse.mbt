///|
fn parse_constraint(name : String) -> Constraint raise EafError {
  match name {
    "" => Independent
    "Time_Subdivision" => TimeSubdivision
    "Included_In" => IncludedIn
    "Symbolic_Association" => SymbolicAssociation
    "Symbolic_Subdivision" => SymbolicSubdivision
    _ => raise Unsupported("linguistic constraint")
  }
}

///|
fn parse_annotation(
  n : XmlNode,
  extras : Array[ObjectAttributes],
) -> Annotation raise EafError {
  guard n.element.name == "ANNOTATION" && n.children.length() == 1 else {
    raise Invalid("expected one wrapped annotation")
  }
  attrs_only(n, [])
  structural(n)
  let a = n.children[0]
  structural(a)
  guard a.children.length() == 1 &&
    a.children[0].element.name == "ANNOTATION_VALUE" else {
    raise Invalid("expected one annotation value")
  }
  let value = a.children[0]
  attrs_only(value, [])
  leaf(value)
  let metadata = extra_attrs(a, ["EXT_REF", "LANG_REF", "CVE_REF", "SVG_REF"])
  if !metadata.is_empty() {
    extras.push({ id: required(a, "ANNOTATION_ID"), values: metadata, })
  }
  match a.element.name {
    "ALIGNABLE_ANNOTATION" => {
      attrs_only(a, [
        "ANNOTATION_ID", "TIME_SLOT_REF1", "TIME_SLOT_REF2", "EXT_REF", "LANG_REF",
        "CVE_REF", "SVG_REF",
      ])
      Aligned(
        required(a, "ANNOTATION_ID"),
        required(a, "TIME_SLOT_REF1"),
        required(a, "TIME_SLOT_REF2"),
        value.text.to_string(),
      )
    }
    "REF_ANNOTATION" => {
      attrs_only(a, [
        "ANNOTATION_ID", "ANNOTATION_REF", "PREVIOUS_ANNOTATION", "EXT_REF", "LANG_REF",
        "CVE_REF",
      ])
      Reference(
        required(a, "ANNOTATION_ID"),
        required(a, "ANNOTATION_REF"),
        attribute(a, "PREVIOUS_ANNOTATION"),
        value.text.to_string(),
      )
    }
    _ => raise Unsupported("annotation element")
  }
}

///|
/// Strict semantic import. Unsupported constructs fail rather than disappearing.
pub fn parse(
  text : String,
  limits~ : Limits = default_limits(),
) -> Document raise EafError {
  let root = xml_tree(text, limits)
  guard root.element.name == "ANNOTATION_DOCUMENT" else {
    raise Invalid("expected EAF root")
  }
  attrs_only(root, [
    "AUTHOR", "DATE", "FORMAT", "VERSION", "xmlns:xsi", "xsi:noNamespaceSchemaLocation",
  ])
  structural(root)
  let version = required(root, "VERSION")
  let format = attribute(root, "FORMAT").unwrap_or(version)
  guard format == version else {
    raise Unsupported("different FORMAT and VERSION")
  }
  let extensions = empty_extensions()
  let media : Array[Media] = []
  let properties : Array[(String, String)] = []
  let times : Array[TimeSlot] = []
  let types : Array[LinguisticType] = []
  let tiers : Array[Tier] = []
  let mut header = false
  let mut time_order = false
  for n in root.children {
    match n.element.name {
      "HEADER" => {
        guard !header else { raise Invalid("duplicate HEADER") }
        header = true
        attrs_only(n, ["MEDIA_FILE", "TIME_UNITS"])
        structural(n)
        match attribute(n, "TIME_UNITS") {
          Some(u) => {
            guard u == "milliseconds" else { raise Unsupported("time units") }
          }
          None => ()
        }
        if attribute(n, "MEDIA_FILE") is Some(value) {
          extensions.header_attributes.push(("MEDIA_FILE", value))
        }
        for c in n.children {
          leaf(c)
          match c.element.name {
            "MEDIA_DESCRIPTOR" => {
              attrs_only(c, [
                "MEDIA_URL", "RELATIVE_MEDIA_URL", "MIME_TYPE", "TIME_ORIGIN", "EXTRACTED_FROM",
              ])
              structural(c)
              let extra = extra_attrs(c, ["EXTRACTED_FROM"])
              if !extra.is_empty() {
                extensions.media_attributes.push({
                  id: required(c, "MEDIA_URL"),
                  values: extra,
                })
              }
              media.push({
                url: required(c, "MEDIA_URL"),
                relative_url: attribute(c, "RELATIVE_MEDIA_URL").unwrap_or(""),
                mime_type: required(c, "MIME_TYPE"),
                time_origin: parse_signed_milliseconds(
                  attribute(c, "TIME_ORIGIN").unwrap_or("0"),
                ),
              })
            }
            "PROPERTY" => {
              attrs_only(c, ["NAME"])
              properties.push(
                (attribute(c, "NAME").unwrap_or(""), c.text.to_string()),
              )
            }
            "LINKED_FILE_DESCRIPTOR" =>
              extensions.header_elements.push(import_element(c))
            _ => raise Unsupported("HEADER child")
          }
        }
      }
      "TIME_ORDER" => {
        guard !time_order else { raise Invalid("duplicate TIME_ORDER") }
        time_order = true
        attrs_only(n, [])
        structural(n)
        for s in n.children {
          guard s.element.name == "TIME_SLOT" else {
            raise Unsupported("TIME_ORDER child")
          }
          attrs_only(s, ["TIME_SLOT_ID", "TIME_VALUE"])
          leaf(s)
          structural(s)
          times.push({
            id: required(s, "TIME_SLOT_ID"),
            milliseconds: match attribute(s, "TIME_VALUE") {
              Some(value) => Some(parse_milliseconds(value))
              None => None
            },
          })
        }
      }
      "LINGUISTIC_TYPE" => {
        attrs_only(n, [
          "LINGUISTIC_TYPE_ID", "TIME_ALIGNABLE", "GRAPHIC_REFERENCES", "CONSTRAINTS",
          "CONTROLLED_VOCABULARY_REF", "EXT_REF", "LEXICON_REF",
        ])
        leaf(n)
        structural(n)
        let constraint = parse_constraint(
          attribute(n, "CONSTRAINTS").unwrap_or(""),
        )
        let alignable = attribute(n, "TIME_ALIGNABLE").unwrap_or("true")
        guard parse_boolean(alignable) == is_time_alignable(constraint) else {
          raise Invalid("TIME_ALIGNABLE conflicts with constraint")
        }
        let metadata = extra_attrs(n, [
          "CONTROLLED_VOCABULARY_REF", "EXT_REF", "LEXICON_REF", "GRAPHIC_REFERENCES",
        ])
        if !metadata.is_empty() {
          extensions.type_attributes.push({
            id: required(n, "LINGUISTIC_TYPE_ID"),
            values: metadata,
          })
        }
        types.push({ id: required(n, "LINGUISTIC_TYPE_ID"), constraint, })
      }
      "TIER" => {
        attrs_only(n, [
          "TIER_ID", "LINGUISTIC_TYPE_REF", "PARENT_REF", "PARTICIPANT", "ANNOTATOR",
          "DEFAULT_LOCALE", "LANG_REF", "EXT_REF",
        ])
        structural(n)
        let metadata = extra_attrs(n, ["DEFAULT_LOCALE", "LANG_REF", "EXT_REF"])
        if !metadata.is_empty() {
          extensions.tier_attributes.push({
            id: required(n, "TIER_ID"),
            values: metadata,
          })
        }
        tiers.push({
          id: required(n, "TIER_ID"),
          linguistic_type: required(n, "LINGUISTIC_TYPE_REF"),
          parent: attribute(n, "PARENT_REF"),
          participant: attribute(n, "PARTICIPANT").unwrap_or(""),
          annotator: attribute(n, "ANNOTATOR").unwrap_or(""),
          annotations: n.children.map(c => {
            parse_annotation(c, extensions.annotation_attributes)
          }),
        })
      }
      "CONSTRAINT" => {
        attrs_only(n, ["STEREOTYPE", "DESCRIPTION"])
        leaf(n)
        structural(n)
        ignore(parse_constraint(required(n, "STEREOTYPE")))
        extensions.elements.push(import_element(n))
      }
      "LICENSE"
      | "LOCALE"
      | "LANGUAGE"
      | "CONTROLLED_VOCABULARY"
      | "LEXICON_REF"
      | "REF_LINK_SET"
      | "EXTERNAL_REF" => extensions.elements.push(import_element(n))
      _ => raise Unsupported("EAF element \{n.element.name}")
    }
  }
  guard header && time_order else {
    raise Invalid("missing HEADER or TIME_ORDER")
  }
  let d = Document::{
    extensions,
    author: attribute(root, "AUTHOR").unwrap_or(""),
    date: attribute(root, "DATE").unwrap_or(""),
    version,
    media,
    properties,
    times,
    types,
    tiers,
  }
  validate(d, limits~)
  d
}
