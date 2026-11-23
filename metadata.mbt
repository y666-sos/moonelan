///|
/// The portable ID subset deliberately excludes colon and non-ASCII characters.
/// Tier and linguistic-type labels may still contain Unicode.
fn validate_xml_id(id : String) -> Unit raise EafError {
  let cs = id.to_array()
  guard !cs.is_empty() else { raise Invalid("empty XML ID") }
  for i, c in cs {
    let n = c.to_int()
    let first = c.is_ascii_alphabetic() ||
      c == '_' ||
      (n >= 0xC0 && n <= 0xD6) ||
      (n >= 0xD8 && n <= 0xF6) ||
      (n >= 0xF8 && n <= 0x2FF) ||
      (n >= 0x370 && n <= 0x37D) ||
      (n >= 0x37F && n <= 0x1FFF) ||
      (n >= 0x200C && n <= 0x200D) ||
      (n >= 0x2070 && n <= 0x218F) ||
      (n >= 0x2C00 && n <= 0x2FEF) ||
      (n >= 0x3001 && n <= 0xD7FF) ||
      (n >= 0xF900 && n <= 0xFDCF) ||
      (n >= 0xFDF0 && n <= 0xFFFD) ||
      (n >= 0x10000 && n <= 0xEFFFF)
    guard first ||
      (
        i > 0 &&
        (
          c.is_ascii_digit() ||
          c == '-' ||
          c == '.' ||
          n == 0xB7 ||
          (n >= 0x300 && n <= 0x36F) ||
          (n >= 0x203F && n <= 0x2040)
        )
      ) else {
      raise Invalid("invalid XML NCName")
    }
  }
}

///|
fn xml_text(value : String) -> Unit raise EafError {
  for c in value.to_array() {
    let n = c.to_int()
    guard n == 9 ||
      n == 10 ||
      n == 13 ||
      (n >= 32 && n <= 0xD7FF) ||
      (n >= 0xE000 && n <= 0xFFFD) ||
      (n >= 0x10000 && n <= 0x10FFFF) else {
      raise Invalid("XML 1.0 forbidden character")
    }
  }
}

///|
fn date_number(
  cs : Array[Char],
  start : Int32,
  length : Int32,
) -> Int32 raise EafError {
  let mut n = 0
  for i = start; i < start + length; i = i + 1 {
    guard cs[i].is_ascii_digit() else {
      raise Invalid("DATE has nondigit field")
    }
    n = n * 10 + cs[i].to_int() - 48
  }
  n
}

///|
/// Accept four-digit Gregorian dateTimes, fractional seconds and explicit zones.
/// Leap seconds and 24:00 are rejected, keeping cross-runtime behavior uniform.
fn validate_date(value : String) -> Unit raise EafError {
  let cs = value.to_array()
  guard cs.length() >= 19 else { raise Invalid("DATE requires ISO dateTime") }
  guard cs[4] == '-' &&
    cs[7] == '-' &&
    cs[10] == 'T' &&
    cs[13] == ':' &&
    cs[16] == ':' else {
    raise Invalid("DATE separators")
  }
  let year = date_number(cs, 0, 4)
  let month = date_number(cs, 5, 2)
  let day = date_number(cs, 8, 2)
  let hour = date_number(cs, 11, 2)
  let minute = date_number(cs, 14, 2)
  let second = date_number(cs, 17, 2)
  guard year > 0 &&
    month >= 1 &&
    month <= 12 &&
    hour < 24 &&
    minute < 60 &&
    second < 60 else {
    raise Invalid("DATE field range")
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let days = [
    31,
    if leap {
      29
    } else {
      28
    },
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ]
  guard day >= 1 && day <= days[month - 1] else {
    raise Invalid("DATE day range")
  }
  let mut pos = 19
  if pos < cs.length() && cs[pos] == '.' {
    pos += 1
    let begin = pos
    while pos < cs.length() && cs[pos].is_ascii_digit() {
      pos += 1
    }
    guard pos > begin else { raise Invalid("DATE empty fraction") }
  }
  if pos == cs.length() {
    return
  }
  if cs[pos] == 'Z' && pos + 1 == cs.length() {
    return
  }
  guard cs.length() - pos == 6 &&
    (cs[pos] == '+' || cs[pos] == '-') &&
    cs[pos + 3] == ':' else {
    raise Invalid("DATE timezone")
  }
  let hours = date_number(cs, pos + 1, 2)
  let minutes = date_number(cs, pos + 4, 2)
  guard hours <= 14 && minutes < 60 && (hours != 14 || minutes == 0) else {
    raise Invalid("DATE timezone range")
  }
}

///|
fn validate_metadata(d : Document) -> Unit raise EafError {
  validate_date(d.date)
  xml_text(d.author)
  for m in d.media {
    guard !m.url.is_empty() && !m.mime_type.is_empty() else {
      raise Invalid("invalid media descriptor")
    }
    xml_text(m.url)
    xml_text(m.relative_url)
    xml_text(m.mime_type)
  }
  for (name, value) in d.properties {
    xml_text(name)
    xml_text(value)
  }
  for t in d.types {
    xml_text(t.id)
  }
  for t in d.tiers {
    xml_text(t.id)
    xml_text(t.linguistic_type)
    xml_text(t.participant)
    xml_text(t.annotator)
    for a in t.annotations {
      xml_text(annotation_value(a))
    }
  }
}
