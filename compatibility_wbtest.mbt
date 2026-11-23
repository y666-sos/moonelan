///|
fn compatibility_xml() -> String {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="test" DATE="2026-11-23T00:00:00Z" FORMAT="3.0" VERSION="3.0">
    #|<LICENSE LICENSE_URL="https://example.org/license">original synthetic fixture</LICENSE>
    #|<HEADER MEDIA_FILE="legacy.wav" TIME_UNITS="milliseconds"><MEDIA_DESCRIPTOR MEDIA_URL="file:///audio.wav" MIME_TYPE="audio/x-wav" TIME_ORIGIN="-100" EXTRACTED_FROM="file:///video.mp4"/><LINKED_FILE_DESCRIPTOR LINK_URL="file:///notes.txt" MIME_TYPE="text/plain" TIME_ORIGIN="-20"/><PROPERTY>unnamed property</PROPERTY></HEADER>
    #|<TIME_ORDER><TIME_SLOT TIME_SLOT_ID="边界0" TIME_VALUE="0"/><TIME_SLOT TIME_SLOT_ID="边界1"/><TIME_SLOT TIME_SLOT_ID="边界2" TIME_VALUE="1000"/></TIME_ORDER>
    #|<TIER TIER_ID="speech tier" LINGUISTIC_TYPE_REF="root" DEFAULT_LOCALE="zh" LANG_REF="zho"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="根" TIME_SLOT_REF1="边界0" TIME_SLOT_REF2="边界2" EXT_REF="er"><ANNOTATION_VALUE>你好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<TIER TIER_ID="words" LINGUISTIC_TYPE_REF="word" PARENT_REF="speech tier"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="w1" TIME_SLOT_REF1="边界0" TIME_SLOT_REF2="边界1"><ANNOTATION_VALUE>你</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="w2" TIME_SLOT_REF1="边界1" TIME_SLOT_REF2="边界2"><ANNOTATION_VALUE>好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<TIER TIER_ID="pos" LINGUISTIC_TYPE_REF="tag" PARENT_REF="words" LANG_REF="zho"><ANNOTATION><REF_ANNOTATION ANNOTATION_ID="p1" ANNOTATION_REF="w1" CVE_REF="noun"><ANNOTATION_VALUE>名词</ANNOTATION_VALUE></REF_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="root" TIME_ALIGNABLE="1" GRAPHIC_REFERENCES="0"/>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="word" TIME_ALIGNABLE="true" CONSTRAINTS="Time_Subdivision"/>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="tag" TIME_ALIGNABLE="false" CONSTRAINTS="Symbolic_Association" CONTROLLED_VOCABULARY_REF="POS" LEXICON_REF="lex"/>
    #|<LOCALE LANGUAGE_CODE="zh" COUNTRY_CODE="CN"/>
    #|<LANGUAGE LANG_ID="zho" LANG_DEF="https://iso639-3.sil.org/code/zho" LANG_LABEL="中文"/><LANGUAGE LANG_ID="eng" LANG_LABEL="English"/>
    #|<CONSTRAINT STEREOTYPE="Time_Subdivision"/><CONSTRAINT STEREOTYPE="Symbolic_Association"/>
    #|<CONTROLLED_VOCABULARY CV_ID="POS"><DESCRIPTION LANG_REF="zho">词性</DESCRIPTION><CV_ENTRY_ML CVE_ID="noun"><CVE_VALUE LANG_REF="zho" DESCRIPTION="类别">名词</CVE_VALUE><CVE_VALUE LANG_REF="eng">noun</CVE_VALUE></CV_ENTRY_ML><CV_ENTRY_ML CVE_ID="verb"><CVE_VALUE LANG_REF="zho">动词</CVE_VALUE><CVE_VALUE LANG_REF="eng">verb</CVE_VALUE></CV_ENTRY_ML></CONTROLLED_VOCABULARY>
    #|<LEXICON_REF LEX_REF_ID="lex" NAME="lexicon" TYPE="test" URL="https://example.org/lex" LEXICON_ID="lex1" LEXICON_NAME="Demo"/>
    #|<REF_LINK_SET LINK_SET_ID="links" LANG_REF="zho"><CROSS_REF_LINK REF_LINK_ID="link1" REF1="根" REF2="p1" DIRECTIONALITY="unidirectional">association</CROSS_REF_LINK><GROUP_REF_LINK REF_LINK_ID="link2" REFS="link1 w2">group</GROUP_REF_LINK></REF_LINK_SET>
    #|<EXTERNAL_REF EXT_REF_ID="er" TYPE="resource_url" VALUE="https://example.org/resource"/>
    #|</ANNOTATION_DOCUMENT>
  xml
}

///|
test "unaligned slots retain missing boundaries through complete graph workflows" {
  let d = parse(compatibility_xml())
  assert_eq(d.times[1].milliseconds, None)
  assert_eq(annotation_timing(d, "w1"), { start_ms: Some(0), end_ms: None, })
  assert_eq(annotation_timing(d, "p1"), annotation_timing(d, "w1"))
  assert_eq(parent_annotation(d, "w2"), Some("根"))
  assert_eq(children(d, "words", "根").length(), 2)
  let saved = parse(write(d))
  assert_eq(write(saved), write(d))
  assert_eq(saved.times[1].milliseconds, None)
  assert_eq(corpus_records(saved).length(), 4)
  assert_true(to_json(saved).contains("null"))
  assert_true(to_csv(saved).contains("\"0\",\"\""))
  try resolve(saved, "p1") catch {
    _ => ()
  } noraise {
    _ => fail("fabricated missing time")
  }
  let aligned = retime(saved, [{ id: "边界1", milliseconds: Some(400), }])
  assert_eq(resolve(aligned, "p1"), { start: 0, end: 400, })
  assert_eq(resample(saved, 2, 1).times[1].milliseconds, None)
  assert_eq(extract_roots(saved, ["根"]).tiers.length(), 3)
}

///|
test "controlled vocabulary selection updates multilingual binding atomically" {
  let d = parse(compatibility_xml())
  assert_eq(vocabulary_choices(d, "pos", "eng").length(), 2)
  let edited = set_controlled_value(d, "p1", "verb", "eng")
  assert_eq(annotation_value(edited.tiers[2].annotations[0]), "verb")
  assert_eq(annotation_value(d.tiers[2].annotations[0]), "名词")
  assert_eq(write(parse(write(edited))), write(edited))
  try set_value(d, "p1", "unlisted") catch {
    _ => ()
  } noraise {
    _ => fail("stale vocabulary binding")
  }
  try set_controlled_value(d, "p1", "missing", "eng") catch {
    _ => ()
  } noraise {
    _ => fail("unknown CV entry")
  }
}

///|
test "metadata references follow rename and cascade deletion" {
  let d = parse(compatibility_xml())
  let renamed = rename_annotation(d, "根", "renamed")
  assert_true(write(renamed).contains("REF1=\"renamed\""))
  let renamed = rename_tier(renamed, "speech tier", "new tier")
  assert_eq(write(parse(write(renamed))), write(renamed))
  let removed = remove_annotation(d, "根", cascade=true)
  assert_eq(corpus_records(removed).length(), 0)
  assert_true(!write(removed).contains("REF_LINK_ID"))
  let removed = remove_tier(d, "pos")
  assert_eq(removed.extensions.annotation_attributes.length(), 1)
  assert_eq(write(parse(write(removed))), write(removed))
}

///|
test "metadata rejects unresolved languages entries links and misplaced nodes" {
  let xml = compatibility_xml()
  for
    (old, replacement) in [
      ("LANG_REF=\"zho\"", "LANG_REF=\"missing\""),
      ("CVE_REF=\"noun\"", "CVE_REF=\"missing\""),
      ("REF2=\"p1\"", "REF2=\"missing\""),
      ("CVE_ID=\"verb\"", "CVE_ID=\"noun\""),
      ("TIME_SLOT_REF2=\"边界1\"", "TIME_SLOT_REF2=\"边界0\""),
      ("<HEADER MEDIA_FILE", "<HEADER UNKNOWN=\"x\" MEDIA_FILE"),
    ] {
    try parse(xml.replace(old~, new=replacement)) catch {
      _ => ()
    } noraise {
      _ => fail("invalid metadata accepted")
    }
  }
}

///|
test "external CV metadata is preserved and offline resolution is explicit" {
  let xml = compatibility_xml()
  let cv =
    #|<CONTROLLED_VOCABULARY CV_ID="POS" EXT_REF="ecv"/>
  let before = parse(xml)
  let original_cv = before.extensions.elements.filter(fn(e) {
      e.name == "CONTROLLED_VOCABULARY"
    })[0]
  let external = {
    ..before,
    extensions: {
      ..before.extensions,
      elements: before.extensions.elements.filter(fn(e) {
        e.name != "CONTROLLED_VOCABULARY"
      }) +
      [
        import_element(xml_tree(cv, default_limits())),
        {
          name: "EXTERNAL_REF",
          attributes: [
            ("EXT_REF_ID", "ecv"),
            ("TYPE", "ecv"),
            ("VALUE", "https://example.org/cv.ecv"),
          ],
          text: "",
          children: [],
        },
      ],
    },
  }
  assert_eq(original_cv.children.length(), 3)
  validate(external)
  assert_eq(write(parse(write(external))), write(external))
  try vocabulary_choices(external, "pos", "zho") catch {
    _ => ()
  } noraise {
    _ => fail("invented external vocabulary contents")
  }
}

///|
test "snapshot owns extension trees and optional timing edits roll back" {
  let d = parse(compatibility_xml())
  let saved = write(d)
  let copy = snapshot(d)
  copy.extensions.elements[0].attributes.push(("EXTRA", "value"))
  assert_eq(write(d), saved)
  try retime(d, [{ id: "边界1", milliseconds: Some(1500), }]) catch {
    _ => ()
  } noraise {
    _ => fail("invalid timing accepted")
  }
  assert_eq(write(d), saved)
  let missing = retime(d, [{ id: "边界2", milliseconds: None, }])
  assert_eq(annotation_timing(missing, "根").end_ms, None)
  assert_eq(write(parse(write(missing))), write(missing))
}

///|
test "partial selection retains shared metadata and removes dangling links" {
  let d = parse(compatibility_xml())
  let selected = select_tiers(d, ["words"])
  assert_eq(selected.tiers.length(), 2)
  assert_true(!write(selected).contains("REF_LINK_ID"))
  assert_eq(write(parse(write(selected))), write(selected))
  let empty = extract_roots(d, [])
  assert_eq(empty.times.length(), 0)
  assert_eq(write(parse(write(empty))), write(empty))
}

///|
test "missing time and vocabulary inputs from baseline now import" {
  let d = sample_document()
  let xml = write(d).replace(old=" TIME_VALUE=\"0\"", new="")
  assert_eq(parse(xml).times[0].milliseconds, None)
  let d = parse(compatibility_xml())
  assert_eq(vocabulary_choices(d, "pos", "zho")[0].value, "名词")
}
