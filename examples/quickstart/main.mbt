///|
fn main raise {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="demo" DATE="2026-11-11T00:00:00Z" FORMAT="3.0" VERSION="3.0">
    #|<HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s0" TIME_VALUE="0"/><TIME_SLOT TIME_SLOT_ID="s1" TIME_VALUE="1000"/></TIME_ORDER>
    #|<TIER TIER_ID="speech" LINGUISTIC_TYPE_REF="utterance"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a1" TIME_SLOT_REF1="s0" TIME_SLOT_REF2="s1"><ANNOTATION_VALUE>你好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="utterance" TIME_ALIGNABLE="true"/>
    #|</ANNOTATION_DOCUMENT>
  let document = @eaf.parse(xml)
  let edited = @eaf.rename_annotation(document, "a1", "utterance_1")
  assert_eq(@eaf.resolve(edited, "utterance_1"), { start: 0, end: 1000, })
  println(@eaf.to_json(edited))
}
