///|
fn main raise {
  let text = @eaf.write(@fixture.corpus(0))
  let imported = @eaf.parse(text)
  @eaf.validate(imported)
  let selected = @eaf.extract_roots(imported, ["a0"])
  assert_eq(@eaf.corpus_rows(selected).length(), 11)
  assert_eq(@eaf.parse(@eaf.write(selected)), selected)
  println("curate: 1 utterance, 11 annotations, 6 tiers, valid EAF roundtrip")
}
