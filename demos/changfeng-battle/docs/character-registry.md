# 统一角色卡 · CharacterRegistry

新角色以 `WuxiaCharacterDefinition` 原生 `.tres` 创建并加入 `data/content_manifest.tres.characters`。完整步骤参阅 [唯一内容制作指南](../../../docs/changfeng-native-authoring.md)。

## 唯一身份与角色定义

`content_id` 是跨剧情、队伍、装备、美术的稳定角色身份；`battle_actor_id` 是可选预留索引，不是角色身份。新角色可使用 `-1`，由每次 Encounter 指定 actor ID。角色姓名、门派、`learned_schools`、`attributes`、`passives`、`techniques`、人物背景和初始道具保存在同一张原生角色卡。

`CharacterRegistry` 校验唯一 ID/姓名、属性范围、门派引用、初始装备与美术资源路径，然后向 `CharacterFactory` 提供防篡改数据副本。`ScenarioDirector` 通过 `WuxiaEncounterCombatantDefinition.character_id` 连接角色和战斗站位、阵营、控制权，无需额外角色索引。

## 运行时与表现

`CharacterRuntime` 管理持久成长、背包与装备；`BattleModel` 管理 HP、Qi、CTB、Buff、卡区与技能阶段。`CharacterCardUI` 只读角色快照，不得改变战斗规则。

`WuxiaCharacterDefinition.portrait` / `sprite_sheet` 是 Godot 的 `Texture2D` 引用，`CharacterFactory` 与 `HD2DArtCatalog` 负责解析，必要时使用独立的 fallback 图。动作图集约定 6 列 × 4 行。图集能在 Editor 加载并不代表已经完成全部连贯逐帧动作或获得商用授权。

更改原生角色卡后，运行 `checks/test_character_factory.gd`、`checks/test_character_dynamic_identity.gd`、`checks/test_chapter_pipeline.gd`，并手工确认场景中的身份、立绘和脚点。
