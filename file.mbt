///|
/// Complete structured EAF 3.0 interchange document (annotation or CV resource).
/// Unlike Document this model does not impose time-aligned editing policies.
pub(all) struct EafFile {
  root : Element
} derive(Debug, Eq)

///|
pub extend EafFile with @debug.Debug::{to_repr}

///|
pub extend EafFile with Eq::{equal, not_equal}

///|
/// Parse decoded XML, validate the full EAF 3.0 schema surface and references.
pub fn parse_file(
  text : String,
  limits~ : Limits = default_limits(),
) -> EafFile raise EafError {
  let file = EafFile::{ root: import_element(xml_tree(text, limits)), }
  validate_file(file, limits~)
  file
}

///|
/// Preserve every standard element, attribute, optional omission and text value.
/// XML formatting, entity spelling and comments are not data-model properties.
pub fn write_file(
  file : EafFile,
  limits~ : Limits = default_limits(),
) -> String raise EafError {
  validate_file(file, limits~)
  let w = @xml.Writer::new()
  try {
    write_element(w, file.root)
    w.to_string()
  } catch {
    _ => raise Xml("file serialization")
  }
}

///|
/// Explicit projection to the stricter millisecond-based editable graph model.
/// Unsupported graph policies do not make the interchange file malformed.
pub fn file_document(
  file : EafFile,
  limits~ : Limits = default_limits(),
) -> Document raise EafError {
  parse(write_file(file, limits~), limits~)
}

///|
pub fn document_file(d : Document) -> EafFile raise EafError {
  parse_file(write(d))
}

///|
fn file_map(e : Element, f : (Element) -> Element) -> Element {
  f({
    ..e,
    attributes: e.attributes.copy(),
    children: e.children.map(fn(c) { file_map(c, f) }),
  })
}

///|
fn file_annotation(e : Element) -> Bool {
  e.name == "ALIGNABLE_ANNOTATION" || e.name == "REF_ANNOTATION"
}

///|
/// Transactional rename updates annotation, previous and cross/group links.
/// Text values, CV entry names and unrelated string attributes are untouched.
pub fn file_rename_annotation(
  file : EafFile,
  old : String,
  fresh : String,
) -> EafFile raise EafError {
  validate_file(file)
  validate_xml_id(fresh)
  guard fresh == schema_token(fresh) else {
    raise Invalid("noncanonical new ID")
  }
  let found = Ref(false)
  let root = file_map(file.root, fn(e) {
    let is_annotation = file_annotation(e)
    let values = e.attributes.map(fn(pair) {
      let (name, value) = pair
      let direct = (
          is_annotation &&
          ["ANNOTATION_ID", "ANNOTATION_REF", "PREVIOUS_ANNOTATION"].contains(
            name,
          )
        ) ||
        (e.name == "CROSS_REF_LINK" && ["REF1", "REF2"].contains(name))
      if is_annotation && name == "ANNOTATION_ID" && schema_token(value) == old {
        found.val = true
      }
      if direct && schema_token(value) == old {
        (name, fresh)
      } else if e.name == "GROUP_REF_LINK" && name == "REFS" {
        (
          name,
          id_words(value)
          .map(fn(id) { if id == old { fresh } else { id } })
          .join(" "),
        )
      } else {
        pair
      }
    })
    { ..e, attributes: values, }
  })
  guard found.val else { raise Invalid("missing: " + "annotation " + old) }
  let result = EafFile::{ root, }
  validate_file(result)
  result
}

///|
/// Set a free-text value without interpreting its time slots; clear CVE_REF.
/// Use file_select_cv to retain a checked controlled-vocabulary binding.
pub fn file_set_value(
  file : EafFile,
  id : String,
  value : String,
) -> EafFile raise EafError {
  validate_file(file)
  xml_text(value)
  let found = Ref(false)
  let root = file_map(file.root, fn(e) {
    if file_annotation(e) &&
      attr(e.attributes, "ANNOTATION_ID").map(schema_token) == Some(id) {
      found.val = true
      {
        ..e,
        attributes: e.attributes.filter(fn(p) { p.0 != "CVE_REF" }),
        children: e.children.map(fn(c) {
          if c.name == "ANNOTATION_VALUE" {
            { ..c, text: value, }
          } else {
            c
          }
        }),
      }
    } else {
      e
    }
  })
  guard found.val else { raise Invalid("missing: " + "annotation " + id) }
  let result = EafFile::{ root, }
  validate_file(result)
  result
}

///|
/// Change a slot's exact unsigned-32-bit value or keep it explicitly unaligned.
/// Frame units remain frame units; no hidden conversion to milliseconds occurs.
pub fn file_set_time(
  file : EafFile,
  id : String,
  value : Int64?,
) -> EafFile raise EafError {
  validate_file(file)
  if value is Some(n) {
    guard n >= 0L && n <= 4294967295L else { raise Invalid("TIME_VALUE range") }
  }
  let found = Ref(false)
  let root = file_map(file.root, fn(e) {
    if e.name == "TIME_SLOT" &&
      attr(e.attributes, "TIME_SLOT_ID").map(schema_token) == Some(id) {
      found.val = true
      let attrs = e.attributes.filter(fn(pair) { pair.0 != "TIME_VALUE" })
      if value is Some(n) {
        attrs.push(("TIME_VALUE", n.to_string()))
      }
      { ..e, attributes: attrs, }
    } else {
      e
    }
  })
  guard found.val else { raise Invalid("missing: " + "time slot " + id) }
  let result = EafFile::{ root, }
  validate_file(result)
  result
}

///|
/// Resolve a caller-supplied ECV resource by CV_ID, entry ID and language.
/// No URL fetching; unresolved external content is an explicit error.
pub fn file_cv_value(
  file : EafFile,
  cv_id : String,
  entry_id : String,
  language : String,
  resource~ : EafFile? = None,
) -> String raise EafError {
  validate_file(file)
  let mut vocabularies = file.root.children.filter(fn(c) {
    c.name == "CONTROLLED_VOCABULARY" &&
    attr(c.attributes, "CV_ID") == Some(cv_id)
  })
  guard vocabularies.length() == 1 else {
    raise Invalid("missing: " + "controlled vocabulary " + cv_id)
  }
  if !vocabularies[0].children.iter().any(fn(c) { c.name == "CV_ENTRY_ML" }) &&
    attr(vocabularies[0].attributes, "EXT_REF") is Some(_) {
    let external = match resource {
      Some(r) => r
      None => raise Invalid("missing: " + "external CV resource")
    }
    validate_file(external)
    guard external.root.name == "CV_RESOURCE" else {
      raise Invalid("expected CV_RESOURCE")
    }
    vocabularies = external.root.children.filter(fn(c) {
      c.name == "CONTROLLED_VOCABULARY" &&
      attr(c.attributes, "CV_ID") == Some(cv_id)
    })
    guard vocabularies.length() == 1 else {
      raise Invalid("missing: " + "external vocabulary " + cv_id)
    }
  }
  for entry in vocabularies[0].children {
    if entry.name == "CV_ENTRY_ML" &&
      attr(entry.attributes, "CVE_ID") == Some(entry_id) {
      for v in entry.children {
        if v.name == "CVE_VALUE" &&
          attr(v.attributes, "LANG_REF").map(schema_token) == Some(language) {
          return v.text
        }
      }
    }
  }
  raise Invalid("missing: " + "CV entry/language")
}

///|
/// Set a bound CV value and its IDs atomically, checking the tier's actual type.
pub fn file_select_cv(
  file : EafFile,
  id : String,
  entry_id : String,
  language : String,
  resource~ : EafFile? = None,
) -> EafFile raise EafError {
  validate_file(file)
  let mut type_id : String? = None
  for tier in schema_select(file.root, ["TIER"]) {
    for wrapper in tier.children {
      for a in wrapper.children {
        if attr(a.attributes, "ANNOTATION_ID").map(schema_token) == Some(id) {
          type_id = attr(tier.attributes, "LINGUISTIC_TYPE_REF")
        }
      }
    }
  }
  let tid = match type_id {
    Some(t) => t
    None => raise Invalid("missing: " + "annotation " + id)
  }
  let mut cv_id : String? = None
  for t in schema_select(file.root, ["LINGUISTIC_TYPE"]) {
    if attr(t.attributes, "LINGUISTIC_TYPE_ID") == Some(tid) {
      cv_id = attr(t.attributes, "CONTROLLED_VOCABULARY_REF")
    }
  }
  let cv = match cv_id {
    Some(c) => c
    None => raise Invalid("tier has no CV binding")
  }
  let value = file_cv_value(file, cv, entry_id, language, resource~)
  let edited = file_set_value(file, id, value)
  let root = file_map(edited.root, fn(e) {
    if file_annotation(e) &&
      attr(e.attributes, "ANNOTATION_ID").map(schema_token) == Some(id) {
      {
        ..e,
        attributes: e.attributes.filter(fn(p) {
          p.0 != "CVE_REF" && p.0 != "LANG_REF"
        }) +
        [("CVE_REF", entry_id), ("LANG_REF", language)],
      }
    } else {
      e
    }
  })
  let result = EafFile::{ root, }
  validate_file(result)
  result
}

///|
/// Validate the meaning of CVE_REF bindings, beyond XSD's string datatype.
/// Caller supplies external resources; unavailable external content is an error,
/// never a silently successful validation. No network or file access occurs.
pub fn file_validate_vocabularies(
  file : EafFile,
  resources~ : Array[EafFile] = [],
) -> Unit raise EafError {
  validate_file(file)
  for resource in resources {
    validate_file(resource)
    guard resource.root.name == "CV_RESOURCE" else {
      raise Invalid("expected external CV_RESOURCE")
    }
  }
  for tier in schema_select(file.root, ["TIER"]) {
    let type_id = attr(tier.attributes, "LINGUISTIC_TYPE_REF").unwrap()
    let mut cv_id : String? = None
    for t in schema_select(file.root, ["LINGUISTIC_TYPE"]) {
      if attr(t.attributes, "LINGUISTIC_TYPE_ID") == Some(type_id) {
        cv_id = attr(t.attributes, "CONTROLLED_VOCABULARY_REF")
      }
    }
    for wrapper in tier.children {
      for a in wrapper.children {
        if attr(a.attributes, "CVE_REF") is Some(entry_id) {
          let cv = match cv_id {
            Some(cv) => cv
            None => raise Invalid("CVE_REF without tier vocabulary")
          }
          let candidates = resources.filter(fn(r) {
            r.root.children.any(fn(c) {
              c.name == "CONTROLLED_VOCABULARY" &&
              attr(c.attributes, "CV_ID") == Some(cv)
            })
          })
          guard candidates.length() <= 1 else {
            raise Invalid("ambiguous external vocabulary")
          }
          let resource = if candidates.is_empty() {
            None
          } else {
            Some(candidates[0])
          }
          let languages = if attr(a.attributes, "LANG_REF") is Some(language) {
            [schema_token(language)]
          } else {
            schema_select(file.root, ["LANGUAGE"]).map(fn(l) {
              schema_token(attr(l.attributes, "LANG_ID").unwrap())
            })
          }
          let mut matches = false
          let mut resolved = false
          for language in languages {
            let value = file_cv_value(file, cv, entry_id, language, resource~) catch {
              _ => continue
            }
            resolved = true
            if a.children[0].text == value {
              matches = true
            }
          }
          guard resolved && matches else {
            raise Invalid("unresolved or mismatched CV binding")
          }
        }
      }
    }
  }
}
