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
