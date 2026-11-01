# R32 · 动作时间轴改用强类型 Godot Resource

## 生产路径

`data/content_manifest.tres.action_timelines` 注册唯一默认 `WuxiaActionTimelineDefinition`。
其 9 个 `WuxiaActionClipDefinition`、13 个 `WuxiaActionEventBinding`，以及可选 `WuxiaActionTimeWindow` 和 `WuxiaActionCueDefinition` 都是 Inspector 可编辑的 Godot Resource 子资源。

`BattleActionTimeline` 现在从 `ContentRegistry.resource_for("action_timeline", "...")` 获得原生对象，用类型化字段检查时间相位、视效窗口和 cue。生产代码不再解析 `data/action_timelines.json` 或旧 `r25_action_timelines` 的 Dictionary Schema。默认 JSON 继续留在 `data/`，仅由迁移测试当作数据校准基准；旧封装 `data/native/documents/action_timelines.tres` 已删除。

`HD2DAnimation` 的语义事件队列和 R30 `AnimationPlayer` clip 共享这些时间；`BattleModel` 仍是唯一伤害、合法行动和状态权威。时间轴中的 `invulnerable` 字样**只表示可查询的视觉窗口**，不能给予规则层的无敌帧。

## 新建或调整动作

1. 在 Godot Inspector 打开 `data/native/action_timelines/r32_default.tres`。
2. 在 `clips` 中编辑/添加 `WuxiaActionClipDefinition`，填写唯一 `clip_id`、总时长、startup、active、recovery。三段时长合计必须等于总时长。
3. 可选地为 cancel/reaction/invulnerable 指定 `WuxiaActionTimeWindow`，为视觉 cue 指定 `WuxiaActionCueDefinition`。
4. 在 `event_bindings` 映射动作事件名到合法 clip ID。正式内容必须覆盖已有九种动作 ID；重复 ID 或无目标事件映射会被拒绝。
5. 运行 `checks/test_r32_native_action_timeline.gd` 与 `checks/test_battle_action_timeline.gd`。前者逐字段核对原版 9 clip / 13 event 语义并验证错误资源，后者核验实景演出时序不会写入战斗规则。

## 迁移边界

R32 迁移七份遗留 `WuxiaDataDocument` 中的 **动作时间轴**，剩下六份：`school_forms`、`tingfeng_cards`、`legacy_id_map`、`techniques`、`demo_scenario`、`rainy_bridge`。

`BattleActionTimeline.clip(id)` 暂保留一个只读 Dictionary 快照作为公开接口过渡，其正式加载、验证和计算完全基于类型化 Resource。对旧技能 ID 与剩余六种复杂 Schema 的删除，必须先找到并替换各自的正式消费者与回归基线。
