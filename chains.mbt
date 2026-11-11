///|
/// Return sibling order by PREVIOUS_ANNOTATION rather than XML storage order.
fn sibling_chain(
  xs : Array[Annotation],
  association : Bool,
) -> Array[Annotation] raise EafError {
  if xs.is_empty() {
    return []
  }
  if association {
    guard xs.length() == 1 else {
      raise Invalid("multiple Symbolic_Association children")
    }
    match xs[0] {
      Reference(_, _, None, _) => return xs.copy()
      _ => raise Invalid("association cannot have previous annotation")
    }
  }
  let by_id : Map[String, Annotation] = Map([])
  let next : Map[String, Annotation] = Map([])
  let heads : Array[Annotation] = []
  for a in xs {
    by_id[annotation_id(a)] = a
  }
  for a in xs {
    match a {
      Reference(id, _, previous, _) =>
        match previous {
          None => heads.push(a)
          Some(p) => {
            guard p != id && by_id.contains(p) else {
              raise Invalid("previous annotation outside sibling group")
            }
            guard !next.contains(p) else {
              raise Invalid("forked symbolic order")
            }
            next[p] = a
          }
        }
      _ => raise Invalid("non-reference symbolic child")
    }
  }
  guard heads.length() == 1 else {
    raise Invalid("symbolic group requires one chain head")
  }
  let ordered : Array[Annotation] = [heads[0]]
  while true {
    let id = annotation_id(ordered[ordered.length() - 1])
    match next.get(id) {
      None => break
      Some(a) => ordered.push(a)
    }
    guard ordered.length() <= xs.length() else {
      raise Invalid("cyclic symbolic chain")
    }
  }
  guard ordered.length() == xs.length() else {
    raise Invalid("disconnected symbolic chain")
  }
  ordered
}

///|
fn symbolic_groups(
  d : Document,
  ix : GraphIndex,
) -> Map[String, Array[Annotation]] raise EafError {
  let result : Map[String, Array[Annotation]] = Map([])
  for ti in ix.order {
    let t = d.tiers[ti]
    let c = ix.types.get(t.linguistic_type).unwrap()
    if is_time_alignable(c) {
      continue
    }
    let groups : Map[String, Array[Annotation]] = Map([])
    for a in t.annotations {
      match a {
        Reference(_, p, _, _) =>
          match groups.get(p) {
            Some(xs) => xs.push(a)
            None => groups[p] = [a]
          }
        _ => raise Invalid("invalid symbolic annotation")
      }
    }
    for _, xs in groups {
      let ordered = sibling_chain(xs, c == SymbolicAssociation)
      result[annotation_id(ordered[0])] = ordered
    }
  }
  result
}

///|
/// Full semantic validation, including all dependent tier constraints.
pub fn validate(
  d : Document,
  limits? : Limits = default_limits(),
) -> Unit raise EafError {
  let ix = graph_index(d, limits)
  ignore(temporal_parents(d, ix, resolved_spans(d, ix)))
  ignore(symbolic_groups(d, ix))
}

///|
/// Direct children sorted by time or symbolic previous-chain order.
pub fn children(
  d : Document,
  tier : String,
  parent : String,
) -> Array[Annotation] raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let ti = match ix.tiers.get(tier) {
    Some(i) => i
    None => raise Invalid("unknown tier")
  }
  guard ix.annotations.contains(parent) else {
    raise Invalid("unknown parent annotation")
  }
  let c = ix.types.get(d.tiers[ti].linguistic_type).unwrap()
  let spans = resolved_spans(d, ix)
  let temporal = temporal_parents(d, ix, spans)
  let selected = d.tiers[ti].annotations.filter(fn(a) {
    match a {
      Reference(_, p, _, _) => p == parent
      Aligned(id, _, _, _) => temporal.get(id) == Some(parent)
    }
  })
  if !is_time_alignable(c) {
    return sibling_chain(selected, c == SymbolicAssociation)
  }
  selected.sort_by(fn(a, b) {
    spans.get(annotation_id(a)).unwrap().start.compare(
      spans.get(annotation_id(b)).unwrap().start,
    )
  })
  selected
}
