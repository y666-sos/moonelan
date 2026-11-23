# MoonELAN

MoonELAN 是面向 ELAN EAF 语料的 MoonBit 层级标注库。它把时间对齐标注、引用标注、父子层和符号细分顺序组成可校验的图，支持引用安全编辑、话语子树提取，以及带继承时间和祖先路径的 CSV / JSON 数据集导出。

模块：`y666-sos/moonelan@0.2.0`。许可证：MIT。

0.2.0 将未对齐时间、内置多语言控制词表及其标注绑定接入读写、校验、编辑和导出；同时保留语言/区域、链接文件、词典/外部引用和 EAF 3.0 引用链接。常见标注工程可以在尚未完成时间对齐时继续整理，不需要先给未知边界填写假时间。

## 谁可以使用

- 语料整理人员：导入受支持的 EAF，检查悬空引用、层级循环、细分缺口和符号链错误，提取指定话语后重新保存。
- 标注工具开发者：重命名标注或层、插入符号单元、删除依赖子树、调整共享时间锚点，获得通过完整校验的新文档。
- 数据集构建者：保留词、形态和词性之间的祖先路径，把没有自身时间槽的标签解析到对齐区间，再导出训练表格。

这些是 API 的使用场景；项目未声称做过用户访谈或外部生产部署。

## 安装与运行环境

本项目固定验证 MoonBit `0.10.18+6c83a7f62`，对应 moon `0.1.20261028`。依赖 `Milky2018/xml@0.6.1`，由它处理 XML 词法、实体转义和文档结构；本项目实现 EAF 语义。

在已有 MoonBit 模块中执行：

```sh
moon add y666-sos/moonelan@0.2.0
```

使用它的包在 `moon.pkg` 中添加：

```moonbit
import {
  "y666-sos/moonelan" @eaf,
}
options("is-main": true)
```

保存以下代码为该包的 `main.mbt`，执行 `moon run 路径/到/这个包`：

```moonbit
fn main raise {
  let xml =
    #|<ANNOTATION_DOCUMENT AUTHOR="demo" DATE="2026-11-11T00:00:00Z" FORMAT="3.0" VERSION="3.0">
    #|<HEADER/><TIME_ORDER><TIME_SLOT TIME_SLOT_ID="s0" TIME_VALUE="0"/><TIME_SLOT TIME_SLOT_ID="s1" TIME_VALUE="1000"/></TIME_ORDER>
    #|<TIER TIER_ID="speech" LINGUISTIC_TYPE_REF="utterance"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="a1" TIME_SLOT_REF1="s0" TIME_SLOT_REF2="s1"><ANNOTATION_VALUE>你好</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
    #|<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="utterance" TIME_ALIGNABLE="true"/>
    #|</ANNOTATION_DOCUMENT>
  let document = @eaf.parse(xml)
  let edited = @eaf.rename_annotation(document, "a1", "utterance_1")
  assert_eq(@eaf.resolve(edited, "utterance_1"), { start: 0, end: 1000 })
  println(@eaf.to_json(edited))
}
```

文件读取和保存由调用方提供。库接收已解码的字符串，返回字符串或结构化值；媒体 URL 只作为元数据保存，不会下载媒体或访问文件。

## 三个完整工作流

从仓库根目录运行，示例包含断言：

```sh
moon run examples/curate
moon run examples/edit
moon run examples/dataset
```

`curate` 将六层合成 EAF 导入并校验，再按 `a0` 提取一个话语和其 11 条标注，重新写出并验证往返一致性。

`edit` 重命名根标注、向符号细分链插入前缀、级联删除带词性子标注的形态单元，并整体移动时间轴。它核对链顺序、更新后的引用以及原文档未被修改。

`dataset` 选取词性和翻译层，自动保留所需祖先层，输出 20 条带毫秒时间、父标注、根标注和完整祖先路径的 JSON 记录。

## 数据模型与 API

`Document` 包含作者、日期、版本、媒体、属性、时间槽、语言类型、层及结构化 `extensions`。`TimeSlot.milliseconds` 为 `Int32?`：`Some(ms)` 表示已对齐，`None` 表示未定边界。`Annotation` 区分 `Aligned(id, start_slot, end_slot, value)` 与 `Reference(id, target, previous, value)`。引用只能指向直接父层的标注；可跨多级引用继承时间。

| 任务 | API 与行为 |
| --- | --- |
| EAF 导入/写出 | `parse` / `write`，常见 EAF 2.8/3.0 元素和属性保留；未知语义报错 |
| 未对齐时间 | `annotation_timing` 返回可选起止值；`retime` 可完成或撤销对齐 |
| 多语言词表 | `vocabulary_choices` 查询内置选项；`set_controlled_value` 原子更新文本、CVE_REF 和 LANG_REF |
| 配套元数据 | `extensions` 保留语言/区域、词典、链接文件、外部引用、许可证及引用链接 |
| 可缺失时间的表格 | `corpus_records`、`to_csv` / `to_json`，保留层级及未定边界 |
| 校验 | `validate_structure`、`validate_temporal`、完整 `validate` |
| 时间与路径 | `resolve`、`reference_path`、`parent_annotation`、`tier_ancestors` |
| 子单元顺序 | `children`，时间层按起始时间，符号细分按 `PREVIOUS_ANNOTATION` |
| 名称和文本 | `rename_annotation`、`rename_tier`、`set_value` |
| 增加和替换 | `add_tier`、`replace_annotations`、`insert_reference` |
| 删除 | `remove_annotation(cascade=true)`、`remove_tier`，修复符号前驱链 |
| 层级提取 | `select_tiers` 保留祖先层；`extract_roots` 保留完整话语子树 |
| 时间编辑 | `retime` 同时修改共享时间槽；`resample` 使用有理比例和偏移 |
| 语料导出 | `corpus_rows`、`rows_between`、`to_csv`、`to_json` |
| 所有权 | `snapshot` 深复制嵌套数组；编辑均返回新文档 |

例如，存在 `words` 层时，可同时替换一组细分标注和新时间槽：

```moonbit
let changed = @eaf.replace_annotations(document, "words", [
  @eaf.Aligned("w1", "s0", "sm", "你"),
  @eaf.Aligned("w2", "sm", "s1", "好"),
], times=[{ id: "sm", milliseconds: Some(400) }])
```

更完整的构造方式见 [合成语料](examples/fixture/fixture.mbt)；全部公开接口见 [pkg.generated.mbti](pkg.generated.mbti)。

## 语义约束与错误

- `Time_Subdivision`：同层无重叠，每个已标注的父标注组完整、连续覆盖父区间。尚未开始标注的空子组允许存在。
- `Included_In`：同层无重叠，每条子标注恰好属于一个包含它的父标注；允许间隙。
- `Symbolic_Association`：每个父标注最多一个子标注，禁止前驱链接。
- `Symbolic_Subdivision`：每个父标注下恰好一条无分叉、无环且连通的前驱链。XML 中的存放顺序不决定语义顺序。
- 已对齐区间必须为正长度。存在未定边界时，以 TIME_ORDER 槽序检查层级包含、重叠和细分连续性；已知锚点须按序排列，不插值、不赋予未知槽毫秒值。`annotation_timing` 和 `corpus_records` 保留未知值，引用标注继承同样的可选边界。
- `resolve` 与 `corpus_rows` 是要求完整时间的接口；涉及的标注仍未对齐时返回明确错误。查询窗口使用半开区间 `[start, end)`。非负时间上限为 `2147483647` 毫秒；媒体及链接文件偏移支持有符号 Int32。
- 编辑先校验输入，复制后执行，再校验结果。失败不会改变输入；删除部分时间细分若导致缺口会失败，调用方可用整组替换完成重新分段。
- `resample` 使用 Int64 中间计算，按非负整数向下取整；时间溢出、负值和舍入导致区间塌缩均拒绝。

`EafError` 分为 `Invalid`、`Unsupported`、`Budget`、`Xml`。错误消息描述结构，不附带标注正文。只做结构查询的 `resolve`、`reference_path` 等不会替调用者完成全部细分约束校验；进入编辑、导出或业务处理前使用 `validate`。

## 支持范围和明确限制

本库以 EAF 2.8 / 3.0 常用标注工程的语义兼容为目标，主要格式路径包括：

- 已对齐和未对齐的 TIME_SLOT、时间/引用标注、父子层、参与者和标注者、语言类型与四种标准约束。
- 内置多语言控制词表的描述、条目、语言及说明，类型的 CONTROLLED_VOCABULARY_REF、标注的 CVE_REF/LANG_REF；校验内部绑定是否存在且文本与所选语言一致。`set_controlled_value` 会同时更新三项数据；直接 `set_value` 若留下不匹配的旧绑定则事务失败。
- LANGUAGE、LOCALE、DEFAULT_LOCALE、许可证、无名属性、旧式 MEDIA_FILE、EXTRACTED_FROM、负媒体偏移、LINKED_FILE_DESCRIPTOR、LEXICON_REF、EXTERNAL_REF、SVG_REF。保留标准配套元数据及外部资源地址，不下载文件或联网访问词典。
- EAF 3.0 的 REF_LINK_SET、CROSS_REF_LINK、GROUP_REF_LINK；重命名会更新引用，删除/提取会级联清理失去目标的链接。外部词表地址和标注绑定可往返保留；离线状态无法核验外部条目内容，`vocabulary_choices` 对未装入的外部词表明确返回错误。

层名/类型名可含空格，XML ID 接受 XML 1.0 的 Unicode NCName。布尔属性接受 `true` / `false` / `1` / `0`。输入省略 FORMAT 时采用 VERSION。日期限四位公历年份的 ISO dateTime；不支持闰秒和 24:00。

本库不实现 ELAN 图形界面、音视频处理、外部资源抓取或任意版本/厂商扩展，也不是通用 XSD 校验器。时间存储使用上述 Int32 范围；TIME_UNITS 限 milliseconds；XML 声明编码仅支持 UTF-8。命名空间 EAF 元素、未知语义属性和 DTD 明确拒绝。

XML 注释、处理指令、排版及原始属性顺序不保存；标准约束说明和 xsi schema 位置在写出时规范化。语义元数据以结构化元素及对象属性保存，不把无法理解的 XML 当作已支持内容吞入。文本中的 `<!DOCTYPE` / `<!ENTITY` 字面量也会触发保守拒绝。

### 从 0.1.0 迁移

- 时间槽构造从 `{ id: "s", milliseconds: 400 }` 改为 `{ id: "s", milliseconds: Some(400) }`；未定边界使用 `None`。
- 直接构造 `Document` 时添加 `extensions: @eaf.empty_extensions()`；使用 `empty_document()` 再更新字段的代码无需新增字段。
- 导出 JSON 的 schema 为 `moonelan.corpus.v2`，`start_ms`/`end_ms` 可以为 null；CSV 对应字段为空。完整时间输入的数值和行顺序保持一致。`corpus_records` 可处理未定时间，`corpus_rows` 保留完整时间要求。

```moonbit
// 对已导入文档 d 的真实标注调用；不为未知时间编造默认值。
let timing = @eaf.annotation_timing(d, "w1")
let choices = @eaf.vocabulary_choices(d, "pos", "zho")
let edited = @eaf.set_controlled_value(d, "p1", "verb", "eng")
let aligned = @eaf.retime(edited, [{ id: "边界1", milliseconds: Some(400) }])
```

完整输入和断言见 `moon run examples/compatibility`；外部工具生成输入见 `moon run examples/foreign`。上面的片段使用该示例中的标注、层和词表标识。
默认上限：输入 2,000,000 个 UTF-16 单元、100,000 个 XML 事件、32 层深度、256 个层/语言类型和 10,000 条标注。`parse(..., limits=...)` 可设置预算；结构标注预算最高 1,000,000，避免乘法溢出。XML 依赖本身会缓冲输入，本项目不是流式解析器。时间子层的父区间归属最坏为二次比较，不作大型语料性能承诺。

CSV 使用 CRLF 行尾并引用所有数据字段，正文中的换行、逗号和引号保留。它不会修改以 `=` 等字符开头的文本，导入电子表格时应按文本列处理。JSON schema 名为 `moonelan.corpus.v2`，`parent` 为字符串或 null，未定时间为 null；符号单元即使共享区间也各自占一行。

## 检查、测试和构建

```sh
moon info
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build --deny-warn
python scripts/check_project.py
python -m pip install -r scripts/requirements-oracle.txt
python scripts/verify_interop.py --target wasm-gc
```

CI 针对 `wasm-gc`、`wasm`、`js`、`native` 执行严格检查、测试、构建、三个工作流、兼容性/外部输入示例和独立兼容性检查。JS 需 Node.js；Linux native 使用 C 编译器。Windows 的 native 运行需安装 MSVC C++ Build Tools 和 Windows SDK；本次 Windows 本地环境未安装它们，因此 native 执行以 Linux CI 为准。

34 个 MoonBit 测试覆盖引用归属、层级循环、时间覆盖、符号链、恶意 XML、预算、日期、XML ID、时间溢出和事务不变性；其中一项包含 60 组编辑序列。独立 Python 检查每个目标的 40 份原创合成文档和 880 条标注，核对固定哈希的 EAF 2.8/3.0 XSD、pympi 1.70.2 读取结果、闭式期望时间、JSON 和 Python CSV 解码。该检查不证明任意 ELAN 工程均可兼容。

新增 `python scripts/verify_compatibility.py --target wasm-gc` 对 16 组两版本、四种对齐状态和双语言词表组合检查 64 条标注，另核验 1 份 pympi 1.70.2 生成的外部输入及其编辑写出结果。新用例验证空值时间、词表选择、语言/词典/外部引用及链接保留；旧版两个拒绝行为已在隔离 0.1.0 源码上复现。全部样本是原创合成数据，没有真实个人语料；没有组委会原始测试文件，未宣称复现其私有样本。

独立检查按固定版本从 ELAN 源码镜像下载 schema 到 `_build`，不将第三方 schema 放入源码包。离线使用可通过 `--schema-dir` 指定已有且哈希匹配的缓存。

## 来源、许可与 AI 使用

本项目是原创 MoonBit 实现，不是 pympi 代码移植。实现和测试数据由本项目编写；未复制真实个人语料。XML 解析和写出复用 Apache-2.0 的 `Milky2018/xml`；独立行为对照使用 MIT 的 pympi-ling。EAF 规范和 schema 仅用于理解、外部验证；不随本项目再分发。

AI 参与选题研究、设计、实现、测试、调试和文档编写。提交者负责审查实现、来源与发布结果。详细来源与边界见 [PROVENANCE.md](PROVENANCE.md)，设计见 [docs/design.md](docs/design.md)，检索范围与相邻项目比较见 [docs/competition/duplicate-check.md](docs/competition/duplicate-check.md)。

0.2.0 的问题—实现—独立验证映射见 [兼容性验证](docs/competition/compatibility-0.2.0.md)。
