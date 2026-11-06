# Repository agent guidance

本仓库使用 Godot 原生 `.tres` Resource、`data/content_manifest.tres` 与可编辑 `.tscn` 场景。**跨领域编辑真源和交付流程**统一按 [`docs/GODOT_NATIVE_AUTHORING_STANDARD.md`](docs/GODOT_NATIVE_AUTHORING_STANDARD.md)：Resource 管数据／规则、场景管表现／已迁移探索地图几何、`SpriteFrames.tres` 管新角色帧序；自研工具只做来源校验、转换、绑定和回退。美术制作仍使用 `art-production/standards/ART_PRODUCTION_STANDARD.md`；AI 生成时使用 `art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md`。

- 仅在美术相关任务中读取相应规范与 art-production/skills/ 下的 Skill；不要对无关代码任务强制加载全部美术文档。
- 仓库级 Skills 以 art-production/skills/ 为唯一维护目录；.agents/skills 是其相对软连接。不要在发现入口复制另一套 SKILL.md。
- 对角色、场景、VFX、UI 和素材审核/导入，优先调用同名 wuxia-* Skill，遵循其中的制作、原生交付、预览、人工审查流程。修改 Skill 只修改 `art-production/skills/`，不改发现入口的软连接。
- 素材管理状态仅 `candidate` 与 `in_use`：`concept/preview` 是制作用途，`approved` 仅为工作单中的视觉／权属验收结论，**不是第三种状态**。技术检查通过不等于人工批准，资源已在运行不代表已通过美术审核。
- 未完成目标素材的必要人工验收与明确批准，不得替换正式在用美术；旧资源引用和运行路径必须保留。离线工作单、库存索引不可代替运行时 Resource。**规范优先级**：已实现的运行时代码／原生 Resource／场景合同 → `docs/GODOT_NATIVE_AUTHORING_STANDARD.md` 跨领域编辑与绑定合同 → `art-production/standards/` 美术制作与 QA 合同 → 各 `wuxia-*` Skill 执行步骤 → `art-production/prompts/` 短提示词；源图制作像素与运行时世界像素分别遵循各自合同。
