///|
/// Model errors carry structural identifiers, never annotation payloads.
pub(all) suberror EafError {
  Invalid(String)
  Unsupported(String)
  Budget(String)
  Xml(String)
} derive(Debug)

///|
/// The four EAF dependent tier stereotypes and a root tier.
pub(all) enum Constraint {
  Independent
  TimeSubdivision
  IncludedIn
  SymbolicAssociation
  SymbolicSubdivision
} derive(Debug, Eq)

///|
pub(all) struct LinguisticType {
  id : String
  constraint : Constraint
} derive(Debug, Eq)

///|
/// Times are integer milliseconds, bounded by the positive Int range.
pub(all) struct TimeSlot {
  id : String
  milliseconds : Int32
} derive(Debug, Eq)

///|
/// Reference annotations inherit the complete interval of their referent.
pub(all) enum Annotation {
  Aligned(String, String, String, String)
  Reference(String, String, String?, String)
} derive(Debug, Eq)

///|
pub(all) struct Tier {
  id : String
  linguistic_type : String
  parent : String?
  participant : String
  annotator : String
  annotations : Array[Annotation]
} derive(Debug, Eq)

///|
pub(all) struct Media {
  url : String
  relative_url : String
  mime_type : String
  time_origin : Int32
} derive(Debug, Eq)

///|
/// Public data is inspectable; every graph operation revalidates it.
pub(all) struct Document {
  author : String
  date : String
  version : String
  media : Array[Media]
  properties : Array[(String, String)]
  times : Array[TimeSlot]
  types : Array[LinguisticType]
  tiers : Array[Tier]
} derive(Debug, Eq)

///|
pub(all) struct Limits {
  input_units : Int32
  nodes : Int32
  depth : Int32
  tiers : Int32
  annotations : Int32
} derive(Debug, Eq)

///|
pub fn default_limits() -> Limits {
  {
    input_units: 2000000,
    nodes: 100000,
    depth: 32,
    tiers: 256,
    annotations: 10000,
  }
}

///|
pub fn empty_document() -> Document {
  {
    author: "",
    date: "1970-01-01T00:00:00Z",
    version: "3.0",
    media: [],
    properties: [],
    times: [],
    types: [],
    tiers: [],
  }
}

///|
pub fn annotation_id(a : Annotation) -> String {
  match a {
    Aligned(id, _, _, _) | Reference(id, _, _, _) => id
  }
}

///|
pub fn annotation_value(a : Annotation) -> String {
  match a {
    Aligned(_, _, _, v) | Reference(_, _, _, v) => v
  }
}

///|
pub fn constraint_name(c : Constraint) -> String {
  match c {
    Independent => ""
    TimeSubdivision => "Time_Subdivision"
    IncludedIn => "Included_In"
    SymbolicAssociation => "Symbolic_Association"
    SymbolicSubdivision => "Symbolic_Subdivision"
  }
}

///|
pub fn is_time_alignable(c : Constraint) -> Bool {
  match c {
    Independent | TimeSubdivision | IncludedIn => true
    _ => false
  }
}

///|
/// Deep copy prevents successful edits from mutating the caller's arrays.
pub fn snapshot(d : Document) -> Document {
  {
    ..d,
    media: d.media.copy(),
    properties: d.properties.copy(),
    times: d.times.copy(),
    types: d.types.copy(),
    tiers: d.tiers.map(fn(t) { { ..t, annotations: t.annotations.copy(), } }),
  }
}

///|
fn valid_id(id : String) -> Bool {
  if id.is_empty() {
    return false
  }
  for c in id.to_array() {
    if c <= ' ' || c == '<' || c == '>' || c == '&' || c == '"' || c == '\'' {
      return false
    }
  }
  true
}

///|
pub fn validate_identifier(id : String) -> Unit raise EafError {
  guard valid_id(id) else { raise Invalid("empty or unsafe identifier") }
}

///|
pub extend EafError with @debug.Debug::{to_repr}

///|
pub extend Constraint with @debug.Debug::{to_repr}

///|
pub extend Constraint with Eq::{equal, not_equal}

///|
pub extend LinguisticType with @debug.Debug::{to_repr}

///|
pub extend LinguisticType with Eq::{equal, not_equal}

///|
pub extend TimeSlot with @debug.Debug::{to_repr}

///|
pub extend TimeSlot with Eq::{equal, not_equal}

///|
pub extend Annotation with @debug.Debug::{to_repr}

///|
pub extend Annotation with Eq::{equal, not_equal}

///|
pub extend Tier with @debug.Debug::{to_repr}

///|
pub extend Tier with Eq::{equal, not_equal}

///|
pub extend Media with @debug.Debug::{to_repr}

///|
pub extend Media with Eq::{equal, not_equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub extend Document with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Limits with Eq::{equal, not_equal}
