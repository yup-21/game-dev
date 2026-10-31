# R41 · 历史兼容代码已经移除

这份文档仅保留迁移决策，不再定义受支持的旧文件接口。

R29–R40 逐步将历史战斗场景、独立 waypoint 寻路器、泛型 WuxiaDataDocument、旧内容 JSON 和旧 ID 导入映射隔离。**R41 已进一步删除源仓库内旧内容 JSON、旧武学 ID 对照表及其适配器、各生产 catalog 的 JSON 分支**。不再支持通过自定义 JSON 索引创建角色、物品、武学或剧情。

正式玩家场景仍然只有 `opening.tscn`、`battle_hd2d.tscn` 和 `demo_result.tscn`。规则回归保留 `BattleModel`、`BattleSpatialService`、CTB、连携与两种移动模式；内容校验改为 `WuxiaContentManifest` + 类型化 Resource。旧数据仅存在于 Git 历史，不需要继续存储在源工程中。

注意：`assets/production_manifest.json` 属于离线的美术来源/授权审计清单，既不是游戏数据，也不会包含在发布包。存档/运行时记录可以序列化为数据结构，但不能反过来将其当成配置文件加载器。

详见 [R41 技术收口](R41_NATIVE_ONLY_CLOSURE.md)。
