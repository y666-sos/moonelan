# 工程发布审计

版本：y666-sos/moonelan@0.1.0。许可证：MIT。GitHub 与 MoonCakes 使用同名账户 y666-sos。

## 可复现证据

- `python scripts/check_project.py` 输出逐文件统计：根目录 16 个生产 .mbt，物理 1,945 行，去空行及整行注释后 1,710 行。排除测试、示例、依赖、生成接口和配置；物理行数含实际结构声明与括号，无填充片段。
- `moon info`、`moon fmt --check`、严格 check/test/build 和三个场景均在固定 SDK 上验证。26 个测试均通过，其中一项执行 60 组事务序列。
- 本地 Windows 已对 wasm-gc / wasm / js 执行严格检查、测试、构建、三个工作流及独立 oracle；native 仅严格静态检查，本机缺少 MSVC/Windows SDK。native 执行结果以 Linux CI 为准。
- `scripts/verify_interop.py` 每目标核对 40 个合成文档 / 880 条标注，包含 2.8/3.0 XSD、pympi 1.70.2、独立时间公式、CSV 和 JSON。没有性能跑分或生产使用量声明。
- README 快速开始原样提取后编译运行成功；examples/quickstart 保存经过 moon fmt 的同一示例。
- [CI](https://github.com/y666-sos/moonelan/actions/workflows/ci.yml) 的四个矩阵作业在同一公开提交执行，远端实际结论由运行记录给出。本地结果不能代替远端记录。
- [v0.1.0 Release](https://github.com/y666-sos/moonelan/releases/tag/v0.1.0) 和同版本 MoonCakes 内容须与通过 CI 的提交一致。发布前另行检查真实包清单与隐私，发布后以无凭据、无旧缓存消费者核对精确版本。

## 有效提交审查

以下 21 个提交均为非空、有独立工程目的且保留在最终交付中的切片。保守有效计数为 21；本审计及后续发布收尾提交不用于凑足门槛。每项实现提交都通过格式化、严格静态检查和当时存在的全部测试；独立互操作、CI 和文档各自承担不同验收目的。Git 非空检查只是一道自动门槛，不代替下列人工目的审查。

| SHA | 提交 / 目的 | 影响路径 | 验证 |
| --- | --- | --- | --- |
| 71e5a76 | feat: model typed EAF annotation hierarchies and owned snapshots | `.gitignore`, `model.mbt`, `model_wbtest.mbt`, `moon.mod`, `moon.pkg` | fmt / strict check / tests |
| 7a1b12c | feat: index annotation identities and validate parent tier DAGs | `graph.mbt`, `graph_wbtest.mbt` | fmt / strict check / tests |
| a92486c | feat: resolve symbolic reference paths and temporal queries | `resolve.mbt`, `resolve_wbtest.mbt` | fmt / strict check / tests |
| 1f20d86 | feat: enforce temporal parent containment and subdivision coverage | `constraints.mbt`, `constraints_wbtest.mbt` | fmt / strict check / tests |
| fc6ee66 | feat: validate symbolic associations and linked sibling subdivisions | `chains.mbt`, `chains_wbtest.mbt` | fmt / strict check / tests |
| ffaadf1 | feat: import bounded EAF XML with explicit unsupported construct errors | `moon.pkg`, `parse.mbt`, `parse_wbtest.mbt`, `xml_codec.mbt`, `xml_codec_wbtest.mbt` | fmt / strict check / tests |
| ffb1729 | feat: serialize interoperable EAF preserving references and metadata | `chains.mbt`, `graph.mbt`, `model.mbt`, `moon.mod`, `resolve.mbt`, `write.mbt`, `write_wbtest.mbt` | fmt / strict check / tests |
| 7218fa8 | feat: add atomic identity renames and annotation text edits | `edit.mbt`, `edit_wbtest.mbt` | fmt / strict check / tests |
| 4a5d8a0 | feat: transact tier replacements and chain-aware symbolic insertions | `insert.mbt`, `insert_wbtest.mbt` | fmt / strict check / tests |
| bde10a9 | feat: delete dependency closures and reconnect symbolic sibling chains | `remove.mbt`, `remove_wbtest.mbt` | fmt / strict check / tests |
| 52ed6fe | feat: extract complete utterance subtrees with ancestor-closed tier selection | `extract.mbt`, `extract_wbtest.mbt` | fmt / strict check / tests |
| b12460a | feat: retime shared anchors with checked rational timeline resampling | `retime.mbt`, `retime_wbtest.mbt` | fmt / strict check / tests |
| 8ad081c | feat: resolve corpus rows with hierarchy paths and semantic sibling order | `rows.mbt`, `rows_wbtest.mbt` | fmt / strict check / tests |
| f59b1a6 | feat: export resolved annotation corpora as quoted CSV and versioned JSON | `export.mbt`, `export_wbtest.mbt`, `moon.pkg` | fmt / strict check / tests |
| f3ff87c | fix: enforce portable XML identities and bounded metadata invariants | `edit.mbt`, `graph.mbt`, `metadata.mbt`, `metadata_wbtest.mbt`, `parse_wbtest.mbt` | fmt / strict check / tests |
| c209ca4 | test: exercise adversarial EAF graphs budgets and transaction sequences | `adversarial_wbtest.mbt`, `metadata.mbt`, `xml_codec.mbt` | fmt / strict check / tests |
| 33ad235 | feat: demonstrate curator editor and dataset workflows on hierarchical corpora | `examples/curate/main.mbt`, `examples/curate/moon.pkg`, `examples/dataset/main.mbt`, `examples/dataset/moon.pkg`, `examples/edit/main.mbt`, `examples/edit/moon.pkg`, `examples/fixture/fixture.mbt`, `examples/fixture/moon.pkg`, `examples/oracle/main.mbt`, `examples/oracle/moon.pkg` | fmt / strict check / tests |
| 4769f56 | test: compare EAF schemas pympi and CSV across 40 generated corpora | `examples/oracle/main.mbt`, `export.mbt`, `export_wbtest.mbt`, `scripts/requirements-oracle.txt`, `scripts/verify_interop.py`, `write.mbt` | fmt / strict check / tests / 40-corpus oracle |
| 44be1e1 | docs: specify Chinese usage semantic boundaries and source licenses | `LICENSE`, `PROVENANCE.md`, `README.md`, `docs/design.md`, `examples/curate/pkg.generated.mbti`, `examples/dataset/pkg.generated.mbti`, `examples/edit/pkg.generated.mbti`, `examples/fixture/pkg.generated.mbti`, `examples/oracle/pkg.generated.mbti`, `pkg.generated.mbti` | fmt / strict check / tests / source and documentation review |
| 5bc370f | docs: record multi-domain selection and source-level semantic duplication checks | `docs/competition/duplicate-check.md` | fmt / strict check / tests / source and documentation review |
| 490caf0 | ci: enforce source history and four-backend interoperability gates | `.github/workflows/ci.yml`, `scripts/check_project.py` | fmt / strict check / tests / project gate; remote CI required |
