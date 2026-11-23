# 0.2.0 常用 EAF 标注语义兼容性验证

0.1.0 的可验证发布基线为 `5fba34db293b58827d645784196b1ab5ff0f91b0`。本次完善未对齐时间槽、控制词表及标注工程配套元数据；目标是兑现常用 EAF 标注编辑/整理/导出链路，不以更改功能名称替代实现。

| 缺口 | 实质修复 | 主入口及回归 |
| --- | --- | --- |
| TIME_VALUE 必填，合法未对齐时间被拒绝 | TimeSlot 可选值；未知边界按 TIME_ORDER 校验结构；时间查询不编造值 | parse/write/validate/retime/resample/extract_roots/corpus_records，compatibility_wbtest |
| CONTROLLED_VOCABULARY 被拒绝 | 内置多语言描述/条目；类型词表、标注条目及语言绑定；原子选择同步正文 | vocabulary_choices/set_controlled_value/parse/write，compatibility_wbtest |
| 常见配套元数据被拒绝 | 结构化保存 LANGUAGE/LOCALE/LICENSE、链接文件、词典/外部引用、SVG_REF 和引用链接，检查 ID 和引用 | extensions.mbt、parse/write、examples/compatibility |
| 编辑后元数据可能悬空 | 快照深复制；重命名更新对象归属和链接；删除/提取清理失去端点的链接及其依赖链接 | metadata_edit.mbt、edit/remove/extract 回归 |

## 独立预期与来源

沿用 `scripts/verify_interop.py` 固定到 ELAN 源码镜像提交 `4e9eb6e0e70e549471816ee30096138ce166a7c3` 的 EAF 2.8/3.0 XSD 和 SHA-256。schema 保存在忽略目录，仅作外部检查，不随包分发。TIME_VALUE 的 optional 声明、CV_ENTRY_ML/CVE_VALUE 的语言与值模型及标准元素/属性来自 schema，不从本项目读写器互相推导。

- 原 40 文档 / 880 标注：XSD + pympi 1.70.2 + 独立时间公式 + Python CSV/JSON。
- 新增 16 文档 / 64 标注：EAF 2.8/3.0 × 四种对齐状态 × 两种词表语言；检查空值边界、路径、选中值/CVE_REF/LANG_REF、媒体负偏移、词典和链接文件保留，以及 3.0 链接重命名。脚本为 `scripts/verify_compatibility.py`。
- 新增 1 份反向输入：由 pympi 1.70.2 公共接口生成原创合成词表语料，再用 Python ElementTree 独立省略 optional TIME_VALUE；`examples/foreign` 从导入、选择中文词条到重新写出，输出通过 3.0 XSD。没有复制 pympi 实现。
- 新增 8 个 MoonBit 回归，连同原有用例共 34 个；包含事务失败输入不变、快照元数据不共享、外部词表离线状态及删除/选择后的引用完整性。

隔离 0.1.0 源码执行两条新增最小输入，分别实际得到 Invalid（未对齐时间）和 Unsupported（多语言词表）；34 个当前测试及独立检查验证修复。原版失败日志保存在仓库外。没有组委会原始夹具，不能据此声称复现了其私有样本。

## 运行与边界

```sh
moon test --deny-warn
python scripts/verify_interop.py --target wasm-gc
python scripts/verify_compatibility.py --target wasm-gc
```

CI 使用固定 SDK `0.10.18+6c83a7f62` 对 wasm-gc/wasm/js/native 运行完整验证。具体远端结果以本版本实际 CI 运行记录和 Release 提交为准；本地原始日志、源指纹与发布消费者证据另存仓库外。

保留 EAF 2.8/3.0 主格式常见数据，不宣称任意扩展或任意工程兼容。未知语义仍报错，外部词表只保存引用而不联网抓取内容；未装入的外部词表不能作离线候选查询。Int32 时间边界、毫秒时间单位和资源预算见中文 README。`resolve`/`corpus_rows` 保留精确时间契约；`annotation_timing`/`corpus_records` 处理可缺失边界；JSON v2 导出 null，CSV 导出空字段。没有将未定时间解释为零或估算时间。
