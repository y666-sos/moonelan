// Generated grammar facts; do not edit. Not counted as production LOC.
// EAF 3.0 schema SHA-256: 59e76f90d5840813314b1e635480d044287b811ebd63a40e25cb4e73c6ad72bb

///|
fn eaf30_rule(name : String) -> SchemaRule? {
  match name {
    "ALIGNABLE_ANNOTATION" =>
      Some({
        type_name: "alignableType",
        attributes: [
          { name: "ANNOTATION_ID", kind: "ID", required: true, choices: [], },
          { name: "EXT_REF", kind: "IDREFS", required: false, choices: [], },
          { name: "LANG_REF", kind: "IDREF", required: false, choices: [], },
          { name: "CVE_REF", kind: "string", required: false, choices: [], },
          {
            name: "TIME_SLOT_REF1",
            kind: "IDREF",
            required: true,
            choices: [],
          },
          {
            name: "TIME_SLOT_REF2",
            kind: "IDREF",
            required: true,
            choices: [],
          },
          { name: "SVG_REF", kind: "string", required: false, choices: [], },
        ],
        children: [{ names: ["ANNOTATION_VALUE"], minimum: 1, maximum: 1, }],
        textual: false,
      })
    "ANNOTATION" =>
      Some({
        type_name: "annotationType",
        attributes: [],
        children: [
          {
            names: ["ALIGNABLE_ANNOTATION", "REF_ANNOTATION"],
            minimum: 1,
            maximum: 1,
          },
        ],
        textual: false,
      })
    "ANNOTATION_DOCUMENT" =>
      Some({
        type_name: "",
        attributes: [
          { name: "DATE", kind: "dateTime", required: true, choices: [], },
          { name: "AUTHOR", kind: "string", required: true, choices: [], },
          { name: "VERSION", kind: "string", required: true, choices: [], },
          { name: "FORMAT", kind: "string", required: false, choices: [], },
        ],
        children: [
          { names: ["LICENSE"], minimum: 0, maximum: -1, },
          { names: ["HEADER"], minimum: 1, maximum: 1, },
          { names: ["TIME_ORDER"], minimum: 1, maximum: 1, },
          { names: ["TIER"], minimum: 0, maximum: -1, },
          { names: ["LINGUISTIC_TYPE"], minimum: 0, maximum: -1, },
          { names: ["LOCALE"], minimum: 0, maximum: -1, },
          { names: ["LANGUAGE"], minimum: 0, maximum: -1, },
          { names: ["CONSTRAINT"], minimum: 0, maximum: -1, },
          { names: ["CONTROLLED_VOCABULARY"], minimum: 0, maximum: -1, },
          { names: ["LEXICON_REF"], minimum: 0, maximum: -1, },
          { names: ["REF_LINK_SET"], minimum: 0, maximum: -1, },
          { names: ["EXTERNAL_REF"], minimum: 0, maximum: -1, },
        ],
        textual: false,
      })
    "ANNOTATION_VALUE" =>
      Some({
        type_name: "xsd:string",
        attributes: [],
        children: [],
        textual: true,
      })
    "CONSTRAINT" =>
      Some({
        type_name: "constraintType",
        attributes: [
          { name: "STEREOTYPE", kind: "ID", required: true, choices: [], },
          { name: "DESCRIPTION", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: false,
      })
    "CONTROLLED_VOCABULARY" =>
      Some({
        type_name: "convocType",
        attributes: [
          { name: "CV_ID", kind: "string", required: true, choices: [], },
          { name: "EXT_REF", kind: "IDREF", required: false, choices: [], },
        ],
        children: [
          { names: ["DESCRIPTION"], minimum: 0, maximum: -1, },
          { names: ["CV_ENTRY_ML"], minimum: 0, maximum: -1, },
        ],
        textual: false,
      })
    "CROSS_REF_LINK" =>
      Some({
        type_name: "crossLinkType",
        attributes: [
          { name: "REF1", kind: "IDREF", required: true, choices: [], },
          { name: "REF2", kind: "IDREF", required: true, choices: [], },
          {
            name: "DIRECTIONALITY",
            kind: "string",
            required: false,
            choices: ["undirected", "unidirectional", "bidirectional"],
          },
          { name: "REF_LINK_ID", kind: "ID", required: true, choices: [], },
          {
            name: "REF_LINK_NAME",
            kind: "string",
            required: false,
            choices: [],
          },
          { name: "EXT_REF", kind: "IDREFS", required: false, choices: [], },
          { name: "LANG_REF", kind: "IDREF", required: false, choices: [], },
          { name: "CVE_REF", kind: "string", required: false, choices: [], },
          { name: "REF_TYPE", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: true,
      })
    "CVE_VALUE" =>
      Some({
        type_name: "cveValueType",
        attributes: [
          { name: "LANG_REF", kind: "IDREF", required: true, choices: [], },
          { name: "DESCRIPTION", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: true,
      })
    "CV_ENTRY_ML" =>
      Some({
        type_name: "cventryType",
        attributes: [
          { name: "CVE_ID", kind: "string", required: true, choices: [], },
          { name: "EXT_REF", kind: "IDREF", required: false, choices: [], },
        ],
        children: [{ names: ["CVE_VALUE"], minimum: 1, maximum: -1, }],
        textual: false,
      })
    "CV_RESOURCE" =>
      Some({
        type_name: "",
        attributes: [
          { name: "DATE", kind: "dateTime", required: false, choices: [], },
          { name: "AUTHOR", kind: "string", required: false, choices: [], },
          { name: "VERSION", kind: "string", required: false, choices: [], },
        ],
        children: [
          { names: ["LANGUAGE"], minimum: 0, maximum: -1, },
          { names: ["CONTROLLED_VOCABULARY"], minimum: 1, maximum: -1, },
          { names: ["EXTERNAL_REF"], minimum: 0, maximum: -1, },
        ],
        textual: false,
      })
    "DESCRIPTION" =>
      Some({
        type_name: "descMultiLangType",
        attributes: [
          { name: "LANG_REF", kind: "IDREF", required: true, choices: [], },
        ],
        children: [],
        textual: true,
      })
    "EXTERNAL_REF" =>
      Some({
        type_name: "extRefType",
        attributes: [
          { name: "EXT_REF_ID", kind: "ID", required: true, choices: [], },
          {
            name: "TYPE",
            kind: "string",
            required: true,
            choices: ["iso12620", "ecv", "cve_id", "lexen_id", "resource_url"],
          },
          { name: "VALUE", kind: "string", required: true, choices: [], },
        ],
        children: [],
        textual: false,
      })
    "GROUP_REF_LINK" =>
      Some({
        type_name: "groupLinkType",
        attributes: [
          { name: "REFS", kind: "IDREFS", required: true, choices: [], },
          { name: "REF_LINK_ID", kind: "ID", required: true, choices: [], },
          {
            name: "REF_LINK_NAME",
            kind: "string",
            required: false,
            choices: [],
          },
          { name: "EXT_REF", kind: "IDREFS", required: false, choices: [], },
          { name: "LANG_REF", kind: "IDREF", required: false, choices: [], },
          { name: "CVE_REF", kind: "string", required: false, choices: [], },
          { name: "REF_TYPE", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: true,
      })
    "HEADER" =>
      Some({
        type_name: "headType",
        attributes: [
          { name: "MEDIA_FILE", kind: "string", required: false, choices: [], },
          {
            name: "TIME_UNITS",
            kind: "string",
            required: false,
            choices: ["NTSC-frames", "PAL-frames", "milliseconds"],
          },
        ],
        children: [
          { names: ["MEDIA_DESCRIPTOR"], minimum: 0, maximum: -1, },
          { names: ["LINKED_FILE_DESCRIPTOR"], minimum: 0, maximum: -1, },
          { names: ["PROPERTY"], minimum: 0, maximum: -1, },
        ],
        textual: false,
      })
    "LANGUAGE" =>
      Some({
        type_name: "langType",
        attributes: [
          { name: "LANG_ID", kind: "ID", required: true, choices: [], },
          { name: "LANG_DEF", kind: "string", required: false, choices: [], },
          { name: "LANG_LABEL", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: false,
      })
    "LEXICON_REF" =>
      Some({
        type_name: "lexRefType",
        attributes: [
          { name: "LEX_REF_ID", kind: "ID", required: true, choices: [], },
          { name: "NAME", kind: "string", required: true, choices: [], },
          { name: "TYPE", kind: "string", required: true, choices: [], },
          { name: "URL", kind: "string", required: true, choices: [], },
          { name: "LEXICON_ID", kind: "string", required: true, choices: [], },
          { name: "LEXICON_NAME", kind: "string", required: true, choices: [], },
          { name: "DATCAT_ID", kind: "string", required: false, choices: [], },
          { name: "DATCAT_NAME", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: false,
      })
    "LICENSE" =>
      Some({
        type_name: "licenseType",
        attributes: [
          { name: "LICENSE_URL", kind: "anyURI", required: false, choices: [], },
        ],
        children: [],
        textual: true,
      })
    "LINGUISTIC_TYPE" =>
      Some({
        type_name: "lingType",
        attributes: [
          {
            name: "LINGUISTIC_TYPE_ID",
            kind: "string",
            required: true,
            choices: [],
          },
          {
            name: "TIME_ALIGNABLE",
            kind: "boolean",
            required: false,
            choices: [],
          },
          { name: "CONSTRAINTS", kind: "IDREF", required: false, choices: [], },
          {
            name: "GRAPHIC_REFERENCES",
            kind: "boolean",
            required: false,
            choices: [],
          },
          {
            name: "CONTROLLED_VOCABULARY_REF",
            kind: "string",
            required: false,
            choices: [],
          },
          { name: "EXT_REF", kind: "IDREF", required: false, choices: [], },
          { name: "LEXICON_REF", kind: "IDREF", required: false, choices: [], },
        ],
        children: [],
        textual: false,
      })
    "LINKED_FILE_DESCRIPTOR" =>
      Some({
        type_name: "",
        attributes: [
          { name: "LINK_URL", kind: "anyURI", required: true, choices: [], },
          {
            name: "RELATIVE_LINK_URL",
            kind: "anyURI",
            required: false,
            choices: [],
          },
          { name: "MIME_TYPE", kind: "string", required: true, choices: [], },
          { name: "TIME_ORIGIN", kind: "long", required: false, choices: [], },
          {
            name: "ASSOCIATED_WITH",
            kind: "anyURI",
            required: false,
            choices: [],
          },
        ],
        children: [],
        textual: false,
      })
    "LOCALE" =>
      Some({
        type_name: "localeType",
        attributes: [
          { name: "LANGUAGE_CODE", kind: "ID", required: true, choices: [], },
          {
            name: "COUNTRY_CODE",
            kind: "string",
            required: false,
            choices: [],
          },
          { name: "VARIANT", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: false,
      })
    "MEDIA_DESCRIPTOR" =>
      Some({
        type_name: "",
        attributes: [
          { name: "MEDIA_URL", kind: "anyURI", required: true, choices: [], },
          {
            name: "RELATIVE_MEDIA_URL",
            kind: "anyURI",
            required: false,
            choices: [],
          },
          { name: "MIME_TYPE", kind: "string", required: true, choices: [], },
          { name: "TIME_ORIGIN", kind: "long", required: false, choices: [], },
          {
            name: "EXTRACTED_FROM",
            kind: "anyURI",
            required: false,
            choices: [],
          },
        ],
        children: [],
        textual: false,
      })
    "PROPERTY" =>
      Some({
        type_name: "propType",
        attributes: [
          { name: "NAME", kind: "string", required: false, choices: [], },
        ],
        children: [],
        textual: true,
      })
    "REF_ANNOTATION" =>
      Some({
        type_name: "refAnnoType",
        attributes: [
          { name: "ANNOTATION_ID", kind: "ID", required: true, choices: [], },
          { name: "EXT_REF", kind: "IDREFS", required: false, choices: [], },
          { name: "LANG_REF", kind: "IDREF", required: false, choices: [], },
          { name: "CVE_REF", kind: "string", required: false, choices: [], },
          {
            name: "ANNOTATION_REF",
            kind: "IDREF",
            required: true,
            choices: [],
          },
          {
            name: "PREVIOUS_ANNOTATION",
            kind: "IDREF",
            required: false,
            choices: [],
          },
        ],
        children: [{ names: ["ANNOTATION_VALUE"], minimum: 1, maximum: 1, }],
        textual: false,
      })
    "REF_LINK_SET" =>
      Some({
        type_name: "refLinksType",
        attributes: [
          { name: "LINK_SET_ID", kind: "ID", required: true, choices: [], },
          {
            name: "LINK_SET_NAME",
            kind: "string",
            required: false,
            choices: [],
          },
          { name: "EXT_REF", kind: "IDREFS", required: false, choices: [], },
          { name: "LANG_REF", kind: "IDREF", required: false, choices: [], },
          { name: "CV_REF", kind: "string", required: false, choices: [], },
        ],
        children: [
          {
            names: ["CROSS_REF_LINK", "GROUP_REF_LINK"],
            minimum: 0,
            maximum: -1,
          },
        ],
        textual: false,
      })
    "TIER" =>
      Some({
        type_name: "tierType",
        attributes: [
          { name: "TIER_ID", kind: "string", required: true, choices: [], },
          { name: "PARTICIPANT", kind: "string", required: false, choices: [], },
          { name: "ANNOTATOR", kind: "string", required: false, choices: [], },
          {
            name: "LINGUISTIC_TYPE_REF",
            kind: "string",
            required: true,
            choices: [],
          },
          {
            name: "DEFAULT_LOCALE",
            kind: "IDREF",
            required: false,
            choices: [],
          },
          { name: "PARENT_REF", kind: "string", required: false, choices: [], },
          { name: "EXT_REF", kind: "IDREF", required: false, choices: [], },
          { name: "LANG_REF", kind: "IDREF", required: false, choices: [], },
        ],
        children: [{ names: ["ANNOTATION"], minimum: 0, maximum: -1, }],
        textual: false,
      })
    "TIME_ORDER" =>
      Some({
        type_name: "timeType",
        attributes: [],
        children: [{ names: ["TIME_SLOT"], minimum: 0, maximum: -1, }],
        textual: false,
      })
    "TIME_SLOT" =>
      Some({
        type_name: "",
        attributes: [
          { name: "TIME_SLOT_ID", kind: "ID", required: true, choices: [], },
          {
            name: "TIME_VALUE",
            kind: "unsignedInt",
            required: false,
            choices: [],
          },
        ],
        children: [],
        textual: false,
      })
    _ => None
  }
}
