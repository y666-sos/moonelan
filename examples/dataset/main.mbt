///|
fn main raise {
  let d = @eaf.select_tiers(@fixture.corpus(0), ["pos", "translation"])
  let rows = @eaf.corpus_rows(d)
  assert_eq(rows.length(), 20)
  let labels = rows.filter(fn(r) { r.tier == "pos" })
  assert_eq(labels[0].path.length(), 4)
  assert_eq(labels[0].span.start, 0)
  println(@eaf.to_json(d))
}
