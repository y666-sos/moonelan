///|
priv struct GraphIndex {
  tiers : Map[String, Int32]
  types : Map[String, Constraint]
  times : Map[String, Int64?]
  annotations : Map[String, (Int32, Int32)]
  order : Array[Int32]
}

///|
/// Index construction also verifies identifiers, cardinalities and tier DAGs.
fn graph_index(d : Document, limits : Limits) -> GraphIndex raise EafError {
  guard limits.tiers > 0 &&
    limits.annotations > 0 &&
    limits.annotations <= 1000000 &&
    limits.depth > 0 else {
    raise Budget("invalid structural limits")
  }
  guard d.tiers.length() <= limits.tiers && d.types.length() <= limits.tiers else {
    raise Budget("too many tiers or linguistic types")
  }
  guard d.times.length() <= limits.annotations * 2 else {
    raise Budget("too many time slots")
  }
  guard d.version == "2.8" || d.version == "3.0" else {
    raise Unsupported("EAF version")
  }
  validate_metadata(d)
  let xml_ids : Map[String, Bool] = Map([])
  for
    c in [TimeSubdivision, IncludedIn, SymbolicAssociation, SymbolicSubdivision] {
    xml_ids[constraint_name(c)] = true
  }
  let tiers : Map[String, Int32] = Map([])
  let types : Map[String, Constraint] = Map([])
  let times : Map[String, Int64?] = Map([])
  let annotations : Map[String, (Int32, Int32)] = Map([])
  for t in d.types {
    validate_identifier(t.id)
    guard !types.contains(t.id) else {
      raise Invalid("duplicate linguistic type")
    }
    types[t.id] = t.constraint
  }
  for s in d.times {
    validate_xml_id(s.id)
    guard !xml_ids.contains(s.id) else { raise Invalid("XML ID collision") }
    xml_ids[s.id] = true
    if s.milliseconds is Some(ms) {
      guard ms >= 0L && ms <= 4294967295L else {
        raise Invalid("negative time slot")
      }
    }
    guard !times.contains(s.id) else { raise Invalid("duplicate time slot") }
    times[s.id] = s.milliseconds
  }
  let mut count = 0
  for i, t in d.tiers {
    validate_identifier(t.id)
    guard !tiers.contains(t.id) else { raise Invalid("duplicate tier") }
    guard types.contains(t.linguistic_type) else {
      raise Invalid("unknown linguistic type")
    }
    tiers[t.id] = i
    count += t.annotations.length()
    guard count <= limits.annotations else {
      raise Budget("too many annotations")
    }
    for j, a in t.annotations {
      let id = annotation_id(a)
      validate_xml_id(id)
      guard !xml_ids.contains(id) else { raise Invalid("XML ID collision") }
      xml_ids[id] = true
      guard !annotations.contains(id) else {
        raise Invalid("duplicate annotation")
      }
      annotations[id] = (i, j)
    }
  }
  for t in d.tiers {
    let c = types.get(t.linguistic_type).unwrap()
    match t.parent {
      None => {
        guard c == Independent else {
          raise Invalid("dependent type lacks parent tier")
        }
      }
      Some(parent) => {
        guard tiers.contains(parent) else {
          raise Invalid("missing parent tier")
        }
        guard c != Independent else {
          raise Invalid("independent tier has parent")
        }
      }
    }
    for a in t.annotations {
      match a {
        Aligned(_, s1, s2, _) => {
          guard is_time_alignable(c) else {
            raise Invalid("aligned annotation on symbolic tier")
          }
          guard times.contains(s1) && times.contains(s2) else {
            raise Invalid("missing time slot")
          }
          if times.get(s1).unwrap() is Some(lo) &&
            times.get(s2).unwrap() is Some(hi) {
            guard lo < hi else { raise Invalid("nonpositive annotation span") }
          }
        }
        Reference(_, target, previous, _) => {
          guard !is_time_alignable(c) else {
            raise Invalid("reference annotation on temporal tier")
          }
          guard annotations.contains(target) else {
            raise Invalid("missing annotation referent")
          }
          let (ti, _) = annotations.get(target).unwrap()
          guard t.parent == Some(d.tiers[ti].id) else {
            raise Invalid("reference must target immediate parent tier")
          }
          match previous {
            Some(id) => {
              guard annotations.contains(id) else {
                raise Invalid("missing previous annotation")
              }
            }
            None => ()
          }
        }
      }
    }
  }
  // Kahn ordering avoids recursion and detects parent-tier cycles.
  let order : Array[Int32] = []
  let done : Map[String, Bool] = Map([])
  let depths : Map[String, Int32] = Map([])
  while order.length() < d.tiers.length() {
    let before = order.length()
    for i, t in d.tiers {
      if done.contains(t.id) {
        continue
      }
      let depth = match t.parent {
        None => 1
        Some(p) =>
          match depths.get(p) {
            Some(n) => n + 1
            None => continue
          }
      }
      guard depth <= limits.depth else {
        raise Budget("tier hierarchy too deep")
      }
      done[t.id] = true
      depths[t.id] = depth
      order.push(i)
    }
    guard order.length() > before else {
      raise Invalid("cyclic tier hierarchy")
    }
  }
  let ix = GraphIndex::{ tiers, types, times, annotations, order, }
  validate_extensions(d, ix, xml_ids, limits)
  ix
}

///|
/// Structural validation is useful before temporal policy checks.
pub fn validate_structure(
  d : Document,
  limits~ : Limits = default_limits(),
) -> Unit raise EafError {
  let ix = graph_index(d, limits)
  ignore(ix.tiers.length())
  ignore(ix.types.length())
  ignore(ix.times.length())
  ignore(ix.annotations.length())
}

///|
/// Deterministic parent-before-child tier order, preserving input order for peers.
pub fn tier_order(d : Document) -> Array[String] raise EafError {
  let ix = graph_index(d, default_limits())
  ix.order.map(fn(i) { d.tiers[i].id })
}
