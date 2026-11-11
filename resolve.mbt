///|
pub(all) struct Span {
  start : Int
  end : Int
} derive(Debug, Eq)

///|
pub extend Span with @debug.Debug::{to_repr}

///|
pub extend Span with Eq::{equal, not_equal}

///|
fn resolved_spans(
  d : Document,
  ix : GraphIndex,
) -> Map[String, Span] raise EafError {
  let spans : Map[String, Span] = Map([])
  for i in ix.order {
    for a in d.tiers[i].annotations {
      let s = match a {
        Aligned(_, lo, hi, _) =>
          Span::{
            start: ix.times.get(lo).unwrap(),
            end: ix.times.get(hi).unwrap(),
          }
        Reference(_, target, _, _) =>
          match spans.get(target) {
            Some(s) => s
            None => raise Invalid("unresolvable annotation referent")
          }
      }
      spans[annotation_id(a)] = s
    }
  }
  spans
}

///|
/// Resolve arbitrarily many symbolic levels without recursion.
pub fn resolve(d : Document, id : String) -> Span raise EafError {
  let ix = graph_index(d, default_limits())
  match resolved_spans(d, ix).get(id) {
    Some(s) => s
    None => raise Invalid("unknown annotation")
  }
}

///|
/// Return the reference path starting at an annotation, ending at an alignable anchor.
pub fn reference_path(
  d : Document,
  id : String,
) -> Array[String] raise EafError {
  let ix = graph_index(d, default_limits())
  let path : Array[String] = []
  let mut cursor = id
  while true {
    let (ti, ai) = match ix.annotations.get(cursor) {
      Some(pair) => pair
      None => raise Invalid("unknown annotation")
    }
    path.push(cursor)
    match d.tiers[ti].annotations[ai] {
      Aligned(_, _, _, _) => break
      Reference(_, target, _, _) => cursor = target
    }
  }
  path
}

///|
/// Half-open temporal overlap. References share their anchor's interval.
pub fn annotations_between(
  d : Document,
  tier : String,
  start : Int,
  end : Int,
) -> Array[Annotation] raise EafError {
  guard start >= 0 && end > start else {
    raise Invalid("invalid query interval")
  }
  let ix = graph_index(d, default_limits())
  let i = match ix.tiers.get(tier) {
    Some(i) => i
    None => raise Invalid("unknown tier")
  }
  let spans = resolved_spans(d, ix)
  d.tiers[i].annotations.filter(fn(a) {
    let s = spans.get(annotation_id(a)).unwrap()
    s.start < end && start < s.end
  })
}

///|
/// Ordered ancestors do not include the tier itself.
pub fn tier_ancestors(
  d : Document,
  tier : String,
) -> Array[String] raise EafError {
  let ix = graph_index(d, default_limits())
  let result : Array[String] = []
  let mut cursor = tier
  while true {
    let i = match ix.tiers.get(cursor) {
      Some(i) => i
      None => raise Invalid("unknown tier")
    }
    match d.tiers[i].parent {
      None => break
      Some(p) => {
        result.push(p)
        cursor = p
      }
    }
  }
  result
}
