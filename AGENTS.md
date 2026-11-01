# Repository agent guidance

本仓库的正式运行时内容以 Godot 原生 .tres Resource 和 Content Manifest 为准。美术素材工作使用 art-production/standards/ART_PRODUCTION_STANDARD.md；AI 生成时使用 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md。

- 仅在美术相关任务中读取相应规范与 art-production/skills/ 下的 Skill；不要对无关代码任务强制加载全部美术文档。
- 仓库级 Skills 以 art-production/skills/ 为唯一维护目录；.agents/skills 是其相对软连接。不要在发现入口复制另一套 SKILL.md。
- 对角色、场景、VFX、UI 和素材审核/导入，优先调用同名 wuxia-* Skill，遵循其中的制作、预览、人工审查流程。
- **素材管理只有两种状态**：`candidate`（同一槽位允许多个候选文件）与 `in_use`（以 Godot 原生 `.tres` 的实际绑定为准，每个槽位只有一个当前版本）。`approved` 等旧字段不属于素材管理状态。
- 素材符合现有原生 Resource 合同、能导入并运行，即可成为 `in_use`；不要因为审美差异自动阻断使用或要求重绘。生成方式与实际游戏使用规范继续按现有四类美术 Skill 和标准执行。
- 来源管理只要求**生成提示词和对应原生 Resource**，不强制建立第二套模型、seed、审批台账。技术 SHA 由工具自动校验。旧文件及必要回退暂时保留，之后另行分批退出；离线目录不可替代运行时 Resource。
