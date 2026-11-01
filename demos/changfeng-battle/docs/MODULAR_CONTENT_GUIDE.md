# 模块化内容制作 · 当前入口

**正式制作唯一依据**：[Godot 原生 Resource 内容指南](../../../docs/changfeng-native-authoring.md)。

当前内容体系为 `WuxiaContentManifest` → 领域 Catalog → 独立运行态 → `BattleModel`。添加角色、武学、Buff、装备、消耗品和章节时，使用 Inspector 或复制已有 `.tres`，将资源注册到 `res://data/content_manifest.tres`；不修改 `BattleModel`、`CombatResolver` 或 UI 中的规则分支。

| 内容领域 | 原生定义 | Manifest 数组 | 运行时 |
| --- | --- | --- | --- |
| 角色 | `WuxiaCharacterDefinition` | `characters` | `CharacterRegistry` → `CharacterFactory` |
| 武学/招式 | `WuxiaSchoolDefinition` + `WuxiaSkillDefinition` | `schools` + `skills` | `SchoolCatalog` / `CardSystem` |
| 技法 | `WuxiaTechniqueDefinition` | `techniques` | `TechniqueRuntime` |
| Buff / Debuff | `WuxiaBuffDefinition` | `buffs` | `StatusCatalog` / `StatusSystem` |
| 装备 / 消耗品 | `WuxiaItemDefinition` | `items` | `ItemCatalog` / `InventoryRuntime` |
| 装备词条 | `WuxiaAffixDefinition` | `affixes` | `EquipmentAffixCatalog` |
| 剧情/章节/遭遇 | `WuxiaStoryDefinition` / `WuxiaChapterDefinition` / `WuxiaEncounterDefinition` | `stories` / `chapters` / `encounters` | `OpeningStory` / `ChapterCatalog` / `ScenarioDirector` |

新增内容必须通过目录校验及实际玩法回归，不得在失败的 Catalog 中使用部分配置。`battle_actor_id=-1` 的角色可以通过遭遇配置分配独立 actor ID；`GRID` / `FREE`、CTB、连携和结算逻辑不因增加内容而改变。

章节条件、奖励和跨战斗角色运行态请参阅 [章节指南](CHAPTER_AUTHORING_GUIDE.md)。该文档不再维护另一套内容格式或独立注册步骤。
