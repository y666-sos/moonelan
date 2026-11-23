///|
/// Original synthetic corpus: two utterances, timed words, symbolic morphology,
/// nested POS labels, translations and sparse Included_In gestures.
pub fn corpus(seed : Int32) -> @eaf.Document raise @eaf.EafError {
  let offset = seed * 4000
  let times : Array[@eaf.TimeSlot] = []
  let speech : Array[@eaf.Annotation] = []
  let words : Array[@eaf.Annotation] = []
  let translations : Array[@eaf.Annotation] = []
  let morph : Array[@eaf.Annotation] = []
  let pos : Array[@eaf.Annotation] = []
  let gestures : Array[@eaf.Annotation] = []
  for i = 0; i < 2; i = i + 1 {
    let suffix = i.to_string()
    let a = "a" + suffix
    let start = "s" + suffix
    let mid = "m" + suffix
    let end = "e" + suffix
    let g1 = "gstart" + suffix
    let g2 = "gend" + suffix
    let lo = offset + i * 1500
    times.push({ id: start, milliseconds: Some(lo), })
    times.push({ id: mid, milliseconds: Some(lo + 300 + seed % 100), })
    times.push({ id: end, milliseconds: Some(lo + 1000), })
    times.push({ id: g1, milliseconds: Some(lo + 100), })
    times.push({ id: g2, milliseconds: Some(lo + 200), })
    speech.push(
      @eaf.Aligned(a, start, end, "你好，世界 & \"语料\" \{seed}"),
    )
    translations.push(
      @eaf.Reference("tr" + suffix, a, None, "Hello, world\nline two"),
    )
    gestures.push(@eaf.Aligned("g" + suffix, g1, g2, "point"))
    for j = 0; j < 2; j = j + 1 {
      let w = "w" + suffix + j.to_string()
      words.push(
        @eaf.Aligned(
          w,
          if j == 0 {
            start
          } else {
            mid
          },
          if j == 0 {
            mid
          } else {
            end
          },
          "word\{j}",
        ),
      )
      let m1 = "morph_" + w + "_0"
      let m2 = "morph_" + w + "_1"
      // Reverse physical storage intentionally: semantic order comes from links.
      morph.push(@eaf.Reference(m2, w, Some(m1), "suffix"))
      morph.push(@eaf.Reference(m1, w, None, "stem"))
      pos.push(@eaf.Reference("pos_" + w, m1, None, "N"))
    }
  }
  let d = @eaf.Document::{
    extensions: @eaf.empty_extensions(),
    author: "MoonELAN synthetic corpus",
    version: if seed % 2 == 0 {
      "3.0"
    } else {
      "2.8"
    },
    date: "2026-11-11T12:00:00+08:00",
    media: [
      {
        url: "file:///synthetic.wav",
        relative_url: "./synthetic.wav",
        mime_type: "audio/x-wav",
        time_origin: 0,
      },
    ],
    properties: [
      ("source", "Original synthetic fixture; no personal recordings"),
    ],
    times,
    types: [
      { id: "utterance", constraint: @eaf.Independent, },
      { id: "word", constraint: @eaf.TimeSubdivision, },
      { id: "translation", constraint: @eaf.SymbolicAssociation, },
      { id: "morphology", constraint: @eaf.SymbolicSubdivision, },
      { id: "pos", constraint: @eaf.SymbolicAssociation, },
      { id: "gesture", constraint: @eaf.IncludedIn, },
    ],
    tiers: [
      {
        id: "speech",
        linguistic_type: "utterance",
        parent: None,
        participant: "speaker_A",
        annotator: "",
        annotations: speech,
      },
      {
        id: "words",
        linguistic_type: "word",
        parent: Some("speech"),
        participant: "speaker_A",
        annotator: "",
        annotations: words,
      },
      {
        id: "translation",
        linguistic_type: "translation",
        parent: Some("speech"),
        participant: "",
        annotator: "",
        annotations: translations,
      },
      {
        id: "morphology",
        linguistic_type: "morphology",
        parent: Some("words"),
        participant: "",
        annotator: "",
        annotations: morph,
      },
      {
        id: "pos",
        linguistic_type: "pos",
        parent: Some("morphology"),
        participant: "",
        annotator: "",
        annotations: pos,
      },
      {
        id: "gesture",
        linguistic_type: "gesture",
        parent: Some("speech"),
        participant: "",
        annotator: "",
        annotations: gestures,
      },
    ],
  }
  @eaf.validate(d)
  d
}
