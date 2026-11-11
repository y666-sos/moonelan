///|
fn sample_document() -> Document {
  {
    ..empty_document(),
    times: [{ id: "ts0", milliseconds: 0, }, { id: "ts1", milliseconds: 1000, }],
    types: [
      { id: "utterance", constraint: Independent, },
      { id: "translation", constraint: SymbolicAssociation, },
    ],
    tiers: [
      {
        id: "speech",
        linguistic_type: "utterance",
        parent: None,
        participant: "speaker",
        annotator: "",
        annotations: [Aligned("a1", "ts0", "ts1", "你好")],
      },
      {
        id: "gloss",
        linguistic_type: "translation",
        parent: Some("speech"),
        participant: "",
        annotator: "",
        annotations: [Reference("a2", "a1", None, "hello")],
      },
    ],
  }
}

///|
test "index validates reference tier ownership and deterministic DAG order" {
  let d = sample_document()
  validate_structure(d)
  assert_eq(tier_order(d), ["speech", "gloss"])
  let copy = snapshot(d)
  copy.tiers[1].annotations.push(Reference("a1", "a1", None, "duplicate"))
  try validate_structure(copy) catch {
    _ => ()
  } noraise {
    _ => fail("expected duplicate error")
  }
}

///|
test "graph limits and missing slots fail without panics" {
  let d = sample_document()
  try validate_structure({ ..d, times: [], }) catch {
    _ => ()
  } noraise {
    _ => fail("missing slots")
  }
  try
    validate_structure(d, limits={ ..default_limits(), annotations: 1, })
  catch {
    _ => ()
  } noraise {
    _ => fail("budget")
  }
}
