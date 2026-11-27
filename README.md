# MoonELAN

MoonELAN 是面向 ELAN EAF 语料的 MoonBit 文件处理与层级标注库。它提供两层公共接口：EAF 3.0 文件模型负责标准结构验证与信息保留，语义模型负责受约束的层级校验、引用安全编辑和数据集导出。调用者不必为了使用图编辑能力而把合法的未知时间、控制词表或帧时间从原始文件中删除。

模块：`y666-sos/moonelan@0.3.0`。许可证：MIT。

## 用户与工作流

- 语料维护者读取尚未对齐的标注，保留语言、词表和外部引用，重命名标注后写回可由独立工具读取的文件。
- 标注工具通过文件模型接受标准 EAF 3.0，按需显式投影为严格语义模型；不适合图编辑策略的文件仍可保留和处理。
- 数据集流水线解析多层引用、祖先路径与可选时间，导出 CSV / JSON；未知边界保持空值，不用零或插值伪造时间。
- 档案系统校验结构与引用，使用调用者提供的外部词表资源离线核对条目，不因网络不可用而假称内容已验证。

这些是可运行 API 工作流，不是外部用户部署或性能测评声明。

## 安装与快速开始

固定验证工具链 MoonBit `0.10.18+6c83a7f62`，对应 moon `0.1.20261028`；依赖 `Milky2018/xml@0.6.1`。不声称这是当前最新工具链。

```sh
moon add y666-sos/moonelan@0.3.0
```

在使用包的 `moon.pkg` 中添加：

```moonbit
import {
  "y666-sos/moonelan" @eaf,
}
options("is-main": true)
```

保存为该包的 `main.mbt`，执行 `moon run 路径/到/这个包`：

```moonbit
fn main raise {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="demo" DATE="2026-11-27T00:00:00Z" VERSION="3.0">
    #|<HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s0"/><TIME_SLOT TIME_SLOT_ID="s1" TIME_VALUE="4294967295"/></TIME_ORDER>
    #|<TIER TIER_ID="speech" LINGUISTIC_TYPE_REF="utterance"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a1" TIME_SLOT_REF1="s0" TIME_SLOT_REF2="s1"><ANNOTATION_VALUE>你好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="utterance"/>
    #|</ANNOTATION_DOCUMENT>
  let input = @eaf.parse_file(xml)
  let edited = @eaf.file_rename_annotation(input, "a1", "utterance_1")
  let edited = @eaf.file_set_time(edited, "s0", Some(2147483648L))
  let output = @eaf.write_file(edited)
  assert_eq(@eaf.parse_file(output), edited)
  assert_true(output.contains("4294967295"))
  println(output)
}
```

文件系统读写由调用方实现。库接收已解码的 UTF-8 字符串并返回结构化对象或 XML 字符串；媒体与词表 URL 只是标识，不会触发下载。

## EAF 3.0 文件模型与符合性终点

`EafFile` 保存结构化元素、属性及文本。`parse_file`、`validate_file`、`write_file` 覆盖固定版本 EAF 3.0 XSD 声明的 27 种元素、98 项属性、顺序与基数、必填属性、枚举、数据类型、ID 与引用约束；涵盖 ANNOTATION_DOCUMENT 和 CV_RESOURCE 两个入口。不是“常用标签可以读取就算符合”的终点，也不是任意 XML Schema 的通用解释器。

- 时间槽使用 `Int64` 承载 `xsd:unsignedInt` 的 0～4294967295 范围；媒体与链接文件 TIME_ORIGIN 支持 -9223372036854775808～9223372036854775807。TIME_VALUE 缺失保持未对齐，不能把范围扩大到超出标准的数据。
- 文件模型接受 milliseconds、PAL-frames、NTSC-frames，保留自定义 CONSTRAINT 及其描述；不对帧值冒充毫秒运算。合法零长区间和应用尚未完成的编辑状态不会仅因图策略被拒绝。
- 保留内置多语言词表、语言/区域、许可证、媒体、属性、链接文件、词典、外部引用、SVG 标识和 EAF 3.0 交叉／分组引用链接。
- 日期接受 XML Schema dateTime 的合法年份、精度、时区及日终表示；XML ID 支持 Unicode。格式版本入口明确为 EAF 3.0；EAF 2.8 的既有兼容路径不等于全模型符合性承诺。
- 文件接口按标准结构拒绝未知元素/属性、重复 ID、悬空引用和不合法值。另检查上游 schema 的引用链接键引用漏写 `@` 所对应的实际目标，避免接受悬空链接。

| 任务 | 公共 API / 行为 |
| --- | --- |
| 读取、校验与写回 | `parse_file`、`validate_file`、`write_file` |
| 标注重命名 | `file_rename_annotation` 同步标注、前驱和引用链接目标 |
| 文本和时间编辑 | `file_set_value` 清除旧 CVE_REF；`file_set_time` 接受 Int64? |
| 词表查询与选择 | `file_cv_value`、`file_select_cv` 原子选择文本、CVE_REF、LANG_REF |
| 词表内容验证 | `file_validate_vocabularies(resources=...)`；外部资源须由调用者明确提供 |
| 进入图模型 | `file_document`，显式报出不支持的编辑策略 |
| 图模型转文件 | `document_file`，不再混淆文件符合性与图约束 |

全部修改返回经验证的新对象，不修改原输入。外部词表只有 EXT_REF 或含 DESCRIPTION 时均需实际资源；缺资源、条目不匹配或资源歧义时明确报错，不将“结构合法”包装成“词表内容已验证”。外部资源选择按 CV_ID 及条目/语言匹配，获取 URL、缓存和访问控制由调用者负责。

## 语义图模型与数据集能力

`Document` 描述作者、日期、媒体、属性、时间槽、语言类型、层及 `extensions`。`TimeSlot.milliseconds` 为 `Int64?`；`Span`、`Timing` 与导出时间也使用 Int64。`Annotation` 区分时间对齐标注与引用标注。图模型要求毫秒时间和已实现的四种标准层级策略；自定义约束或帧时间须留在文件模型，不能默默投影成另一种意义。

| 任务 | API |
| --- | --- |
| 图导入/写出 | `parse`、`write`，EAF 2.8/3.0 既有语义路径 |
| 结构与时间校验 | `validate_structure`、`validate_temporal`、`validate` |
| 未知时间 | `annotation_timing` 返回可选边界；`retime` 完成或撤销对齐 |
| 内置词表 | `vocabulary_choices`、`set_controlled_value` |
| 引用和祖先 | `resolve`、`reference_path`、`parent_annotation`、`tier_ancestors` |
| 名称和文本 | `rename_annotation`、`rename_tier`、`set_value` |
| 插入/删除 | `add_tier`、`replace_annotations`、`insert_reference`、`remove_annotation`、`remove_tier` |
| 提取与重采样 | `select_tiers`、`extract_roots`、`retime`、`resample` |
| 数据集导出 | `corpus_records`、`corpus_rows`、`to_csv`、`to_json` |

引用标注须指向直接父层，跨层继承时间；符号细分按前驱链排序。语义校验检查父层 DAG、时间包含/细分、符号关联与链归属。这些是编辑器策略，不应当用于否定其他合法 EAF 3.0 文件。

CSV 使用 CRLF，引用所有数据字段并保留换行与引号；不会改写以 `=` 等字符开头的文本，电子表格导入应按文本列处理。JSON schema 为 `moonelan.corpus.v2`，未知时间为 null；CSV 对应为空。`corpus_rows` 要求完整时间，`corpus_records` 可保留未定时间。

### 迁移

从 0.2.0 升级：时间与偏移参数由 Int32 升为 Int64，显式 Int32 变量需 `.to_int64()`；Int64 常量可用 `2147483648L`。重采样比例仍为正 Int32，时间计算逐步检查溢出及标准范围。已有 `Document` API 继续可用，需全模型信息保留时改用 `parse_file` / `write_file`。

从 0.1.0 升级还须：时间槽改用 `Some(ms)` 或 `None`；直接构造 Document 时加 `extensions: empty_extensions()`；导出空时间按 schema v2 处理。

## 可运行工作流

```sh
moon run examples/quickstart
moon run examples/curate
moon run examples/edit
moon run examples/dataset
moon run examples/compatibility
moon run examples/foreign
moon run examples/conformance
```

`curate` 提取话语子树；`edit` 插入符号单元、级联删除和移动时间轴并断言输入未变；`dataset` 导出带祖先路径的 20 条记录。`compatibility` 演示未对齐时间和内置多语言词表。`conformance` 使用帧时间、unsignedInt 上界、signed long 下界和描述型外部词表占位，离线提供 CV_RESOURCE 后选值、改名、调整时间并写回；缺资源验证必须失败。

## 验证与复现

```sh
moon info
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build --deny-warn
python scripts/check_project.py
python -m pip install -r scripts/requirements-oracle.txt
python scripts/verify_interop.py --target wasm-gc
python scripts/verify_compatibility.py --target wasm-gc
python scripts/verify_conformance.py --target wasm-gc
python scripts/build_eaf30_rules.py _build/oracle-schemas/eaf3.0.xsd --check
```

CI 配置对 wasm-gc、wasm、js、native 执行严格检查/测试/构建、用户工作流及三个独立验证程序。JS 需 Node.js；Linux native 需 C 编译器。Windows 本地未装 MSVC 和 Windows SDK，native 执行以 Linux CI 为准；配置存在不代表任何指定提交已通过 CI。

符合性矩阵从独立 Python 输入出发，以固定哈希上游 XSD 校验输入及输出，再调用公共 MoonBit 文件 API；覆盖全部 27 种元素及 98 项属性，包含合法边界与非法变体。另用 pympi-ling 1.70.2 读取三个文档核对关键字段；pympi 对 ID/提示属性有自身假设，不是通用符合性裁判。既有独立检查继续覆盖 40 文档 / 880 标注、16 组兼容组合 / 64 标注及一份外部工具生成输入，不以自写自读代替独立验证。

具体检查范围、样本与证据见 [EAF 3.0 验证说明](docs/competition/conformance-0.3.0.md)，0.2.0 历史验证见 [兼容性验证](docs/competition/compatibility-0.2.0.md)。全部数据为原创合成样本，没有真实个人语料；没有组委会私有测试集，不声称通过官方复审。

## 资源、安全与能力边界

默认输入上限 2,000,000 个 UTF-16 单元、100,000 个 XML 事件、32 层深度；图模型默认 256 层/语言类型、10,000 条标注。调用者可传 limits 调整；结构标注预算最高 1,000,000。文件模型也限制元素节点与深度。依赖会缓冲 XML，本项目不是流式解析器，图模型部分区间检查最坏二次比较，不承诺大型语料性能。

拒绝 DTD/实体声明以避免扩展实体；CDATA、注释中的同样字面量不是声明。未知厂商扩展、带目标命名空间的 EAF 元素和任意派生 xsi:type 不在范围内；允许声明的相同类型及常见 schema 提示。注释、处理指令、排版和原始属性顺序不保留；格式保留指标准元素/属性/文本的语义保留，而非字节相同。XML 声明只接受 UTF-8。输入字符串解码、媒体播放、桌面 UI、网络获取和自动语音标注不属于本库。

## 来源、许可与 AI 使用

原创实现使用 MIT。运行时依赖 Apache-2.0 的 Milky2018/xml；独立测试使用 lxml 和 MIT 的 pympi-ling，非运行时依赖。EAF XSD 下载到忽略缓存且不再分发；生成器提取固定 schema 的结构事实，生成表不计入实质生产代码行数。未移植 ELAN 桌面程序或 pympi 实现。

AI 参与设计、实现、测试、调试和文档；提交者负责来源和结果审查。来源见 [PROVENANCE.md](PROVENANCE.md)，设计见 [docs/design.md](docs/design.md)，相邻方案见 [生态比较](docs/competition/duplicate-check.md)。
