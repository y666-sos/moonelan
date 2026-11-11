///|
/// Resample the entire timeline using a positive rational scale and signed offset.
/// Computation uses Int64; integer division floors nonnegative scaled times.
/// A collapsed interval, negative time or Int32 overflow aborts the transaction.
pub fn resample(
  d : Document,
  numerator : Int32,
  denominator : Int32,
  offset~ : Int32 = 0,
) -> Document raise EafError {
  validate(d)
  guard numerator > 0 && denominator > 0 else {
    raise Invalid("time scale must be positive")
  }
  let result = snapshot(d)
  for i, s in result.times {
    let value = s.milliseconds.to_int64() *
      numerator.to_int64() /
      denominator.to_int64() +
      offset.to_int64()
    guard value >= 0L && value <= 2147483647L else {
      raise Invalid("resampled time out of range")
    }
    result.times[i] = { ..s, milliseconds: value.to_int(), }
  }
  validate(result)
  result
}

///|
/// Replace selected time slot values simultaneously, retaining shared anchors.
/// Duplicate edits, unknown slots and invalid resulting constraints are rejected.
pub fn retime(
  d : Document,
  changes : Array[TimeSlot],
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let updates : Map[String, Int32] = Map([])
  for s in changes {
    guard ix.times.contains(s.id) else { raise Invalid("unknown time slot") }
    guard !updates.contains(s.id) else { raise Invalid("duplicate time edit") }
    updates[s.id] = s.milliseconds
  }
  let result = snapshot(d)
  for i, s in result.times {
    if updates.get(s.id) is Some(value) {
      result.times[i] = { ..s, milliseconds: value, }
    }
  }
  validate(result)
  result
}
