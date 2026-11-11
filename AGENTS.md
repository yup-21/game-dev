# Repository agent guidance

本仓库使用 Godot 原生 `.tres` Resource、`data/content_manifest.tres` 与可编辑 `.tscn` 场景。**跨领域编辑真源和交付流程**统一按 [`docs/GODOT_NATIVE_AUTHORING_STANDARD.md`](docs/GODOT_NATIVE_AUTHORING_STANDARD.md)：Resource 管数据／规则、场景管表现／已迁移探索地图几何、`SpriteFrames.tres` 管新角色帧序；自研工具只做来源校验、转换、绑定和回退。美术制作仍使用 `art-production/standards/ART_PRODUCTION_STANDARD.md`；AI 生成时使用 `art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md`。

## AI 实现与验收边界

- 先完成用户当前明确要求的操作；不自行附加审批、格式限制、重复验收或历史数据清理。既有制作规格用于指导成品，不作为 V3 加载、修帧、单动作导入或预览的前置条件。
- 只在文件无法读取、必要结构无法生成、引用无效或操作会造成实际数据损坏时阻断；可见尺寸、透明边距、缺少非当前动作、姿态与风格问题应提示并允许继续编辑、导入和预览。
- 导入工具自动建立本次操作需要的 Resource 与目录，修改当前选中的动作时保留其他动作。仅对准确的替换目标提供一次操作确认，用户随后通过真实 Godot 预览验收视觉效果。
- 已确认的规范与用户修改过的其他资源继续受保护；不静默兼容错误数据、不偷偷替换缺失动作、不无提示覆盖无关资源。说明确实存在的能力边界即可，避免在每步重复免责和风险文字。

- 仅在美术相关任务中读取相应规范与 art-production/skills/ 下的 Skill；不要对无关代码任务强制加载全部美术文档。
- 仓库级 Skills 以 art-production/skills/ 为唯一维护目录；.agents/skills 是其相对软连接。不要在发现入口复制另一套 SKILL.md。
- 对角色、场景、VFX、UI 和素材审核/导入，优先调用同名 wuxia-* Skill，遵循其中的制作、原生交付、预览、人工审查流程。修改 Skill 只修改 `art-production/skills/`，不改发现入口的软连接。
- 素材管理状态仅 `candidate` 与 `in_use`：`concept/preview` 是制作用途，`approved` 仅为工作单中的视觉／权属验收结论，**不是第三种状态**。技术检查通过不等于人工批准，资源已在运行不代表已通过美术审核。
- 未经用户授权不得替换其他正式素材；对用户明确选择并确认的当前目标，允许执行导入和绑定，视觉验收可在操作后完成。其他在用资源保持原样。离线工作单、库存索引不可代替运行时 Resource。**规范优先级**：已实现的运行时代码／原生 Resource／场景合同 → `docs/GODOT_NATIVE_AUTHORING_STANDARD.md` 跨领域编辑与绑定合同 → `art-production/standards/` 美术制作与 QA 合同 → 各 `wuxia-*` Skill 执行步骤 → `art-production/prompts/` 短提示词；源图制作像素与运行时世界像素分别遵循各自合同。
