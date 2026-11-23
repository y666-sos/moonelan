///|
/// Explicit annotation boundaries. None is an unaligned boundary, never zero.
pub(all) struct Timing {
  start_ms : Int32?
  end_ms : Int32?
} derive(Debug, Eq)

///|
pub extend Timing with @debug.Debug::{to_repr}

///|
pub extend Timing with Eq::{equal, not_equal}

///|
fn exact_time(ix : GraphIndex, slot : String) -> Int32 raise EafError {
  match ix.times.get(slot).unwrap() {
    Some(ms) => ms
    None =>
      raise Invalid(
        "time is unaligned; use annotation_timing or corpus_records",
      )
  }
}

///|
/// References inherit both optional boundaries of their alignable ancestor.
pub fn annotation_timing(d : Document, id : String) -> Timing raise EafError {
  let ix = graph_index(d, default_limits())
  timing_from_index(d, ix, id)
}

///|
fn timing_from_index(
  d : Document,
  ix : GraphIndex,
  id : String,
) -> Timing raise EafError {
  let mut current = id
  while true {
    let (ti, ai) = match ix.annotations.get(current) {
      Some(pair) => pair
      None => raise Invalid("unknown annotation")
    }
    match d.tiers[ti].annotations[ai] {
      Aligned(_, lo, hi, _) =>
        return {
          start_ms: ix.times.get(lo).unwrap(),
          end_ms: ix.times.get(hi).unwrap(),
        }
      Reference(_, parent, _, _) => current = parent
    }
  } nobreak {
    raise Invalid("missing timing")
  }
}

///|
/// Coordinates for containment and subdivision checks, not inferred milliseconds.
/// With missing values TIME_ORDER supplies ordering; known equal times coincide.
fn structural_spans(
  d : Document,
  ix : GraphIndex,
) -> Map[String, Span] raise EafError {
  if !d.times.any(fn(s) { s.milliseconds == None }) {
    return resolved_spans(d, ix)
  }
  let coordinates : Map[String, Int32] = Map([])
  let mut rank = 0
  let mut previous_time : Int32? = None
  let mut previous_was_known = false
  for s in d.times {
    if s.milliseconds is Some(ms) {
      if previous_time is Some(prev) {
        guard ms >= prev else {
          raise Invalid("unordered anchors around unaligned slots")
        }
        if ms == prev && previous_was_known {
          rank -= 1
        }
      }
      previous_time = Some(ms)
      previous_was_known = true
    } else {
      previous_was_known = false
    }
    coordinates[s.id] = rank
    rank += 1
  }
  let spans : Map[String, Span] = Map([])
  for ti in ix.order {
    for a in d.tiers[ti].annotations {
      let s = match a {
        Aligned(_, lo, hi, _) =>
          {
            start: coordinates.get(lo).unwrap(),
            end: coordinates.get(hi).unwrap(),
          }
        Reference(_, target, _, _) => spans.get(target).unwrap()
      }
      guard s.end > s.start else {
        raise Invalid("nonpositive slot-order span")
      }
      spans[annotation_id(a)] = s
    }
  }
  spans
}
