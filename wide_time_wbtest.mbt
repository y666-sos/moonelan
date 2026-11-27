///|
test "EAF unsignedInt upper range is preserved" {
  let text = "<ANNOTATION_DOCUMENT AUTHOR=\"\" DATE=\"2026-11-27T00:00:00Z\" VERSION=\"3.0\"><HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID=\"ts1\" TIME_VALUE=\"2147483648\"/><TIME_SLOT TIME_SLOT_ID=\"ts2\" TIME_VALUE=\"4294967295\"/></TIME_ORDER><TIER TIER_ID=\"speech\" LINGUISTIC_TYPE_REF=\"root\"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID=\"a1\" TIME_SLOT_REF1=\"ts1\" TIME_SLOT_REF2=\"ts2\"><ANNOTATION_VALUE>wide</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER><LINGUISTIC_TYPE LINGUISTIC_TYPE_ID=\"root\"/></ANNOTATION_DOCUMENT>"
  let d = parse(text)
  assert_true(write(d).contains("4294967295"))
  assert_true(to_json(d).contains("2147483648"))
}

///|
test "EAF long media origins preserve both signed endpoints" {
  let text = "<ANNOTATION_DOCUMENT AUTHOR=\"\" DATE=\"2026-11-27T00:00:00Z\" VERSION=\"3.0\"><HEADER><MEDIA_DESCRIPTOR MEDIA_URL=\"file:///a.wav\" MIME_TYPE=\"audio/wav\" TIME_ORIGIN=\"-9223372036854775808\"/><MEDIA_DESCRIPTOR MEDIA_URL=\"file:///b.wav\" MIME_TYPE=\"audio/wav\" TIME_ORIGIN=\"9223372036854775807\"/></HEADER><TIME_ORDER/></ANNOTATION_DOCUMENT>"
  assert_true(write(parse(text)).contains("-9223372036854775808"))
}

///|
test "wide times export as exact JSON numbers, not Int64 strings" {
  assert_eq(optional_json_ms(Some(4294967295L)).stringify(), "4294967295")
  assert_eq(optional_json_ms(Some(2147483648L)).stringify(), "2147483648")
  assert_eq(optional_json_ms(None).stringify(), "null")
}
