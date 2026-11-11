///|
fn subdivided_document() -> Document {
  let d = sample_document()
  {
    ..d,
    times: d.times + [{ id: "tsm", milliseconds: 400, }],
    types: d.types + [{ id: "word", constraint: TimeSubdivision, }],
    tiers: d.tiers +
    [
      {
        id: "words",
        linguistic_type: "word",
        parent: Some("speech"),
        participant: "",
        annotator: "",
        annotations: [
          Aligned("w1", "ts0", "tsm", "你"),
          Aligned("w2", "tsm", "ts1", "好"),
        ],
      },
    ],
  }
}

///|
test "time subdivisions tile the containing annotation" {
  let d = subdivided_document()
  validate_temporal(d)
  assert_eq(parent_annotation(d, "w1"), Some("a1"))
  let bad = snapshot(d)
  bad.tiers[2].annotations.remove(0) |> ignore
  try validate_temporal(bad) catch {
    _ => ()
  } noraise {
    _ => fail("gap accepted")
  }
  let included = {
    ..bad,
    types: bad.types.map(fn(t) {
      if t.id == "word" {
        { ..t, constraint: IncludedIn, }
      } else {
        t
      }
    }),
  }
  validate_temporal(included)
}
