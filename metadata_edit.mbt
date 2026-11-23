///|
fn renamed_attrs(
  xs : Array[ObjectAttributes],
  old : String,
  name : String,
) -> Array[ObjectAttributes] {
  xs.map(fn(x) { { ..x, id: if x.id == old { name } else { x.id }, } })
}

///|
fn rename_link_reference(e : Element, old : String, name : String) -> Element {
  {
    ..e,
    attributes: e.attributes.map(fn(pair) {
      let (key, value) = pair
      if key == "REF1" || key == "REF2" || key == "REFS" {
        (
          key,
          id_words(value)
          .map(fn(id) { if id == old { name } else { id } })
          .join(" "),
        )
      } else {
        pair
      }
    }),
    children: e.children.map(fn(child) {
      rename_link_reference(child, old, name)
    }),
  }
}

///|
fn rename_extension_identity(
  d : Document,
  old : String,
  name : String,
  annotation~ : Bool,
) -> Document {
  let e = d.extensions
  {
    ..d,
    extensions: {
      ..e,
      annotation_attributes: if annotation {
        renamed_attrs(e.annotation_attributes, old, name)
      } else {
        e.annotation_attributes
      },
      tier_attributes: if annotation {
        e.tier_attributes
      } else {
        renamed_attrs(e.tier_attributes, old, name)
      },
      elements: if annotation {
        e.elements.map(fn(node) { rename_link_reference(node, old, name) })
      } else {
        e.elements
      },
    },
  }
}

///|
/// Drop only metadata owned by removed graph objects; retain shared vocabularies.
/// Links whose endpoint was removed, and links to those links, cascade together.
fn prune_extension_owners(d : Document) -> Document {
  let annotations : Map[String, Bool] = Map([])
  let tiers : Map[String, Bool] = Map([])
  let types : Map[String, Bool] = Map([])
  for t in d.tiers {
    tiers[t.id] = true
    types[t.linguistic_type] = true
    for a in t.annotations {
      annotations[annotation_id(a)] = true
    }
  }
  let e = d.extensions
  let live : Map[String, Bool] = annotations.copy()
  for node in e.elements {
    if node.name == "REF_LINK_SET" {
      for link in node.children {
        live[attr(link.attributes, "REF_LINK_ID").unwrap()] = true
      }
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for node in e.elements {
      if node.name != "REF_LINK_SET" {
        continue
      }
      for link in node.children {
        let id = attr(link.attributes, "REF_LINK_ID").unwrap()
        if !live.contains(id) {
          continue
        }
        let targets = if link.name == "CROSS_REF_LINK" {
          [
            attr(link.attributes, "REF1").unwrap(),
            attr(link.attributes, "REF2").unwrap(),
          ]
        } else {
          id_words(attr(link.attributes, "REFS").unwrap())
        }
        if targets.any(fn(target) { !live.contains(target) }) {
          live.remove(id)
          changed = true
        }
      }
    }
  }
  {
    ..d,
    extensions: {
      ..e,
      annotation_attributes: e.annotation_attributes.filter(fn(x) {
        annotations.contains(x.id)
      }),
      tier_attributes: e.tier_attributes.filter(fn(x) { tiers.contains(x.id) }),
      type_attributes: e.type_attributes.filter(fn(x) { types.contains(x.id) }),
      elements: e.elements.map(fn(node) {
        if node.name == "REF_LINK_SET" {
          {
            ..node,
            children: node.children.filter(fn(link) {
              live.contains(attr(link.attributes, "REF_LINK_ID").unwrap())
            }),
          }
        } else {
          node
        }
      }),
    },
  }
}
