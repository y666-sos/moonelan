# EAF 3.0 文件符合性与回归验证（0.3.0）

## 验收终点

终点是 `parse_file → 文件级编辑/验证 → write_file`，覆盖固定 EAF 3.0 schema 的声明模型，而非只接受四种层级策略的 Document 图模型。`file_document` 是显式、有可能失败的策略投影；投影限制不缩小文件读写支持范围。

| 问题 | 实现与可运行证据 |
| --- | --- |
| Int32 排除标准时间 | TimeSlot/Span/Timing/偏移改为 Int64；unsignedInt 上界 4294967295、有符号 long 两端、越界与重采样溢出见 wide_time_wbtest.mbt、file_wbtest.mbt |
| 未对齐时间 | 文件模型保留 TIME_VALUE 缺失；图模型继续处理 None，导出 null/空字段，已有 compatibility/foreign 流程回归 |
| 标准词表 | 文件模型支持内置多语言 CV 与 CV_RESOURCE；file_select_cv/file_validate_vocabularies 支持调用者提供的资源；缺失、歧义和不匹配报错；描述占位不误认为已有条目 |
| 仅常用元素子集 | 27 种元素、98 项属性由固定上游 schema 提取；覆盖顺序、基数、类型、必填、枚举和引用；帧时间、自定义约束说明、链接等不因图策略被抛弃 |
| 缺少共同版本终点 | 明确 VERSION 3.0 的格式入口，独立 XSD 验证输入和输出，语义树比较证明标准信息保留；不把本库自写自读作为唯一证据 |

## 独立对照

`scripts/verify_conformance.py` 由 Python 创建原创合成输入，经 lxml 的上游 XSD 校验后交给公共 MoonBit API。覆盖每个元素和每项属性，并对必填缺失、非法枚举、边界溢出、顺序/基数、ID/引用等构造反例。输出再经 XSD 校验，并比较元素、属性与文本的语义树。属性顺序、格式空白不作为标准信息差异。

矩阵包含 110 个合法案例、79 个非法案例。计数是脚本生成的实际样本数，不是 110 份真实外部语料。三个文档还经 pympi-ling 1.70.2 读取，核对宽时间、偏移及文本；其读取器对标识符数字、schema 提示及可选 CONSTRAINT DESCRIPTION 有假设，独立 XSD 才是本流程的结构对照。无 schema 提示、Unicode ID 等仍由其他矩阵案例验证，不为满足 pympi 而收窄 API。

已有 `verify_interop.py` 的 40 文档 / 880 标注和 `verify_compatibility.py` 的 16 组 / 64 标注及一个外部工具输入继续执行。新流程测试外部词表选值、重命名、时间编辑和原输入不变，不将保留 EXT_REF 等同于远端内容已验证。

## 可复现来源

- Schema 镜像固定提交：`4e9eb6e0e70e549471816ee30096138ce166a7c3`，路径 `src/main/resources/mpi/eudico/resources/EAFv3.0.xsd`。
- EAF 3.0 SHA-256：`59e76f90d5840813314b1e635480d044287b811ebd63a40e25cb4e73c6ad72bb`。
- `scripts/build_eaf30_rules.py` 生成声明事实表；`--check` 比较格式化后的词法流，防止手改规则偏离来源。生成表不计入生产实质代码行数。
- schema 只下载至忽略的 `_build/oracle-schemas`，不在源码包中分发；可用 `--schema-dir` 指定经哈希核验的本地缓存。
- 本地/CI 运行命令见根 README；各后端输出 `_build/eaf30-conformance-TARGET.json`，计数和布尔结果由执行产生。

## 边界与结论强度

这是所声明 EAF 3.0 格式模型的实现与可复现验证，不是任意 XML Schema 执行器或 ELAN 桌面软件。没有媒体播放、网络词表获取、未知厂商扩展或任意 xsi 派生类型；不保留注释、处理指令与原始排版。安全预算和 DTD 拒绝是明确的资源策略。EAF 2.8 保留历史兼容路径，不是本次全模型终点。

上游 XSD 引用链接的个别键引用 selector 漏写 `@`，文件校验另检查实际标注/链接目标；这些是额外的有效引用安全检查，并非对通用 XSD 一致性作无限承诺。图模型的时间包含、细分链等约束也是单独策略。测试没有组委会私有样本，不能据此保证复审结果。
