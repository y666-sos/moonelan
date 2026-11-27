///|
fn file_fixture() -> String {
  "<ANNOTATION_DOCUMENT AUTHOR=\"\" DATE=\"2026-11-27T24:00:00Z\" VERSION=\"3.0\"><HEADER TIME_UNITS=\"PAL-frames\"/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID=\"s\"/><TIME_SLOT TIME_SLOT_ID=\"e\" TIME_VALUE=\"4294967295\"/></TIME_ORDER><TIER TIER_ID=\"t\" LINGUISTIC_TYPE_REF=\"l\"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID=\"a\" TIME_SLOT_REF1=\"s\" TIME_SLOT_REF2=\"e\"><ANNOTATION_VALUE>原文</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER><LINGUISTIC_TYPE LINGUISTIC_TYPE_ID=\"l\" CONSTRAINTS=\"custom\"/><CONSTRAINT STEREOTYPE=\"custom\" DESCRIPTION=\"保留描述\"/></ANNOTATION_DOCUMENT>"
}

///|
test "schema file endpoint preserves frame units custom constraints and unaligned times" {
  let f = parse_file(file_fixture())
  assert_true(write_file(f).contains("PAL-frames"))
  assert_eq(parse_file(write_file(f)), f)
  let d = file_rename_annotation(f, "a", "新标注")
  let d = file_set_value(d, "新标注", "修改 & 中文")
  let d = file_set_time(d, "s", Some(2147483648L))
  let text = write_file(d)
  assert_true(text.contains("保留描述"))
  assert_true(text.contains("2147483648"))
  assert_true(write_file(f).contains("原文"))
  try file_document(d) catch {
    _ => ()
  } noraise {
    _ => fail("frame graph projection must not pretend milliseconds")
  }
}

///|
test "EAF file validation separates format grammar from graph editing policies" {
  let xml = file_fixture().replace(
    old="TIME_SLOT_REF2=\"e\"",
    new="TIME_SLOT_REF2=\"s\"",
  )
  ignore(parse_file(xml))
  for
    bad in [
      xml.replace(old="4294967295", new="4294967296"),
      xml.replace(old="PAL-frames", new="seconds"),
      xml.replace(old="TIME_SLOT_REF1=\"s\"", new="TIME_SLOT_REF1=\"missing\""),
      xml.replace(old="<HEADER", new="<UNKNOWN"),
      xml.replace(old="VERSION=\"3.0\"", new="VERSION=\"2.8\""),
    ] {
    try parse_file(bad) catch {
      _ => ()
    } noraise {
      _ => fail("invalid schema file")
    }
  }
}

///|
test "signed 64-bit lexical range checked before arithmetic on every backend" {
  assert_eq(
    parse_signed_milliseconds("-9223372036854775808"),
    -9223372036854775808L,
  )
  assert_eq(
    parse_signed_milliseconds("+9223372036854775807"),
    9223372036854775807L,
  )
  for
    value in [
      "9223372036854775808", "-9223372036854775809", "999999999999999999999999999999999",
      "1 2", "\u{00a0}1\u{00a0}",
    ] {
    try parse_signed_milliseconds(value) catch {
      _ => ()
    } noraise {
      _ => fail("signed overflow")
    }
  }
  let d = sample_document()
  for offset in [-9223372036854775808L, 9223372036854775807L] {
    try resample(d, 2147483647, 1, offset~) catch {
      _ => ()
    } noraise {
      _ => fail("resample overflow")
    }
  }
}

///|
test "full dateTime lexical years fractions timezones and end of day" {
  for
    date in [
      "-0004-02-29T24:00:00Z", "12000-02-29T00:00:00.12345-14:00", "9999999999999999999999999999999999-01-01T00:00:00",
      "2026-11-27T24:00:00.000Z",
    ] {
    validate_date(date)
  }
  for
    date in [
      "0000-01-01T00:00:00", "02026-01-01T00:00:00", "2026-11-27T24:00:00.001Z",
      "-0003-02-29T00:00:00",
    ] {
    try validate_date(date) catch {
      _ => ()
    } noraise {
      _ => fail("bad date accepted")
    }
  }
}

///|
test "graph serialization preserves supplied constraint descriptions" {
  let source = write(sample_document()).replace(
    old="DESCRIPTION=\"Symbolic_Association\"",
    new="DESCRIPTION=\"保留原始约束描述\"",
  )
  assert_true(write(parse(source)).contains("保留原始约束描述"))
}

///|
test "XML security rejects declarations but permits their literal text" {
  let good = file_fixture().replace(
    old="原文",
    new="<![CDATA[<!DOCTYPE is text]]>",
  )
  assert_true(write_file(parse_file(good)).contains("&lt;!DOCTYPE"))
  let commented = "<!-- <!DOCTYPE harmless> -->" + file_fixture()
  ignore(parse_file(commented))
  for
    bad in [
      "<!DOCTYPE ANNOTATION_DOCUMENT [<!ENTITY x 'data'>]>" + file_fixture(),
      "not XML" + file_fixture(),
      file_fixture() + "trailing text",
    ] {
    try parse_file(bad) catch {
      _ => ()
    } noraise {
      _ => fail("unsafe XML")
    }
  }
}

///|
test "file mutations reject missing objects collisions budgets and invalid values" {
  let f = parse_file(file_fixture())
  try file_rename_annotation(f, "a", "s") catch {
    _ => ()
  } noraise {
    _ => fail("ID collision")
  }
  try file_set_time(f, "s", Some(4294967296L)) catch {
    _ => ()
  } noraise {
    _ => fail("unsigned overflow")
  }
  try file_set_value(f, "missing", "text") catch {
    _ => ()
  } noraise {
    _ => fail("missing annotation")
  }
  try
    parse_file(file_fixture(), limits={ ..default_limits(), nodes: 2, })
  catch {
    _ => ()
  } noraise {
    _ => fail("node budget")
  }
  try
    parse_file(file_fixture(), limits={ ..default_limits(), depth: 2, })
  catch {
    _ => ()
  } noraise {
    _ => fail("depth budget")
  }
  assert_eq(f, parse_file(file_fixture()))
}

///|
test "external vocabulary description is metadata, not locally resolved content" {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="" DATE="2026-11-27T00:00:00Z" VERSION="3.0">
    #|<HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s"/></TIME_ORDER>
    #|<TIER TIER_ID="t" LINGUISTIC_TYPE_REF="l"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a" TIME_SLOT_REF1="s" TIME_SLOT_REF2="s"><ANNOTATION_VALUE>draft</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="l" CONTROLLED_VOCABULARY_REF="cv"/><LANGUAGE LANG_ID="eng"/>
    #|<CONTROLLED_VOCABULARY CV_ID="cv" EXT_REF="ext"><DESCRIPTION LANG_REF="eng">External categories</DESCRIPTION></CONTROLLED_VOCABULARY>
    #|<EXTERNAL_REF EXT_REF_ID="ext" TYPE="ecv" VALUE="https://example.org/test.ecv"/></ANNOTATION_DOCUMENT>
  let resource =
    #|<CV_RESOURCE><LANGUAGE LANG_ID="eng"/><CONTROLLED_VOCABULARY CV_ID="cv"><CV_ENTRY_ML CVE_ID="noun"><CVE_VALUE LANG_REF="eng">noun</CVE_VALUE></CV_ENTRY_ML></CONTROLLED_VOCABULARY></CV_RESOURCE>
  let f = parse_file(xml)
  let r = parse_file(resource)
  let edited = file_select_cv(f, "a", "noun", "eng", resource=Some(r))
  file_validate_vocabularies(edited, resources=[r])
  try file_validate_vocabularies(edited) catch {
    _ => ()
  } noraise {
    _ => fail("missing external content was accepted")
  }
  assert_true(write_file(edited).contains("External categories"))
  let free = file_set_value(edited, "a", "unbound text")
  assert_true(!write_file(free).contains("CVE_REF="))
  assert_true(write_file(edited).contains("CVE_REF="))
  assert_true(!write_file(f).contains("CVE_REF="))
}
