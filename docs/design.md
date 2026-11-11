# Design and invariants

The public model deliberately separates aligned annotations from symbolic references. A reference never duplicates time slots: `resolved_spans` processes parent tiers before children and inherits the referent's span. Tier membership must agree with the direct parent relation. The graph index uses identity maps and a nonrecursive topological pass; tier ordering is deterministic for a fixed stored document.

Temporal validation sorts intervals within each aligned tier, rejects overlap, assigns each child to exactly one containing parent and verifies gapless full coverage for each populated Time_Subdivision group. Empty groups are permitted for incomplete annotation work. A symbolic parent with multiple equal-span children cannot provide an unambiguous temporal child; such a mixed hierarchy is rejected.

Symbolic subdivision is a linked sibling sequence. Validation requires one head, no cross-group predecessor, one successor per predecessor and complete reachability. A single head plus an isolated cycle is rejected by the reachability count. Association tiers permit at most one child per parent and no predecessor.

Edits are transactional at the API boundary: validate input, copy owned arrays, apply complete edits, validate result. Strings and scalar structs are immutable; mutable arrays are copied. Public struct fields remain inspectable, so callers can deliberately build invalid documents; every editing operation rejects those inputs. The library has no shared global state or IO.

Removal walks the annotation parent relation (temporal containment plus symbolic references) in topological order. Cascades remove descendants, and surviving symbolic successors skip removed predecessors. Time subdivision gaps are never silently filled. Tier selection retains full ancestor tiers; utterance extraction starts only at independent annotations and retains complete descendant groups. Both preserve IDs and compact unused times/types.

Corpus rows use topological tiers and sorted parent groups. Within a symbolic group, linked order takes precedence over XML storage order. Paths run from independent utterance to leaf; times remain inherited from the nearest aligned annotation. CSV and JSON are views of this common row model.

The EAF reader is strict about recognized semantics, but is not an XSD validator. It tolerates noncanonical root child order and ignores XML comments/processing instructions; output is canonical in EAF schema order. Formatting, namespace hints and constraint prose are not archival metadata. See the Chinese README for the exact unsupported subset, budgets and platform requirements.

Worst cases: tier ordering O(T²), temporal containment O(A_child × A_parent), resolution O(A), symbolic validation O(A), sibling sorting O(A log A). Whole-document transactional copies favor correctness and modest corpus editing over incremental large-file workloads. There is no benchmark or throughput claim in this release.
