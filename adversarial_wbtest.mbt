///|
fn expect_invalid(d : Document) -> Unit raise {
  try validate(d) catch {
    _ => ()
  } noraise {
    _ => fail("invalid graph accepted")
  }
}

///|
test "adversarial hierarchy mutations reject dangling foreign duplicate and cyclic structure" {
  let d = subdivided_document()
  for target in ["missing", "a2", "w1"] {
    let bad = snapshot(d)
    bad.tiers[1].annotations[0] = Reference("a2", target, None, "bad")
    expect_invalid(bad)
  }
  let duplicate = snapshot(d)
  duplicate.tiers[1].annotations.push(Reference("a2", "a1", None, "duplicate"))
  expect_invalid(duplicate)
  let association = snapshot(d)
  association.tiers[1].annotations.push(Reference("a3", "a1", None, "second"))
  expect_invalid(association)
  let wrong_kind = snapshot(d)
  wrong_kind.tiers[1].annotations[0] = Aligned("a2", "ts0", "ts1", "bad")
  expect_invalid(wrong_kind)
  let cyclic = snapshot(d)
  cyclic.types.push({ id: "cyclic", constraint: SymbolicAssociation, })
  cyclic.tiers[0] = {
    ..cyclic.tiers[0],
    parent: Some("gloss"),
    linguistic_type: "cyclic",
    annotations: [],
  }
  cyclic.tiers[1] = { ..cyclic.tiers[1], annotations: [], }
  expect_invalid(cyclic)
  let overlap = snapshot(d)
  overlap.tiers[0].annotations.push(Aligned("a3", "ts0", "ts1", "overlap"))
  expect_invalid(overlap)
}

///|
test "symbolic chains reject forks disconnected cycles and cross-parent links" {
  let d = sample_document()
  let tier = Tier::{
    id: "m",
    linguistic_type: "m",
    parent: Some("speech"),
    participant: "",
    annotator: "",
    annotations: [],
  }
  let d = add_tier(d, tier, SymbolicSubdivision)
  let cases : Array[Array[Annotation]] = [
    [
      Reference("m1", "a1", Some("m2"), ""),
      Reference("m2", "a1", Some("m1"), ""),
    ],
    [Reference("m1", "a1", None, ""), Reference("m2", "a1", None, "")],
    [
      Reference("m1", "a1", None, ""),
      Reference("m2", "a1", Some("m1"), ""),
      Reference("m3", "a1", Some("m1"), ""),
    ],
    [Reference("m1", "a1", Some("a2"), "")],
  ]
  for annotations in cases {
    let bad = snapshot(d)
    bad.tiers[2] = { ..bad.tiers[2], annotations, }
    expect_invalid(bad)
  }
}

///|
test "XML adversarial cases and resource boundaries fail through typed errors" {
  let valid = write(sample_document())
  let cases = [
    valid.replace(old="TIME_VALUE=\"1000\"", new="TIME_VALUE=\"-1\""),
    valid.replace(old="TIME_VALUE=\"1000\"", new="TIME_VALUE=\"4294967296\""),
    valid.replace(old="TIME_VALUE=\"1000\"", new="TIME_VALUE=\"1.0\""),
    valid.replace(old="<HEADER", new="<HEADER X=\"unsupported\""),
    valid.replace(old="<TIME_SLOT", new="<TIME_SLOT CV_ENTRY_REF=\"x\""),
    valid.replace(old="TIME_ALIGNABLE=\"false\"", new="TIME_ALIGNABLE=\"true\""),
    valid.replace(old="ANNOTATION_REF=\"a1\"", new="ANNOTATION_REF=\"none\""),
    valid + "<second/>",
    "<!DOCTYPE ANNOTATION_DOCUMENT SYSTEM 'file:///untrusted'>" + valid,
  ]
  for text in cases {
    try parse(text) catch {
      _ => ()
    } noraise {
      _ => fail("invalid XML accepted")
    }
  }
  for
    limits in [
      { ..default_limits(), input_units: valid.length() - 1, },
      { ..default_limits(), nodes: 2, },
      { ..default_limits(), depth: 2, },
      { ..default_limits(), tiers: 1, },
      { ..default_limits(), annotations: 1, },
    ] {
    try parse(valid, limits~) catch {
      _ => ()
    } noraise {
      _ => fail("budget accepted")
    }
  }
}

///|
test "deterministic transaction sequences preserve invariants and input ownership" {
  for i = 1; i <= 60; i = i + 1 {
    let original = subdivided_document()
    let id = "utterance_" + i.to_string()
    let d = rename_annotation(original, "a1", id)
    let d = set_value(d, "a2", "label \{i} & 中文")
    let d = resample(d, i, 1, offset=i.to_int64())
    let d = select_tiers(d, ["gloss", "words"])
    let d = extract_roots(d, [id])
    let parsed = parse(write(d))
    assert_eq({ ..parsed, extensions: d.extensions, }, d)
    assert_eq(write(parsed), write(d))
    assert_eq(resolve(d, "a2").start, i.to_int64())
    assert_eq(resolve(d, "a2").end, (1000 * i + i).to_int64())
    assert_eq(original, subdivided_document())
  }
}
