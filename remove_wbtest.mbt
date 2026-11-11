///|
test "deletion cascades through temporal and reference dependents" {
  let d = subdivided_document()
  try remove_annotation(d, "a1") catch {
    _ => ()
  } noraise {
    _ => fail("dependents require cascade")
  }
  let r = remove_annotation(d, "a1", cascade=true)
  assert_eq(r.tiers.map(fn(t) { t.annotations.length() }), [0, 0, 0])
  assert_eq(r.times.length(), 0)
  try remove_annotation(d, "w1", cascade=true) catch {
    _ => ()
  } noraise {
    _ => fail("partial subdivision must fail")
  }
  assert_eq(remove_tier(d, "speech").tiers.length(), 0)
  assert_eq(d, subdivided_document())
}

///|
test "removing symbolic head reconnects its successor" {
  let d = sample_document()
  let d = add_tier(
    d,
    {
      id: "m",
      linguistic_type: "m",
      parent: Some("speech"),
      participant: "",
      annotator: "",
      annotations: [],
    },
    SymbolicSubdivision,
  )
  let d = insert_reference(d, "m", "m1", "a1", "one")
  let d = insert_reference(d, "m", "m2", "a1", "two", after=Some("m1"))
  let d = remove_annotation(d, "m1")
  assert_eq(children(d, "m", "a1"), [Reference("m2", "a1", None, "two")])
}
