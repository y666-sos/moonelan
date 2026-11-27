///|
test "tier selection retains required ancestors but omits unrelated tiers" {
  let d = subdivided_document()
  let selected = select_tiers(d, ["words"])
  assert_eq(tier_order(selected), ["speech", "words"])
  assert_eq(selected.types.length(), 2)
  let parsed = parse(write(selected))
  assert_eq({ ..parsed, extensions: selected.extensions, }, selected)
  assert_eq(write(parsed), write(selected))
  assert_eq(select_tiers(d, []).tiers.length(), 0)
}

///|
test "utterance extraction retains temporal and symbolic descendants" {
  let d = subdivided_document()
  assert_eq(extract_roots(d, ["a1"]), d)
  assert_eq(extract_roots(d, []).times.length(), 0)
  try extract_roots(d, ["w1"]) catch {
    _ => ()
  } noraise {
    _ => fail("dependent root")
  }
}
