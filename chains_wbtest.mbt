///|
test "symbolic order is independent of storage order" {
  let d = sample_document()
  let d = {
    ..d,
    types: [
      { id: "utterance", constraint: Independent, },
      { id: "translation", constraint: SymbolicSubdivision, },
    ],
  }
  let d = snapshot(d)
  d.tiers[1].annotations.clear()
  d.tiers[1].annotations.push(Reference("c2", "a1", Some("c1"), "second"))
  d.tiers[1].annotations.push(Reference("c1", "a1", None, "first"))
  validate(d)
  assert_eq(children(d, "gloss", "a1").map(annotation_id), ["c1", "c2"])
  d.tiers[1].annotations.push(Reference("c3", "a1", Some("c1"), "fork"))
  try validate(d) catch {
    _ => ()
  } noraise {
    _ => fail("fork accepted")
  }
}

///|
test "association rejects duplicate children and previous links" {
  let d = sample_document()
  validate(d)
  d.tiers[1].annotations.push(Reference("extra", "a1", None, "duplicate"))
  try validate(d) catch {
    _ => ()
  } noraise {
    _ => fail("duplicate association")
  }
}
