///|
/// Frame-based, partially unaligned project with an explicitly supplied ECV.
/// Run without network access: URLs are identifiers, not an instruction to fetch.
fn main raise {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="demo" DATE="2026-11-27T24:00:00Z" VERSION="3.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://example.org/eaf.xsd">
    #|<HEADER TIME_UNITS="PAL-frames"><MEDIA_DESCRIPTOR MEDIA_URL="file:///movie.mp4" MIME_TYPE="video/mp4" TIME_ORIGIN="-9223372036854775808"/></HEADER>
    #|<TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s1"/><TIME_SLOT TIME_SLOT_ID="e2" TIME_VALUE="4294967295"/></TIME_ORDER>
    #|<TIER TIER_ID="speech" LINGUISTIC_TYPE_REF="kind"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a" TIME_SLOT_REF1="s1" TIME_SLOT_REF2="e2"><ANNOTATION_VALUE>draft</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="kind" CONTROLLED_VOCABULARY_REF="external"/>
    #|<LANGUAGE LANG_ID="eng"/>
    #|<CONTROLLED_VOCABULARY CV_ID="external" EXT_REF="ecv"><DESCRIPTION LANG_REF="eng">External categories</DESCRIPTION></CONTROLLED_VOCABULARY>
    #|<EXTERNAL_REF EXT_REF_ID="ecv" TYPE="ecv" VALUE="https://example.org/vocab.ecv"/>
    #|</ANNOTATION_DOCUMENT>
  let resource =
    #|<CV_RESOURCE AUTHOR="demo" VERSION="0.2"><LANGUAGE LANG_ID="eng"/><CONTROLLED_VOCABULARY CV_ID="external"><CV_ENTRY_ML CVE_ID="noun"><CVE_VALUE LANG_REF="eng" DESCRIPTION="category">noun</CVE_VALUE></CV_ENTRY_ML></CONTROLLED_VOCABULARY></CV_RESOURCE>
  let input = @eaf.parse_file(xml)
  let ecv = @eaf.parse_file(resource)
  let edited = @eaf.file_select_cv(
    input,
    "a",
    "noun",
    "eng",
    resource=Some(ecv),
  )
  @eaf.file_validate_vocabularies(edited, resources=[ecv])
  try @eaf.file_validate_vocabularies(edited) catch {
    _ => ()
  } noraise {
    _ => abort("external CV was not supplied")
  }
  let edited = @eaf.file_rename_annotation(edited, "a", "utterance_1")
  let edited = @eaf.file_set_time(edited, "s1", Some(2147483648L))
  let output = @eaf.write_file(edited)
  assert_true(output.contains("PAL-frames"))
  assert_true(output.contains("4294967295"))
  assert_true(output.contains("-9223372036854775808"))
  assert_true(output.contains("CVE_REF=\"noun\""))
  assert_true(!@eaf.write_file(input).contains("CVE_REF"))
  assert_eq(@eaf.parse_file(output), edited)
  println(output)
  println("EAF30_WORKFLOW_END")
  println(@eaf.write_file(ecv))
}
