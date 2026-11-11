///|
/// Rename an annotation and atomically rewrite referents and predecessor links.
pub fn rename_annotation(
  d : Document,
  old : String,
  name : String,
) -> Document raise EafError {
  validate(d)
  validate_identifier(name)
  let ix = graph_index(d, default_limits())
  guard ix.annotations.contains(old) else {
    raise Invalid("unknown annotation")
  }
  guard old == name || !ix.annotations.contains(name) else {
    raise Invalid("annotation name collision")
  }
  let result = snapshot(d)
  for t in result.tiers {
    for i, a in t.annotations {
      let id = if annotation_id(a) == old { name } else { annotation_id(a) }
      t.annotations[i] = match a {
        Aligned(_, lo, hi, v) => Aligned(id, lo, hi, v)
        Reference(_, target, previous, v) =>
          Reference(
            id,
            if target == old {
              name
            } else {
              target
            },
            if previous == Some(old) {
              Some(name)
            } else {
              previous
            },
            v,
          )
      }
    }
  }
  validate(result)
  result
}

///|
/// Rename a tier without changing annotation identity or hierarchy ownership.
pub fn rename_tier(
  d : Document,
  old : String,
  name : String,
) -> Document raise EafError {
  validate(d)
  validate_identifier(name)
  let ix = graph_index(d, default_limits())
  guard ix.tiers.contains(old) else { raise Invalid("unknown tier") }
  guard old == name || !ix.tiers.contains(name) else {
    raise Invalid("tier name collision")
  }
  let result = snapshot(d)
  for i, t in result.tiers {
    result.tiers[i] = {
      ..t,
      id: if t.id == old {
        name
      } else {
        t.id
      },
      parent: if t.parent == Some(old) {
        Some(name)
      } else {
        t.parent
      },
    }
  }
  validate(result)
  result
}

///|
/// Replace text without exposing mutable arrays shared with the input document.
pub fn set_value(
  d : Document,
  id : String,
  value : String,
) -> Document raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let (ti, ai) = match ix.annotations.get(id) {
    Some(p) => p
    None => raise Invalid("unknown annotation")
  }
  let result = snapshot(d)
  result.tiers[ti].annotations[ai] = match result.tiers[ti].annotations[ai] {
    Aligned(id, lo, hi, _) => Aligned(id, lo, hi, value)
    Reference(id, target, previous, _) => Reference(id, target, previous, value)
  }
  validate(result)
  result
}
