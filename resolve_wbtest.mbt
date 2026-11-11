///|
test "symbolic descendants resolve parent intervals" {
  let d = sample_document()
  assert_eq(resolve(d, "a2"), { start: 0, end: 1000, })
  assert_eq(reference_path(d, "a2"), ["a2", "a1"])
  assert_eq(tier_ancestors(d, "gloss"), ["speech"])
  assert_eq(annotations_between(d, "gloss", 1000, 1100).length(), 0)
  assert_eq(annotations_between(d, "gloss", 999, 1100).length(), 1)
  try resolve(d, "missing") catch {
    _ => ()
  } noraise {
    _ => fail("unknown annotation")
  }
}
