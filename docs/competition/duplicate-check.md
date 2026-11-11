# 选题与语义查重记录

检查日期：2026-11-11。按 osc2026-guide 的 Project Research Guide 和工程交付门禁执行。不代表主办方审核结论，也不保证未索引、私有或刚发布项目均已覆盖。

## 需求与候选

比较五个不同领域的实际任务。成熟参考用于确认需求和行为；其它语言已有实现不等于 MoonBit 重复。直接替代项为硬性淘汰。

| 领域 / 候选 | 真实任务、成熟基线 | 最小闭环与客观验收 | 决策 |
| --- | --- | --- | --- |
| 生物实验 / FCS | 流式细胞读写和补偿；FlowIO / FlowKit | 事件矩阵、元数据、往返、参考读取器比对 | mawei2018/fcs 已有读写能力，淘汰 |
| 家谱 / GEDCOM 7 | 家谱交换、家庭引用；GEDCOM 规范 | 解析、关系图、写回与标准样本 | forey217/moonged 已有相同核心，淘汰 |
| 电子设计 / VCD | 仿真波形事件读取；VCD 规范 | 层级信号、事件、仿真夹具比对 | lqhy1234567/moonbit-vcd 已覆盖核心，淘汰 |
| 生物测序 / ABIF | Sanger 峰图/序列；Biopython ABI 实践 | 二进制目录、峰通道、质量值、ABI 文件 | IvanAXu/BioSeqs 已有 abi.mbt，淘汰 |
| 语言语料 / EAF | 引用层语义、编辑和提取；ELAN EAF 2.8/3.0、pympi-ling | 图校验、引用安全编辑、话语提取、表格导出；XSD、pympi、区间公式比对 | 在已查范围内可作为独立核心实现 |

评分为本次工程判断，1–5 分；风险列 5 表示风险最高，其余列 5 表示更适合。分数不能覆盖硬性重复淘汰。

| 候选 | 需求广度 | 三类用户 | 复用价值 | 重叠风险 | 技术深度 | 可验证性 | 完成可行性 | 维护成本可控性 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FCS | 4 | 4 | 4 | 5 | 4 | 5 | 4 | 4 |
| GEDCOM | 4 | 4 | 4 | 5 | 4 | 5 | 4 | 4 |
| VCD | 5 | 4 | 5 | 5 | 4 | 5 | 4 | 4 |
| ABIF | 3 | 4 | 4 | 5 | 4 | 5 | 4 | 4 |
| EAF | 4 | 4 | 5 | 2 | 5 | 5 | 4 | 4 |

三个 EAF 闭环由 examples/curate、examples/edit、examples/dataset 实现：语料整理人员导入六层文件、提取一个话语并写回；编辑工具插入/重命名/级联删除并维护引用；数据集程序把多级引用还原为时间和祖先路径。未声称做过用户访谈或外部生产部署。

## 检索方法与范围

检索 MoonCakes 名称、语义/API、别名、规范和成熟参考；每条 moon search 使用 --limit 100。对近邻继续读文档、模块版本、接口、源码和测试。另查看 awesome-moonbit 和 GitHub 的 MoonBit 仓库检索（per_page=100，EAF/ELAN 均返回 0，incomplete_results=false）。这只代表查询范围；不把 0 命中当唯一证据。完整原始输出保存在仓库外的本地研究档案。

- FCS：cytometry、cytometer、fcs、flowio、flowkit、flowCore、spillover、compensation、gating、logicle、流式细胞。
- GEDCOM：gedcom、genealogy；VCD：vcd、waveform。
- ABIF：abif、sanger、chromatogram、abi sequencing、abi_trace、read_abif、basecalling、electropherogram、phred、BioSeqs。Sanger 词未命中，仍沿 BioSeqs 源码树找到实质重复。
- EAF：elan、eaf、pympi、linguistic annotation、annotation graph、time subdivision、symbolic association、time_slot_ref、Praat、XML parser。
- 发布前反向检索：EAF、ELAN、pympi、Time_Subdivision、Symbolic_Subdivision、PREVIOUS_ANNOTATION、PARENT_REF。

## 实际近邻及处置

| 项目和版本 | 已读材料 / 能力指纹 | 分类及处置 |
| --- | --- | --- |
| [mawei2018/fcs@0.2.2](https://github.com/mawei2018/moonbit-fcs) | 接口、parser/writer、测试夹具；FCS 元数据与事件 | FCS 直接替代，淘汰候选 |
| [forey217/moonged@0.2.0](https://github.com/forey217/moonged) | 模型、解析、关系查询、夹具 | 家谱直接替代，淘汰 |
| [lqhy1234567/moonbit-vcd@0.3.1](https://github.com/lqhy1234567/moonbit-vcd) | parser、parser_test、fixture_validation_test、接口 | 波形直接替代，淘汰 |
| [IvanAXu/BioSeqs@0.1.14](https://github.com/paipai-Studio/BioSeqs) | src/abi.mbt、test/moonbit/abi_test.mbt、接口 | 测序直接替代，淘汰；Apache-2.0，不拷贝源码/夹具 |
| [Zh666-lab/moontextgrid@0.1.0](https://github.com/Zh666-lab/moontextgrid) | README、完整指纹、模型/区间实现、接口和测试；平面点层/区间层时间分区 | 相邻语料格式；不实现父层 DAG、跨层引用、继承时间和前驱链。保留 EAF 图核心，避免再做通用平面区间/重叠分析库 |
| [Milky2018/xml@0.6.1](https://mooncakes.io/docs/Milky2018/xml) | Reader / Writer 接口、实现和实际集成 | 可复用基础设施，直接依赖；不自造 XML 词法解析器，不计入源码量 |
| [walkzzz/moon-geometry@0.251.0](https://github.com/walkzzz/moon-geometry) | README、公开接口、模块树；曲线和网格细分 | subdivision 近词命中，领域不同 |
| [Juwan-Hwang/moon-certified@0.1.1](https://github.com/Juwan-Hwang/moon-certified) | 模块树、通用算法实现及精确语义词搜索 | 通用图/数据结构，不是语料标注图 |
| [marianoguerra/tutuca@0.57.1](https://github.com/marianoguerra/tutuca-moonbit) | compose/catalog/spec.mbt、merge_test.mbt、接口；Annotation 为 keywords/category/presets/hidden | UI 目录注解，与时间/父层/引用链模型不同 |

反向检索实测：EAF 0、ELAN 0、pympi 8、Time_Subdivision 2、Symbolic_Subdivision 1、PREVIOUS_ANNOTATION 1、PARENT_REF 29。非零结果逐项筛查：pympi 返回 Python 版本工具和 window/webview/event pumping 等；PARENT_REF 返回 IFC 关系、GIR、PDF ParentTree、语法树、通用图和 UI 等。描述涉及父节点但没有 EAF 语义的结果不作为直接替代；最相关的几何、算法、UI 包进一步读源码与接口。精确 EAF 语义词在上述三包 .mbt/.mbti/README 中无命中，实际模型属于其它任务。

## 实现边界与发布复核

能力指纹：对齐/引用标注 + 父层 DAG + 四种语言约束 + 符号前驱链 + 保持引用的事务编辑 + 完整话语子树 + 带继承时间的语料行。约束校验、索引、链修复、祖先闭包和时间变换均在本项目核心实现。

不做 ELAN GUI、音视频处理、全部 EAF 元素、TextGrid 通用转换、重叠度/一致率平台。未知语义元素或属性报 Unsupported；不保留 XML 词法布局。

行为基线为固定上游提交的 EAF XSD 和 pympi-ling 1.70.2；测试输入由程序合成，不复制第三方语料。每目标 40 文档 / 880 标注，与 XSD、独立解析器、时间公式和标准 CSV 读取器比对。见 PROVENANCE.md 和 scripts/verify_interop.py。

注册表已在固定排他锁内预留和登记外部检查；完成状态只在公开发布和全新消费者验证通过后更新。结论为“已检查的公开结果中未确认 EAF 图核心的直接替代项”，不是全生态唯一性证明或官方验收保证。
