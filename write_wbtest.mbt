///|
test "EAF writer roundtrips references metadata and XML-sensitive Unicode" {
  let d = sample_document()
  let d = {
    ..d,
    author: "甲 & 乙\"",
    properties: [("x", "<A> & \r\n中文")],
    media: [
      {
        url: "file:///clip.wav",
        relative_url: "./clip.wav",
        mime_type: "audio/x-wav",
        time_origin: 0,
      },
    ],
  }
  let text = write(d)
  let parsed = parse(text)
  assert_eq({ ..parsed, extensions: d.extensions, }, d)
  assert_true(
    parsed.extensions.elements.filter(fn(e) { e.name == "CONSTRAINT" }).length() ==
    4,
  )
  assert_eq(write(parse(text)), text)
}
