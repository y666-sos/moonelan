///|
fn main raise {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="demo" DATE="2026-11-27T00:00:00Z" VERSION="3.0">
    #|<HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s0"/><TIME_SLOT TIME_SLOT_ID="s1" TIME_VALUE="4294967295"/></TIME_ORDER>
    #|<TIER TIER_ID="speech" LINGUISTIC_TYPE_REF="utterance"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a1" TIME_SLOT_REF1="s0" TIME_SLOT_REF2="s1"><ANNOTATION_VALUE>你好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="utterance"/>
    #|</ANNOTATION_DOCUMENT>
  let input = @eaf.parse_file(xml)
  let edited = @eaf.file_rename_annotation(input, "a1", "utterance_1")
  let edited = @eaf.file_set_time(edited, "s0", Some(2147483648L))
  let output = @eaf.write_file(edited)
  assert_eq(@eaf.parse_file(output), edited)
  assert_true(output.contains("4294967295"))
  println(output)
}
