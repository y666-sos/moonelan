# Sources and license boundaries

MoonELAN is an original MIT-licensed implementation by y666-sos. No upstream implementation code or personal corpus was copied into this repository.

| Source | License / status | Actual use |
| --- | --- | --- |
| [Milky2018/xml 0.6.1](https://mooncakes.io/docs/Milky2018/xml) / [source](https://github.com/moonbit-community/xml-mbt) | Apache-2.0, copyright 2025 International Digital Economy Academy | Runtime dependency for XML reading, escaping and writing; downloaded by Moon, not vendored |
| [pympi-ling 1.70.2](https://github.com/dopefishh/pympi) | MIT, copyright 2015 Mart Lubbers | Independent Python reader and behavior reference; test dependency, no copied implementation |
| [ELAN](https://archive.mpi.nl/tla/elan) | Upstream application and EAF format specification | Hierarchical annotation model and four stereotypes; no application code copied |
| [EAF 2.8/3.0 XSD mirror](https://github.com/chschenk/ELAN/tree/4e9eb6e0e70e549471816ee30096138ce166a7c3/src/main/resources/mpi/eudico/resources) | Third-party upstream validation material | Downloaded during independent checks into ignored build cache; pinned by commit and SHA-256; not redistributed |

`examples/fixture` and all test inputs are original synthetic data. Names such as speaker_A describe synthetic participants. No recording is bundled or fetched.

The XML dependency retains its own Apache-2.0 notices in the dependency distribution. Our MIT license does not relicense dependencies or external verification material. `scripts/verify_interop.py` downloads schemas without running their content as code and disables external XML network access through lxml's default parser; schemas used here have no external includes.

AI was used for research, design, code, tests, debugging and documentation. The account owner remains responsible for correctness and source/license review. No official contest acceptance or absolute ecosystem uniqueness is claimed.


## 0.2.0 compatibility fixtures

`examples/compatibility` and compatibility tests are original synthetic multilingual corpus data designed against the same pinned EAF 2.8/3.0 schemas. `examples/foreign` embeds original synthetic data serialized by pympi-ling 1.70.2, with an optional TIME_VALUE independently omitted using Python ElementTree. No pympi implementation code, external recordings, organizer email or private application is included. Reference links are checked with the EAF 3.0 XSD because pympi does not expose their semantics. Internal CV bindings are independently inspected as XML as well as through pympi's CV model. External CV network fetching is deliberately left to callers.

## 0.3.0 schema facts and conformance tests

`scripts/build_eaf30_rules.py` extracts element/attribute/type/cardinality facts from the pinned EAF 3.0 schema and generates `eaf30_generated.mbt`. It does not translate ELAN application implementation code or redistribute the schema. The generator verifies the schema SHA-256 and its check mode compares token streams after formatting. Generated rules are excluded from substantive production LOC. `schema.mbt`, `file.mbt` and the test harness are original project code. The EAF 3.0 matrix and supplied ECV workflow use original synthetic data; lxml and pympi are test-only dependencies. The original XML dependency license and all upstream rights remain unchanged.
