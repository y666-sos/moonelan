///|
fn main raise {
  for seed = 0; seed < 40; seed = seed + 1 {
    let d = @fixture.corpus(seed)
    let d = @eaf.rename_annotation(d, "a0", "utterance_" + seed.to_string())
    let d = @eaf.set_value(
      d, "tr0", "Translation \"quoted\", 中文\nsecond line",
    )
    let d = @eaf.resample(d, 3, 2, offset=seed.to_int64())
    let d = @eaf.parse(@eaf.write(d))
    println(@eaf.write(d))
    println("MOONELAN_XML_END")
    println(@eaf.to_json(d))
    println("MOONELAN_JSON_END")
    // CSV may contain real newlines, delimit with an explicit marker.
    println(@eaf.to_csv(d))
    println("MOONELAN_CASE_END")
  }
}
