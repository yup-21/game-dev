# R34 · 原生章节遭遇名单

默认 `escort_ambush`、`river_watch_ambush` 由两份 `WuxiaEncounterDefinition` 注册到 Manifest，而不再是 `demo_scenario` 通用字典。每名角色独立 `WuxiaEncounterCombatantDefinition`：含角色 ID、队伍、控制者与起始格坐标。保留相同 seed、title、map_id 与 6 人参战顺序。

`ScenarioDirector` 仍可显式传入 JSON fixture 验证非法遭遇记录；正式默认加载仅从 `ContentRegistry.entries("encounter")` 获取，之后交给既有 `CharacterRegistry.battle_options` 和 `BattleModel`。不得建立第二套 AI 或战斗规则引擎。
