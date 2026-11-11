///|
test "CSV quotes multiline comma and quote payloads and JSON preserves paths" {
  let d = set_value(sample_document(), "a2", "a,\"b\"\n中")
  let csv = to_csv(d)
  assert_true(csv.contains("\"a,\"\"b\"\"\n中\"\r\n"))
  guard @json.parse(to_json(d)) is Object(obj) else { fail("object") }
  assert_eq(obj.get("schema"), Some(@json.to_json("moonelan.corpus.v1")))
  guard obj.get("rows") is Some(Array(rows)) else { fail("rows array") }
  guard rows[0] is Object(first) else { fail("row object") }
  guard rows[1] is Object(second) else { fail("row object") }
  let null_value : Json = null
  assert_eq(first.get("parent"), Some(null_value))
  assert_eq(second.get("parent"), Some(@json.to_json("a1")))
  assert_eq(second.get("path"), Some(@json.to_json(["a1", "a2"])))
  assert_eq(second.get("value"), Some(@json.to_json("a,\"b\"\n中")))
}
