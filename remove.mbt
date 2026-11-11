///|
fn annotation_parents(
  d : Document,
  ix : GraphIndex,
) -> Map[String, String] raise EafError {
  let result = temporal_parents(d, ix, resolved_spans(d, ix))
  for t in d.tiers {
    for a in t.annotations {
      if a is Reference(id, target, _, _) {
        result[id] = target
      }
    }
  }
  result
}

///|
/// Remove unused times/types without renumbering surviving identities.
pub fn compact(d : Document) -> Document raise EafError {
  validate(d)
  let times : Map[String, Bool] = Map([])
  let types : Map[String, Bool] = Map([])
  for t in d.tiers {
    types[t.linguistic_type] = true
    for a in t.annotations {
      if a is Aligned(_, lo, hi, _) {
        times[lo] = true
        times[hi] = true
      }
    }
  }
  let result = snapshot(d)
  {
    ..result,
    times: result.times.filter(fn(s) { times.contains(s.id) }),
    types: result.types.filter(fn(t) { types.contains(t.id) }),
  }
}

///|
/// Delete an annotation; cascade optionally removes all temporal/symbolic descendants.
/// Surviving symbolic successors reconnect to the nearest surviving predecessor.
/// A partial Time_Subdivision removal fails atomically instead of leaving a gap.
pub fn remove_annotation(
  d : Document,
  id : String,
  cascade~ : Bool = false,
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  guard ix.annotations.contains(id) else { raise Invalid("unknown annotation") }
  let parents = annotation_parents(d, ix)
  let removed : Map[String, Bool] = Map([(id, true)])
  for ti in ix.order {
    for a in d.tiers[ti].annotations {
      if parents.get(annotation_id(a)) is Some(p) {
        if removed.contains(p) {
          guard cascade else {
            raise Invalid("annotation has dependent children")
          }
          removed[annotation_id(a)] = true
        }
      }
    }
  }
  let result = snapshot(d)
  for ti, t in result.tiers {
    let kept = t.annotations.filter(fn(a) {
      !removed.contains(annotation_id(a))
    })
    for ai, a in kept {
      if a is Reference(aid, target, previous, v) {
        let mut p = previous
        while p is Some(pid) && removed.contains(pid) {
          let (pti, pai) = ix.annotations.get(pid).unwrap()
          p = match d.tiers[pti].annotations[pai] {
            Reference(_, _, prev, _) => prev
            _ => None
          }
        }
        kept[ai] = Reference(aid, target, p, v)
      }
    }
    result.tiers[ti] = { ..t, annotations: kept, }
  }
  compact(result)
}

///|
/// Delete a tier and its complete dependent tier subtree.
pub fn remove_tier(d : Document, tier : String) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  guard ix.tiers.contains(tier) else { raise Invalid("unknown tier") }
  let removed : Map[String, Bool] = Map([(tier, true)])
  for ti in ix.order {
    let t = d.tiers[ti]
    if t.parent is Some(p) {
      if removed.contains(p) {
        removed[t.id] = true
      }
    }
  }
  let result = snapshot(d)
  compact({
    ..result,
    tiers: result.tiers.filter(fn(t) { !removed.contains(t.id) }),
  })
}
