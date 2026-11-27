///|
/// Map each temporal dependent annotation to exactly one containing parent.
fn temporal_parents(
  d : Document,
  ix : GraphIndex,
  spans : Map[String, Span],
) -> Map[String, String] raise EafError {
  let parents : Map[String, String] = Map([])
  for ti in ix.order {
    let tier = d.tiers[ti]
    let c = ix.types.get(tier.linguistic_type).unwrap()
    if !is_time_alignable(c) {
      continue
    }
    let ordered = tier.annotations.copy()
    ordered.sort_by(fn(a, b) {
      spans.get(annotation_id(a)).unwrap().start.compare(
        spans.get(annotation_id(b)).unwrap().start,
      )
    })
    let mut last_end = -1L
    for a in ordered {
      let s = spans.get(annotation_id(a)).unwrap()
      guard s.start >= last_end else {
        raise Invalid("overlapping annotations within temporal tier")
      }
      last_end = s.end
    }
    let parent_id = match tier.parent {
      None => continue
      Some(p) => p
    }
    let parent_tier = d.tiers[ix.tiers.get(parent_id).unwrap()]
    let groups : Map[String, Array[Span]] = Map([])
    for a in ordered {
      let s = spans.get(annotation_id(a)).unwrap()
      let mut found : String? = None
      for p in parent_tier.annotations {
        let ps = spans.get(annotation_id(p)).unwrap()
        if ps.start <= s.start && s.end <= ps.end {
          guard found == None else {
            raise Invalid("ambiguous temporal parent")
          }
          found = Some(annotation_id(p))
        }
      }
      let p = match found {
        Some(p) => p
        None => raise Invalid("dependent annotation outside parent")
      }
      parents[annotation_id(a)] = p
      match groups.get(p) {
        Some(xs) => xs.push(s)
        None => groups[p] = [s]
      }
    }
    if c == TimeSubdivision {
      // Annotated parent groups must be gapless and span the complete parent.
      // Empty groups are allowed: a partially annotated corpus can omit a parent.
      for p, children in groups {
        let ps = spans.get(p).unwrap()
        let mut cursor = ps.start
        for s in children {
          guard s.start == cursor else {
            raise Invalid("gap in Time_Subdivision")
          }
          cursor = s.end
        }
        guard cursor == ps.end else {
          raise Invalid("incomplete Time_Subdivision")
        }
      }
    }
  }
  parents
}

///|
/// Temporal tier constraints; symbolic chain rules are a separate validation step.
pub fn validate_temporal(d : Document) -> Unit raise EafError {
  let ix = graph_index(d, default_limits())
  let spans = structural_spans(d, ix)
  ignore(temporal_parents(d, ix, spans))
}

///|
/// Identify the direct parent of temporal or symbolic dependent annotations.
pub fn parent_annotation(d : Document, id : String) -> String? raise EafError {
  let ix = graph_index(d, default_limits())
  let (ti, ai) = match ix.annotations.get(id) {
    Some(p) => p
    None => raise Invalid("unknown annotation")
  }
  match d.tiers[ti].annotations[ai] {
    Reference(_, p, _, _) => Some(p)
    Aligned(_, _, _, _) =>
      temporal_parents(d, ix, structural_spans(d, ix)).get(id)
  }
}
