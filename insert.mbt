///|
/// Replace a tier's annotations as one transaction, including subdivision groups.
/// Extra time slots are added before validation; identifiers must remain unique.
pub fn replace_annotations(
  d : Document,
  tier : String,
  annotations : Array[Annotation],
  times~ : Array[TimeSlot] = [],
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let ti = match ix.tiers.get(tier) {
    Some(i) => i
    None => raise Invalid("unknown tier")
  }
  let result = snapshot(d)
  for s in times {
    result.times.push(s)
  }
  result.tiers[ti] = { ..result.tiers[ti], annotations: annotations.copy(), }
  validate(result)
  result
}

///|
/// Add a new dependent or root tier and its linguistic type atomically.
/// Existing type names may be reused only with exactly the same constraint.
pub fn add_tier(
  d : Document,
  tier : Tier,
  constraint : Constraint,
  times~ : Array[TimeSlot] = [],
) -> Document raise EafError {
  validate(d)
  let result = snapshot(d)
  let existing = result.types.filter(fn(t) { t.id == tier.linguistic_type })
  if existing.is_empty() {
    result.types.push({ id: tier.linguistic_type, constraint, })
  } else {
    guard existing[0].constraint == constraint else {
      raise Invalid("linguistic type constraint conflict")
    }
  }
  result.tiers.push({ ..tier, annotations: tier.annotations.copy(), })
  for s in times {
    result.times.push(s)
  }
  validate(result)
  result
}

///|
/// Insert one symbolic child immediately after a sibling (None means head).
/// The former successor is rewired, so an insertion never forks a valid chain.
pub fn insert_reference(
  d : Document,
  tier : String,
  id : String,
  parent : String,
  value : String,
  after~ : String? = None,
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let ti = match ix.tiers.get(tier) {
    Some(i) => i
    None => raise Invalid("unknown tier")
  }
  let c = ix.types.get(d.tiers[ti].linguistic_type).unwrap()
  guard c == SymbolicAssociation || c == SymbolicSubdivision else {
    raise Invalid("insert_reference requires symbolic tier")
  }
  let siblings = children(d, tier, parent)
  match after {
    Some(p) => {
      guard siblings.any(fn(a) { annotation_id(a) == p }) else {
        raise Invalid("predecessor is not a sibling")
      }
    }
    None => ()
  }
  let result = snapshot(d)
  for i, a in result.tiers[ti].annotations {
    if a is Reference(aid, target, previous, v) {
      if target == parent && previous == after {
        result.tiers[ti].annotations[i] = Reference(aid, target, Some(id), v)
      }
    }
  }
  result.tiers[ti].annotations.push(Reference(id, parent, after, value))
  validate(result)
  result
}
