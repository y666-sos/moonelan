# MoonELAN

MoonELAN 是面向 ELAN EAF 语料的 MoonBit 层级标注库。它把时间对齐标注、引用标注、父子层和符号细分顺序组成可校验的图，支持引用安全编辑、话语子树提取，以及带继承时间和祖先路径的 CSV / JSON 数据集导出。

模块：`y666-sos/moonelan@0.1.0`。许可证：MIT。

## 谁可以使用

- 语料整理人员：导入受支持的 EAF，检查悬空引用、层级循环、细分缺口和符号链错误，提取指定话语后重新保存。
- 标注工具开发者：重命名标注或层、插入符号单元、删除依赖子树、调整共享时间锚点，获得通过完整校验的新文档。
- 数据集构建者：保留词、形态和词性之间的祖先路径，把没有自身时间槽的标签解析到对齐区间，再导出训练表格。

这些是 API 的使用场景；项目未声称做过用户访谈或外部生产部署。

## 安装与运行环境

本项目固定验证 MoonBit `0.10.15+943464bfa`，对应 moon `0.1.20261012`。依赖 `Milky2018/xml@0.6.1`，由它处理 XML 词法、实体转义和文档结构；本项目实现 EAF 语义。

在已有 MoonBit 模块中执行：

```sh
moon add y666-sos/moonelan@0.1.0
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

`Document` 包含作者、日期、版本、媒体、属性、时间槽、语言类型和层。`Annotation` 区分 `Aligned(id, start_slot, end_slot, value)` 与 `Reference(id, target, previous, value)`。引用只能指向直接父层的标注；可跨多级引用继承时间。

| 任务 | API 与行为 |
| --- | --- |
| EAF 导入/写出 | `parse` / `write`，遇到未知语义元素或属性返回错误 |
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
], times=[{ id: "sm", milliseconds: 400 }])
```

更完整的构造方式见 [合成语料](examples/fixture/fixture.mbt)；全部公开接口见 [pkg.generated.mbti](pkg.generated.mbti)。

## 语义约束与错误

- `Time_Subdivision`：同层无重叠，每个已标注的父标注组完整、连续覆盖父区间。尚未开始标注的空子组允许存在。
- `Included_In`：同层无重叠，每条子标注恰好属于一个包含它的父标注；允许间隙。
- `Symbolic_Association`：每个父标注最多一个子标注，禁止前驱链接。
- `Symbolic_Subdivision`：每个父标注下恰好一条无分叉、无环且连通的前驱链。XML 中的存放顺序不决定语义顺序。
- 所有时间区间为正长度；查询窗口使用半开区间 `[start, end)`。非负时间上限为 `2147483647` 毫秒。
- 编辑先校验输入，复制后执行，再校验结果。失败不会改变输入；删除部分时间细分若导致缺口会失败，调用方可用整组替换完成重新分段。
- `resample` 使用 Int64 中间计算，按非负整数向下取整；时间溢出、负值和舍入导致区间塌缩均拒绝。

`EafError` 分为 `Invalid`、`Unsupported`、`Budget`、`Xml`。错误消息描述结构，不附带标注正文。只做结构查询的 `resolve`、`reference_path` 等不会替调用者完成全部细分约束校验；进入编辑、导出或业务处理前使用 `validate`。

## 支持范围和明确限制

本库实现 EAF 2.8 / 3.0 的严格子集，不是完整 ELAN 替代品，也不是通用 XSD 校验器。

支持 `HEADER` 内媒体描述和属性、已赋值时间槽、两类标注、父层、参与者、标注者、语言类型和四类约束。输入必须使 FORMAT 与 VERSION 相同。日期限四位公历年份的 ISO dateTime；不支持闰秒和 24:00。标注和时间槽 ID 限 ASCII NCName 子集，二者及约束声明共享 XML ID 唯一性；层与类型标签可含中文但不能含空白或 XML 危险字符。

明确拒绝未对齐时间槽、控制词表、词典、语言/区域定义、外部引用、链接文件、图形引用、命名空间 EAF 元素、未知属性及 DTD。TIME_ORIGIN 限非负 Int32；负媒体偏移不支持。布尔属性使用 `true` / `false`。XML 声明编码仅支持 UTF-8。

XML 注释、处理指令、排版及原始属性顺序不保存；约束说明在写出时规范化为四项标准名称。已识别的 xsi schema 位置属于提示元数据，写出时规范化。不会静默删除未知语义内容。文本中的 `<!DOCTYPE` / `<!ENTITY` 字面量也会触发保守拒绝。

默认上限：输入 2,000,000 个 UTF-16 单元、100,000 个 XML 事件、32 层深度、256 个层/语言类型和 10,000 条标注。`parse(..., limits=...)` 可设置预算；结构标注预算最高 1,000,000，避免乘法溢出。XML 依赖本身会缓冲输入，本项目不是流式解析器。时间子层的父区间归属最坏为二次比较，不作大型语料性能承诺。

CSV 使用 CRLF 行尾并引用所有数据字段，正文中的换行、逗号和引号保留。它不会修改以 `=` 等字符开头的文本，导入电子表格时应按文本列处理。JSON schema 名为 `moonelan.corpus.v1`，`parent` 为字符串或 null；符号单元即使共享区间也各自占一行。

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

CI 针对 `wasm-gc`、`wasm`、`js`、`native` 执行严格检查、测试、构建、三个示例和独立兼容性检查。JS 需 Node.js；Linux native 使用 C 编译器。Windows 的 native 运行需安装 MSVC C++ Build Tools 和 Windows SDK；本次 Windows 本地环境未安装它们，因此 native 执行以 Linux CI 为准。

26 个 MoonBit 测试覆盖引用归属、层级循环、时间覆盖、符号链、恶意 XML、预算、日期、XML ID、时间溢出和事务不变性；其中一项包含 60 组编辑序列。独立 Python 检查每个目标的 40 份原创合成文档和 880 条标注，核对固定哈希的 EAF 2.8/3.0 XSD、pympi 1.70.2 读取结果、闭式期望时间、JSON 和 Python CSV 解码。该检查不证明任意 ELAN 工程均可兼容。

独立检查按固定版本从 ELAN 源码镜像下载 schema 到 `_build`，不将第三方 schema 放入源码包。离线使用可通过 `--schema-dir` 指定已有且哈希匹配的缓存。

## 来源、许可与 AI 使用

本项目是原创 MoonBit 实现，不是 pympi 代码移植。实现和测试数据由本项目编写；未复制真实个人语料。XML 解析和写出复用 Apache-2.0 的 `Milky2018/xml`；独立行为对照使用 MIT 的 pympi-ling。EAF 规范和 schema 仅用于理解、外部验证；不随本项目再分发。

AI 参与选题研究、设计、实现、测试、调试和文档编写。提交者负责审查实现、来源与发布结果。详细来源与边界见 [PROVENANCE.md](PROVENANCE.md)，设计见 [docs/design.md](docs/design.md)，检索范围与相邻项目比较见 [docs/competition/duplicate-check.md](docs/competition/duplicate-check.md)。
