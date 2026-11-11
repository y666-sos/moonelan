///|
/// Serialize the supported EAF subset using the ecosystem XML writer.
/// Tier storage order and annotation values are preserved exactly.
pub fn write(d : Document) -> String raise EafError {
  validate(d)
  write_xml(d) catch {
    _ => raise Xml("cannot serialize invalid XML content")
  }
}

///|
fn write_xml(d : Document) -> String raise @xml.WriterError {
  let w = @xml.Writer::new()
  w.start_element("ANNOTATION_DOCUMENT", [
    ("AUTHOR", d.author),
    ("DATE", d.date),
    ("FORMAT", d.version),
    ("VERSION", d.version),
    ("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"),
    (
      "xsi:noNamespaceSchemaLocation",
      "http://www.mpi.nl/tools/elan/EAFv" + d.version + ".xsd",
    ),
  ])
  w.start_element("HEADER", [("MEDIA_FILE", ""), ("TIME_UNITS", "milliseconds")])
  for m in d.media {
    w.empty_element("MEDIA_DESCRIPTOR", [
      ("MEDIA_URL", m.url),
      ("RELATIVE_MEDIA_URL", m.relative_url),
      ("MIME_TYPE", m.mime_type),
      ("TIME_ORIGIN", m.time_origin.to_string()),
    ])
  }
  for (name, value) in d.properties {
    w.start_element("PROPERTY", [("NAME", name)])
    w.text(value)
    w.end_element("PROPERTY")
  }
  w.end_element("HEADER")
  w.start_element("TIME_ORDER", [])
  for s in d.times {
    w.empty_element("TIME_SLOT", [
      ("TIME_SLOT_ID", s.id),
      ("TIME_VALUE", s.milliseconds.to_string()),
    ])
  }
  w.end_element("TIME_ORDER")
  for t in d.tiers {
    let attrs = [
      ("TIER_ID", t.id),
      ("LINGUISTIC_TYPE_REF", t.linguistic_type),
      ("PARTICIPANT", t.participant),
      ("ANNOTATOR", t.annotator),
    ]
    if t.parent is Some(p) {
      attrs.push(("PARENT_REF", p))
    }
    w.start_element("TIER", attrs)
    for a in t.annotations {
      w.start_element("ANNOTATION", [])
      let (tag, aa) = match a {
        Aligned(id, lo, hi, _) =>
          (
            "ALIGNABLE_ANNOTATION",
            [
              ("ANNOTATION_ID", id),
              ("TIME_SLOT_REF1", lo),
              ("TIME_SLOT_REF2", hi),
            ],
          )
        Reference(id, target, previous, _) => {
          let aa = [("ANNOTATION_ID", id), ("ANNOTATION_REF", target)]
          if previous is Some(p) {
            aa.push(("PREVIOUS_ANNOTATION", p))
          }
          ("REF_ANNOTATION", aa)
        }
      }
      w.start_element(tag, aa)
      w.start_element("ANNOTATION_VALUE", [])
      w.text(annotation_value(a))
      w.end_element("ANNOTATION_VALUE")
      w.end_element(tag)
      w.end_element("ANNOTATION")
    }
    w.end_element("TIER")
  }
  for t in d.types {
    let attrs = [
      ("LINGUISTIC_TYPE_ID", t.id),
      (
        "TIME_ALIGNABLE",
        if is_time_alignable(t.constraint) {
          "true"
        } else {
          "false"
        },
      ),
      ("GRAPHIC_REFERENCES", "false"),
    ]
    if t.constraint != Independent {
      attrs.push(("CONSTRAINTS", constraint_name(t.constraint)))
    }
    w.empty_element("LINGUISTIC_TYPE", attrs)
  }
  for
    c in [TimeSubdivision, IncludedIn, SymbolicAssociation, SymbolicSubdivision] {
    w.empty_element("CONSTRAINT", [
      ("STEREOTYPE", constraint_name(c)),
      ("DESCRIPTION", constraint_name(c)),
    ])
  }
  w.end_element("ANNOTATION_DOCUMENT")
  w.to_string()
}
