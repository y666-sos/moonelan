///|
test "batch replacement is atomic when temporal coverage would be broken" {
  let d = subdivided_document()
  try
    replace_annotations(d, "words", [Aligned("w1", "ts0", "tsm", "bad")])
  catch {
    _ => ()
  } noraise {
    _ => fail("incomplete subdivision")
  }
  assert_eq(d, subdivided_document())
}

///|
test "symbolic insertion repairs successor and rejects foreign predecessors" {
  let d = sample_document()
  let d = add_tier(
    d,
    {
      id: "morph",
      linguistic_type: "morphemes",
      parent: Some("speech"),
      participant: "",
      annotator: "",
      annotations: [],
    },
    SymbolicSubdivision,
  )
  let d = insert_reference(d, "morph", "m2", "a1", "second")
  let d = insert_reference(d, "morph", "m1", "a1", "first")
  let d = insert_reference(d, "morph", "m3", "a1", "third", after=Some("m2"))
  assert_eq(children(d, "morph", "a1").map(annotation_id), ["m1", "m2", "m3"])
  try insert_reference(d, "morph", "m4", "a1", "bad", after=Some("a2")) catch {
    _ => ()
  } noraise {
    _ => fail("foreign sibling")
  }
}
