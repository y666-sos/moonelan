///|
fn main raise {
  let fixture =
    #|<ANNOTATION_DOCUMENT AUTHOR="test" DATE="2026-11-23T00:00:00Z" FORMAT="3.0" VERSION="3.0">
    #|<LICENSE LICENSE_URL="https://example.org/license">original synthetic fixture</LICENSE>
    #|<HEADER MEDIA_FILE="legacy.wav" TIME_UNITS="milliseconds"><MEDIA_DESCRIPTOR MEDIA_URL="file:///audio.wav" MIME_TYPE="audio/x-wav" TIME_ORIGIN="-100" EXTRACTED_FROM="file:///video.mp4"/><LINKED_FILE_DESCRIPTOR LINK_URL="file:///notes.txt" MIME_TYPE="text/plain" TIME_ORIGIN="-20"/><PROPERTY NAME="note">unnamed property</PROPERTY></HEADER>
    #|<TIME_ORDER><TIME_SLOT TIME_SLOT_ID="边界0" TIME_VALUE="0"/><TIME_SLOT TIME_SLOT_ID="边界1"/><TIME_SLOT TIME_SLOT_ID="边界2" TIME_VALUE="1000"/></TIME_ORDER>
    #|<TIER TIER_ID="speech tier" LINGUISTIC_TYPE_REF="root" DEFAULT_LOCALE="zh" LANG_REF="zho"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="根1" TIME_SLOT_REF1="边界0" TIME_SLOT_REF2="边界2" EXT_REF="er"><ANNOTATION_VALUE>你好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
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
    #|<REF_LINK_SET LINK_SET_ID="links" LANG_REF="zho"><CROSS_REF_LINK REF_LINK_ID="link1" REF1="根1" REF2="p1" DIRECTIONALITY="unidirectional">association</CROSS_REF_LINK><GROUP_REF_LINK REF_LINK_ID="link2" REFS="link1 w2">group</GROUP_REF_LINK></REF_LINK_SET>
    #|<EXTERNAL_REF EXT_REF_ID="er" TYPE="resource_url" VALUE="https://example.org/resource"/>
    #|</ANNOTATION_DOCUMENT>

  for version in ["2.8", "3.0"] {
    for mode = 0; mode < 4; mode = mode + 1 {
      for lang in ["zho", "eng"] {
        let mut xml = fixture.replace(
          old="FORMAT=\"3.0\" VERSION=\"3.0\"",
          new="FORMAT=\"" + version + "\" VERSION=\"" + version + "\"",
        )
        if version == "2.8" {
          xml = xml.replace(
            old="<REF_LINK_SET LINK_SET_ID=\"links\" LANG_REF=\"zho\"><CROSS_REF_LINK REF_LINK_ID=\"link1\" REF1=\"根1\" REF2=\"p1\" DIRECTIONALITY=\"unidirectional\">association</CROSS_REF_LINK><GROUP_REF_LINK REF_LINK_ID=\"link2\" REFS=\"link1 w2\">group</GROUP_REF_LINK></REF_LINK_SET>",
            new="",
          )
        }
        if mode == 0 {
          xml = xml.replace(
            old="TIME_SLOT_ID=\"边界1\"/>",
            new="TIME_SLOT_ID=\"边界1\" TIME_VALUE=\"400\"/>",
          )
        }
        if mode == 2 || mode == 3 {
          xml = xml.replace(old=" TIME_VALUE=\"0\"", new="")
        }
        if mode == 3 {
          xml = xml.replace(old=" TIME_VALUE=\"1000\"", new="")
        }
        let d = @eaf.parse(xml)
        let d = @eaf.set_controlled_value(d, "p1", "verb", lang)
        let d = @eaf.rename_annotation(d, "根1", "utterance1")
        let d = @eaf.parse(@eaf.write(d))
        assert_eq(@eaf.corpus_records(d).length(), 4)
        assert_eq(
          @eaf.annotation_timing(d, "p1"),
          @eaf.annotation_timing(d, "w1"),
        )
        println(@eaf.write(d))
        println("MOONELAN_XML_END")
        println(@eaf.to_json(d))
        println("MOONELAN_JSON_END")
        println(@eaf.to_csv(d))
        println("MOONELAN_CASE_END")
      }
    }
  }
}
