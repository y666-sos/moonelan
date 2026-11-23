///|
pub(all) struct VocabularyChoice {
  entry_id : String
  language : String
  value : String
  description : String
} derive(Debug, Eq)

///|
pub extend VocabularyChoice with @debug.Debug::{to_repr}

///|
pub extend VocabularyChoice with Eq::{equal, not_equal}

///|
fn tier_vocabulary(d : Document, tier : Tier) -> Element? {
  let attrs = object_attrs(d.extensions.type_attributes, tier.linguistic_type)
  let id = attr(attrs, "CONTROLLED_VOCABULARY_REF")
  for e in d.extensions.elements {
    if e.name == "CONTROLLED_VOCABULARY" && attr(e.attributes, "CV_ID") == id {
      return Some(e)
    }
  }
  None
}

///|
fn choices(cv : Element) -> Array[VocabularyChoice] {
  let result : Array[VocabularyChoice] = []
  for entry in cv.children {
    if entry.name != "CV_ENTRY_ML" {
      continue
    }
    for value in entry.children {
      result.push({
        entry_id: attr(entry.attributes, "CVE_ID").unwrap(),
        language: attr(value.attributes, "LANG_REF").unwrap(),
        value: value.text,
        description: attr(value.attributes, "DESCRIPTION").unwrap_or(""),
      })
    }
  }
  result
}

///|
fn validate_cv_binding(
  d : Document,
  ti : Int32,
  ai : Int32,
  entry : String,
) -> Unit raise EafError {
  let tier = d.tiers[ti]
  let annotation = tier.annotations[ai]
  let cv = match tier_vocabulary(d, tier) {
    Some(cv) => cv
    None => raise Invalid("CVE_REF without tier vocabulary")
  }
  // External resources are retained; their contents cannot be verified offline.
  if attr(cv.attributes, "EXT_REF") != None {
    return
  }
  let language = match
    attr(
      object_attrs(
        d.extensions.annotation_attributes,
        annotation_id(annotation),
      ),
      "LANG_REF",
    ) {
    Some(language) => Some(language)
    None =>
      attr(object_attrs(d.extensions.tier_attributes, tier.id), "LANG_REF")
  }
  guard choices(cv).any(fn(c) {
    c.entry_id == entry &&
    c.value == annotation_value(annotation) &&
    (language == None || language == Some(c.language))
  }) else {
    raise Invalid("vocabulary binding/value/language mismatch")
  }
}

///|
/// List actual internal entry values for a tier and language.
/// External vocabularies require the caller to load a trusted local resource first.
pub fn vocabulary_choices(
  d : Document,
  tier : String,
  language : String,
) -> Array[VocabularyChoice] raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let ti = match ix.tiers.get(tier) {
    Some(i) => i
    None => raise Invalid("unknown tier")
  }
  let cv = match tier_vocabulary(d, d.tiers[ti]) {
    Some(cv) => cv
    None => raise Invalid("tier has no vocabulary")
  }
  guard attr(cv.attributes, "EXT_REF") == None else {
    raise Unsupported("external vocabulary contents not loaded")
  }
  choices(cv).filter(fn(c) { c.language == language })
}

///|
/// Select a vocabulary entry atomically, updating text, CVE_REF and LANG_REF.
pub fn set_controlled_value(
  d : Document,
  id : String,
  entry : String,
  language : String,
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let (ti, ai) = match ix.annotations.get(id) {
    Some(pair) => pair
    None => raise Invalid("unknown annotation")
  }
  let selected = vocabulary_choices(d, d.tiers[ti].id, language).filter(fn(c) {
    c.entry_id == entry
  })
  guard selected.length() == 1 else {
    raise Invalid("unknown vocabulary entry/language")
  }
  let result = snapshot(d)
  let value = selected[0].value
  result.tiers[ti].annotations[ai] = match result.tiers[ti].annotations[ai] {
    Aligned(aid, lo, hi, _) => Aligned(aid, lo, hi, value)
    Reference(aid, target, previous, _) =>
      Reference(aid, target, previous, value)
  }
  let attrs = object_attrs(result.extensions.annotation_attributes, id).filter(fn(
    a,
  ) {
    a.0 != "CVE_REF" && a.0 != "LANG_REF"
  })
  attrs.push(("CVE_REF", entry))
  attrs.push(("LANG_REF", language))
  let metadata = result.extensions.annotation_attributes.filter(fn(x) {
    x.id != id
  })
  metadata.push({ id, values: attrs, })
  let result = {
    ..result,
    extensions: { ..result.extensions, annotation_attributes: metadata, },
  }
  validate(result)
  result
}
