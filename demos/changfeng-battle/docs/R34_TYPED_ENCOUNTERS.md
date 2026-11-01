# R34 · 原生章节遭遇名单

> 本页为历史迁移记录；新内容制作统一参阅 [原生 Resource 指南](../../../docs/changfeng-native-authoring.md)。


默认 `escort_ambush`、`river_watch_ambush` 由两份 `WuxiaEncounterDefinition` 注册到 Manifest，而不再是 `demo_scenario` 通用字典。每名角色独立 `WuxiaEncounterCombatantDefinition`：含角色 ID、队伍、控制者与起始格坐标。保留相同 seed、title、map_id 与 6 人参战顺序。

`ScenarioDirector` 从 `ContentRegistry.entries("encounter")` 获取原生遭遇记录并严格校验，通过 `CharacterRegistry.battle_options()` 交给唯一的 `BattleModel`。旧 JSON fixture 及解析入口已删除；非法遭遇由原生 Resource 或内存定义验证，不建立第二套 AI 或规则引擎。
