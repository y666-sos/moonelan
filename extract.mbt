///|
/// Retain selected tiers plus every ancestor tier required to interpret them.
/// Full ancestor annotations avoid breaking temporal subdivisions and chains.
pub fn select_tiers(
  d : Document,
  tiers : Array[String],
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let keep : Map[String, Bool] = Map([])
  for id in tiers {
    guard ix.tiers.contains(id) else { raise Invalid("unknown selected tier") }
    keep[id] = true
    for ancestor in tier_ancestors(d, id) {
      keep[ancestor] = true
    }
  }
  let result = snapshot(d)
  compact(
    prune_extension_owners({
      ..result,
      tiers: result.tiers.filter(fn(t) { keep.contains(t.id) }),
    }),
  )
}

///|
/// Extract complete utterance subtrees rooted at independent annotations.
/// Empty tiers retain their hierarchy; unused times and types are pruned.
pub fn extract_roots(
  d : Document,
  roots : Array[String],
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let keep : Map[String, Bool] = Map([])
  for id in roots {
    let (ti, _) = match ix.annotations.get(id) {
      Some(p) => p
      None => raise Invalid("unknown root annotation")
    }
    guard d.tiers[ti].parent == None else {
      raise Invalid("extraction root must belong to independent tier")
    }
    keep[id] = true
  }
  let parents = annotation_parents(d, ix)
  for ti in ix.order {
    for a in d.tiers[ti].annotations {
      if parents.get(annotation_id(a)) is Some(p) {
        if keep.contains(p) {
          keep[annotation_id(a)] = true
        }
      }
    }
  }
  let result = snapshot(d)
  for i, t in result.tiers {
    result.tiers[i] = {
      ..t,
      annotations: t.annotations.filter(fn(a) {
        keep.contains(annotation_id(a))
      }),
    }
  }
  compact(prune_extension_owners(result))
}
