///|
fn csv_cell(value : String) -> String {
  "\"" +
  value.split("\"").map(fn(s) { s.to_owned() }).collect().join("\"\"") +
  "\""
}

///|
/// RFC 4180 quoted CSV with integer milliseconds and explicit parent identity.
/// All cells are quoted. Values remain verbatim, including spreadsheet formulas.
pub fn to_csv(d : Document) -> String raise EafError {
  let out = StringBuilder()
  out.write_string(
    "tier,participant,id,parent,root,start_ms,end_ms,sibling_index,value\r\n",
  )
  for r in corpus_records(d) {
    let cells = [
      r.tier,
      r.participant,
      r.id,
      r.parent.unwrap_or(""),
      r.root,
      optional_ms(r.timing.start_ms),
      optional_ms(r.timing.end_ms),
      r.sibling_index.to_string(),
      r.value,
    ]
    out.write_string(cells.map(csv_cell).join(","))
    out.write_string("\r\n")
  }
  out.to_string()
}

///|
/// Versioned JSON dataset preserving complete hierarchy paths and null parents.
pub fn to_json(d : Document) -> String raise EafError {
  let rows : Array[Json] = corpus_records(d).map(fn(r) {
    @json.to_json(
      Map([
        ("tier", @json.to_json(r.tier)),
        ("participant", @json.to_json(r.participant)),
        ("id", @json.to_json(r.id)),
        (
          "parent",
          match r.parent {
            Some(p) => @json.to_json(p)
            None => null
          },
        ),
        ("root", @json.to_json(r.root)),
        ("path", @json.to_json(r.path)),
        ("start_ms", optional_json_ms(r.timing.start_ms)),
        ("end_ms", optional_json_ms(r.timing.end_ms)),
        ("sibling_index", @json.to_json(r.sibling_index)),
        ("value", @json.to_json(r.value)),
      ]),
    )
  })
  @json.to_json(
    Map([
      ("schema", @json.to_json("moonelan.corpus.v2")),
      ("rows", @json.to_json(rows)),
    ]),
  ).stringify()
}

///|
fn optional_ms(value : Int32?) -> String {
  match value {
    Some(ms) => ms.to_string()
    None => ""
  }
}

///|
fn optional_json_ms(value : Int32?) -> Json {
  match value {
    Some(ms) => @json.to_json(ms)
    None => null
  }
}
