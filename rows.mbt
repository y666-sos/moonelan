///|
/// One annotation with resolved time, hierarchy path and sibling position.
pub(all) struct CorpusRow {
  tier : String
  participant : String
  id : String
  parent : String?
  root : String
  path : Array[String]
  span : Span
  sibling_index : Int32
  value : String
} derive(Debug, Eq)

///|
pub extend CorpusRow with @debug.Debug::{to_repr}

///|
pub extend CorpusRow with Eq::{equal, not_equal}

///|
/// Produce topological tier rows, then parent groups and semantic sibling order.
/// Symbolic subdivisions sharing a time interval remain separate ordered rows.
pub fn corpus_rows(d : Document) -> Array[CorpusRow] raise EafError {
  corpus_records(d).map(r => {
    let (start, end) = match (r.timing.start_ms, r.timing.end_ms) {
      (Some(start), Some(end)) => (start, end)
      _ =>
        raise Invalid("corpus_rows requires aligned times; use corpus_records")
    }
    CorpusRow::{
      tier: r.tier,
      participant: r.participant,
      id: r.id,
      parent: r.parent,
      root: r.root,
      path: r.path.copy(),
      span: { start, end, },
      sibling_index: r.sibling_index,
      value: r.value,
    }
  })
}

///|
/// A dataset record can retain real unaligned boundaries without guessing times.
pub(all) struct CorpusRecord {
  tier : String
  participant : String
  id : String
  parent : String?
  root : String
  path : Array[String]
  timing : Timing
  cv_entry : String?
  sibling_index : Int32
  value : String
} derive(Debug, Eq)

///|
pub extend CorpusRecord with @debug.Debug::{to_repr}

///|
pub extend CorpusRecord with Eq::{equal, not_equal}

///|
pub fn corpus_records(d : Document) -> Array[CorpusRecord] raise EafError {
  validate(d)
  let ix = graph_index(d, default_limits())
  let spans = structural_spans(d, ix)
  let parents = annotation_parents(d, ix)
  let paths : Map[String, Array[String]] = Map([])
  let result : Array[CorpusRecord] = []
  for ti in ix.order {
    let t = d.tiers[ti]
    let c = ix.types.get(t.linguistic_type).unwrap()
    let groups : Map[String, Array[Annotation]] = Map([])
    let group_order : Array[String] = []
    let ordered = t.annotations.copy()
    ordered.sort_by(fn(a, b) {
      let sa = spans.get(annotation_id(a)).unwrap()
      let sb = spans.get(annotation_id(b)).unwrap()
      if sa.start == sb.start {
        annotation_id(a).compare(annotation_id(b))
      } else {
        sa.start.compare(sb.start)
      }
    })
    for a in ordered {
      let group = parents.get(annotation_id(a)).unwrap_or("")
      match groups.get(group) {
        Some(xs) => xs.push(a)
        None => {
          group_order.push(group)
          groups[group] = [a]
        }
      }
    }
    for group in group_order {
      let siblings = groups.get(group).unwrap()
      let siblings = if is_time_alignable(c) {
        siblings
      } else {
        sibling_chain(siblings, c == SymbolicAssociation)
      }
      for index, a in siblings {
        let id = annotation_id(a)
        let parent = parents.get(id)
        let path = match parent {
          None => []
          Some(p) => paths.get(p).unwrap().copy()
        }
        path.push(id)
        paths[id] = path
        result.push({
          tier: t.id,
          participant: t.participant,
          id,
          parent,
          root: path[0],
          path: path.copy(),
          timing: timing_from_index(d, ix, id),
          cv_entry: attr(
            object_attrs(d.extensions.annotation_attributes, id),
            "CVE_REF",
          ),
          sibling_index: index,
          value: annotation_value(a),
        })
      }
    }
  }
  result
}

///|
/// Select resolved rows in one half-open time window, including symbolic labels.
pub fn rows_between(
  d : Document,
  start : Int32,
  end : Int32,
) -> Array[CorpusRow] raise EafError {
  guard start >= 0 && end > start else {
    raise Invalid("invalid row time window")
  }
  corpus_rows(d).filter(fn(r) { r.span.start < end && start < r.span.end })
}
