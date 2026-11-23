///|
test "rational resampling propagates inherited spans and checks overflow" {
  let d = subdivided_document()
  let shifted = resample(d, 3, 2, offset=10)
  assert_eq(resolve(shifted, "a2"), { start: 10, end: 1510, })
  assert_eq(resolve(shifted, "w1"), { start: 10, end: 610, })
  try resample(d, 2147483647, 1) catch {
    _ => ()
  } noraise {
    _ => fail("overflow")
  }
  try resample(d, 1, 10000) catch {
    _ => ()
  } noraise {
    _ => fail("collapse")
  }
  try resample(d, 1, 1, offset=-1) catch {
    _ => ()
  } noraise {
    _ => fail("negative")
  }
  assert_eq(d, subdivided_document())
}

///|
test "shared anchor retiming adjusts both neighboring subdivisions" {
  let d = subdivided_document()
  let boundary = match d.tiers[2].annotations[0] {
    Aligned(_, _, hi, _) => hi
    _ => ""
  }
  let changed = retime(d, [{ id: boundary, milliseconds: Some(500), }])
  assert_eq(resolve(changed, "w1").end, 500)
  assert_eq(resolve(changed, "w2").start, 500)
  try retime(d, [{ id: boundary, milliseconds: Some(1500), }]) catch {
    _ => ()
  } noraise {
    _ => fail("invalid parent coverage")
  }
}
