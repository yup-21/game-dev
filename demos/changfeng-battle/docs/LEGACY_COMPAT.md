# 正式入口与兼容边界（R29）

玩家场景只有 `opening.tscn`、`battle_hd2d.tscn` 和结算 `demo_result.tscn`。旧 `battle.tscn`、`party_battle.tscn` 及其专用 View 已迁移测试后删除，不存在第二套战斗表现。

规则回归测试直接针对 `BattleModel`、命令分发和 GRID/FREE 空间服务；UI 回归测试针对唯一正式场景。保存的是玩法行为，而不是旧场景文件。

旧 ID 适配器和少量旧数据 Schema 仍有真实规则消费者；历史 JSON 只用于主动传入的兼容/非法配置测试。新游戏没有承诺过未发布旧存档格式。

缺失美术使用 `assets/fallback/` 独立占位素材；不拿旧人物/旧场景原画替代。详见 [R29 说明](R29_NATIVE_CLEANUP.md)。

R32：动作时间轴已迁入强类型 `WuxiaActionTimelineDefinition`，生产中不再读取旧 `r25_action_timelines`；余六份复杂数据容器仍在迁移清单中。详见 [R32 时间轴迁移](R32_TYPED_ACTION_TIMELINE.md)。

R39：剩余六份通用内容文档已迁入对应类型化 Resource，生产 Manifest 不再注册 `document`，`WuxiaDataDocument` 与原目录均已移除；旧技能 ID 仅通过 `WuxiaLegacyMappingDefinition` 为显式导入提供适配。历史 JSON 为测试用值对照，不承担生产加载。
