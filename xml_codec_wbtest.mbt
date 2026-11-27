///|
test "bounded XML adapter rejects DTD and malformed roots" {
  assert_true(is_eaf_xml("<ANNOTATION_DOCUMENT/>"))
  assert_true(
    !is_eaf_xml("<!DOCTYPE x [<!ENTITY a 'a'>]><ANNOTATION_DOCUMENT/>"),
  )
  assert_true(!is_eaf_xml("<ANNOTATION_DOCUMENT>"))
  assert_eq(parse_milliseconds("2147483647"), 2147483647)
  try parse_milliseconds("4294967296") catch {
    _ => ()
  } noraise {
    _ => fail("overflow accepted")
  }
  let n = xml_tree("<x a='ok'/>", default_limits())
  assert_eq(required(n, "a"), "ok")
  leaf(n)
}
