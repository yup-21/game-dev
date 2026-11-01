# Repository agent guidance

本仓库的正式运行时内容以 Godot 原生 .tres Resource 和 Content Manifest 为准。美术素材工作使用 art-production/standards/ART_PRODUCTION_STANDARD.md；AI 生成时使用 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md。

- 仅在美术相关任务中读取相应规范与 art-production/skills/ 下的 Skill；不要对无关代码任务强制加载全部美术文档。
- 仓库级 Skills 以 art-production/skills/ 为唯一维护目录；.agents/skills 是其相对软连接。不要在发现入口复制另一套 SKILL.md。
- 对角色、场景、VFX、UI 和素材审核/导入，优先调用同名 wuxia-* Skill，遵循其中的制作、预览、人工审查流程。
- concept/preview、candidate、approved 与 runtime/in_use 语义不同；技术检查通过不等于人工批准，现有运行使用不代表通过美术审核。
- 未获人工批准不要覆盖正式美术；旧资源引用和运行路径必须保留。离线工作单、库存索引不可代替运行时 Resource。
