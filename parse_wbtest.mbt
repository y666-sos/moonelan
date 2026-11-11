///|
test "strict EAF reader builds semantic references with decoded text" {
  let text =
    #|<ANNOTATION_DOCUMENT AUTHOR="a" DATE="2026-11-11T00:00:00Z" FORMAT="3.0" VERSION="3.0">
    #|<HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s0" TIME_VALUE="0"/><TIME_SLOT TIME_SLOT_ID="s1" TIME_VALUE="100"/></TIME_ORDER>
    #|<TIER TIER_ID="t" LINGUISTIC_TYPE_REF="root"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a" TIME_SLOT_REF1="s0" TIME_SLOT_REF2="s1"><ANNOTATION_VALUE>A &amp; 中</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="root" TIME_ALIGNABLE="true"/>
    #|</ANNOTATION_DOCUMENT>
  let d = parse(text)
  assert_eq(annotation_value(d.tiers[0].annotations[0]), "A & 中")
  assert_eq(resolve(d, "a"), { start: 0, end: 100, })
  try
    parse(text.replace(old="<HEADER/>", new="<HEADER/><LEXICON_REF/>"))
  catch {
    _ => ()
  } noraise {
    _ => fail("unsupported element")
  }
}
