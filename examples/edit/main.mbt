///|
fn main raise {
  let original = @fixture.corpus(1)
  let edited = @eaf.rename_annotation(original, "a0", "utterance_A")
  let edited = @eaf.insert_reference(
    edited, "morphology", "new_morph", "w00", "prefix",
  )
  let edited = @eaf.remove_annotation(edited, "morph_w00_0", cascade=true)
  let edited = @eaf.resample(edited, 1, 1, offset=100)
  assert_eq(
    @eaf.children(edited, "morphology", "w00").map(@eaf.annotation_id),
    ["new_morph", "morph_w00_1"],
  )
  assert_eq(@eaf.reference_path(edited, "tr0"), ["tr0", "utterance_A"])
  assert_eq(@eaf.resolve(original, "tr0").start, 4000)
  @eaf.validate(edited)
  println("edit: rename, insert, cascading delete and timeline shift validated")
}
