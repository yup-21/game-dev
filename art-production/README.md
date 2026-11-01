# 《长风浮生录》美术生产工作区

本目录是全游戏美术制作的统一入口，供 AI 生成、人工修改、审核及批量生产使用，**不是 Godot 运行时自动扫描目录**。

| 目录 | 用途 |
| --- | --- |
| [standards/](standards/) | 美术、动画、场景与资源质量规范 |
| [prompts/](prompts/) | 可复制的 AI 生成母提示词与分类模板 |
| [templates/](templates/) | 生成时可参考的工作单 |
| [skills/](skills/) | 角色、场景、VFX、UI、审核导入的仓库级 Agent Skills；通过仓库根目录 `.agents/skills` 软连接自动发现 |
| [candidates/](candidates/) | 后续生成的概念图和候选版本；按批次、类型存放 |
| [reviews/](reviews/) | 已有审核、截图及反馈记录 |
| [inventory/](inventory/) | 仅使用中素材的引用与自动 SHA-256 |
| [in-use/](in-use/) | 已归档的原字节副本（含历史副本） |
| [tools/](tools/) | 离线库存工具与 Godot 导入导出指南 |

Skills 的 `SKILL.md` 遵循 Agent Skills 的 `name` / `description` YAML frontmatter 规范，详细工作规则由对应 Skill 在使用时按需加载；修改 Skill 只编辑本目录，不维护第二套副本。

## 素材管理：两种状态

- **candidate 候选**：`candidates/` 下可以保留任意数量的图片版本；只要求记录生成提示词和拟绑定的 Godot Resource 路径。
- **in_use 使用中**：以原生 `.tres` / Content Manifest 的实际绑定为准，**每个素材槽位只能有一个当前版本**。候选通过既有资源合同校验、能够正常导入和使用后即可切换绑定，无需额外美术返工或新增审批状态。
- `inventory/` **只记录当前使用中的图片及其资源引用**；SHA-256 由脚本自动计算，用于确认副本与回滚，不要求手工整理来源台账。过期副本或旧候选可暂时留在磁盘，但不计作使用中。
- 保留旧素材与回退功能，后续按资源槽位逐步清退；本次不修改已能使用的图像。
- **生成和游戏使用合同不变**：仍按现有角色动作、场景分层、VFX、UI 规范制作与校验。美术讨论、审核记录可以保留，但不是素材管理的第三种状态，也不妨碍满足合同的素材使用。

## 兼容说明

本目录保存独立副本以便美术团队直接浏览。旧正式文档 `docs/ART_PRODUCTION_STANDARD.md` 与 `docs/ART_STYLE_AI_PROMPTS_V1.md` 目前仍保留，避免打断已发布链接。后续版本应同步更新，不要静默让两份规范分叉。

## 第一批生产试点

沈长风（设定、立绘、九类动作）、追兵首领、雨夜断桥分层场景、核心 VFX、物品图标、武学卡面与 CTB/UI 分件。技术使用按原生合同校验；创作规格是否冻结仍按原有制作规范确定。

- [2026-11-01 四项优先试点工作单](candidates/2026-11-01/README.md)：包含剧情场景分层与准确的原生资源目标。
- [运行时代码与存量美术格式差异/验收状态](reviews/2026-11-01/FORMAT_UNIFICATION_STATUS.md)：记录格式接入状态与待人工复核事项。

## Godot 原生素材导入与导出

Godot 4.7.2 编辑器内的 **Art Production** Dock 提供引用图像导出、角色动画与场景分层导入、批次预检、版本化替换和事务回退。运行时仍只读取 `.tres` Resource，离线清单不充当内容定义。

参见 [Godot 导入/导出指南](tools/GODOT_IMPORTER.md)。候选符合原生合同即可接入对应 Resource；当前绑定即为使用中。历史文件先保留，后续按槽位逐步退出。
