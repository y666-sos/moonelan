///|
test "model snapshots own nested arrays" {
  let d = {
    ..empty_document(),
    tiers: [
      {
        id: "t",
        linguistic_type: "root",
        parent: None,
        participant: "",
        annotator: "",
        annotations: [],
      },
    ],
  }
  let c = snapshot(d)
  c.tiers[0].annotations.push(Aligned("a", "s1", "s2", "hello"))
  assert_eq(d.tiers[0].annotations.length(), 0)
  assert_eq(annotation_id(c.tiers[0].annotations[0]), "a")
  assert_eq(constraint_name(SymbolicSubdivision), "Symbolic_Subdivision")
  assert_true(!valid_id("bad id"))
}
