///|
test "renames rewrite the hierarchy and leave the original untouched" {
  let d = sample_document()
  let renamed = rename_annotation(d, "a1", "utterance1")
  assert_eq(reference_path(renamed, "a2"), ["a2", "utterance1"])
  let renamed = rename_tier(renamed, "speech", "utterances")
  assert_eq(renamed.tiers[1].parent, Some("utterances"))
  assert_eq(
    annotation_value(set_value(d, "a1", "new").tiers[0].annotations[0]),
    "new",
  )
  assert_eq(annotation_id(d.tiers[0].annotations[0]), "a1")
  try rename_annotation(d, "a1", "a2") catch {
    _ => ()
  } noraise {
    _ => fail("collision")
  }
  assert_eq(d, sample_document())
}
