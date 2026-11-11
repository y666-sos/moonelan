///|
test "metadata rejects invalid Gregorian dates XML characters and global ID collisions" {
  for
    date in [
      "2024-02-29T12:30:59.12+08:00", "2026-11-11T00:00:00Z", "2000-02-29T00:00:00",
    ] {
    validate_date(date)
  }
  for
    date in [
      "1900-02-29T00:00:00Z", "2026-11-31T00:00:00Z", "2026-11-11T24:00:00Z", "2026-11-11T00:00:00+14:01",
    ] {
    try validate_date(date) catch {
      _ => ()
    } noraise {
      _ => fail("invalid date accepted")
    }
  }
  let d = sample_document()
  try set_value(d, "a1", "\u0000") catch {
    _ => ()
  } noraise {
    _ => fail("NUL accepted")
  }
  try rename_annotation(d, "a1", "ts0") catch {
    _ => ()
  } noraise {
    _ => fail("XML ID collision")
  }
  try rename_annotation(d, "a1", "1bad") catch {
    _ => ()
  } noraise {
    _ => fail("NCName")
  }
  try
    validate(d, limits={ ..default_limits(), annotations: 2147483647, })
  catch {
    _ => ()
  } noraise {
    _ => fail("budget overflow")
  }
}
