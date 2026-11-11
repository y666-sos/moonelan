///|
test "corpus rows retain ancestral labels and half-open windows" {
  let rows = corpus_rows(subdivided_document())
  assert_eq(rows.length(), 4)
  assert_eq(rows[1].path, ["a1", "a2"])
  assert_eq(rows[3].parent, Some("a1"))
  assert_eq(rows[3].sibling_index, 1)
  assert_eq(rows_between(subdivided_document(), 400, 401).map(fn(r) { r.id }), [
    "a1", "a2", "w2",
  ])
}
