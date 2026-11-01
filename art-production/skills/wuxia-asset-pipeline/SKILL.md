---
name: wuxia-asset-pipeline
description: "在《长风浮生录》中管理候选和使用中美术、查看原生 Resource 绑定、检查合同、导入导出和更新当前使用清单时使用；不改变角色、场景、VFX、UI 的生成规范。"
---

# 素材管理与原生接入

## 管理口径

- **只有两种管理状态**：`candidate` 与 `in_use`。一个槽位可有多个候选；每个原生 Resource 属性在任一时刻只能引用一个使用中版本。以 Godot `.tres` 绑定为准，不另建运行时 JSON 或审批数据库。
- 候选来源只需要**生成提示词和拟绑定的 Resource 路径**。可以继续保留已有工作单和历史文件，但不要要求新素材重复填报模型、seed、审批、来源链等管理字段。SHA 由工具自动计算。
- 本 Skill 只负责**管理与合同校验**。角色九动作、Atlas 格数、场景分层、VFX 事件与 UI 可读性的制作/使用规则，仍由 `art-production/standards/ART_PRODUCTION_STANDARD.md` 和对应专业 Skill 规定；不要为了管理精简而改动这些合同。
- 素材满足原生合同且能正常导入使用即可切换为 `in_use`，不额外要求重绘或设置 `approved` 第三种管理状态；创作反馈可留在旧审核记录中。

## 操作流程

1. 读取现有 Resource：角色使用 `WuxiaCharacterDefinition` / `WuxiaActorAnimationProfile`，地图与章节使用 `WuxiaSceneArtProfile`，VFX/UI 使用 `WuxiaAssetDefinition`。检查目标槽位已有的唯一使用中绑定。
2. 将备选素材存入 `art-production/candidates/YYYY-MM-DD/<asset-id>/`，保存提示词和目标 Resource；候选版本数量不限且不覆盖其他版本。
3. 在 Godot **Art Production** Dock 检查实际合同：可解码、必要 Alpha、Atlas 行列/动作索引、场景同画布、VFX 事件等。通过后按正常事务导入并更新对应 `.tres`，原 Resource 仍是唯一事实来源。
4. 运行相关 Godot 检查与导出，必要时使用事务回退。旧文件和回退机制先保留，后续单独按槽位逐步移除。
5. 运行 `python3 art-production/tools/inventory_assets.py --write`，只记录**当前使用中的图像及其实际 Resource/脚本引用**；使用 `--check` 核对副本，不登记候选、未引用或纯测试素材。

## 完成标准

- 每个目标 Resource 槽位只有一个当前绑定，候选可任意多份。
- 能按现有合同加载、显示和导出，相关原生测试通过。
- 仅留提示词、Resource 对应关系和自动生成的使用中清单；不因已有图片可用而做额外美术修改。
