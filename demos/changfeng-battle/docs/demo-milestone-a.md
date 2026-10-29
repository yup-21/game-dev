# Demo A：剧情 → 多人战斗 → 结算闭环

本 PR 整合《长风浮生录》第一幕开场、已有 3v3 战斗和短篇结算；**不复制 BattleModel 或 EnemyAI**。

- `GameSession`（Autoload）：负责阶段 `menu/story/battle/aftermath/complete`，保存对白选择、剧情旗标和残篇物品，跨场景保持。
- `ScenarioDirector` + `data/demo_scenario.json`：通过配置决定追兵遭遇的阵容/阵营/控制权/流派，复用现有 2–8 人战斗框架。
- 开场剧情的 `obtain_fragment` 事件写入会话；不同对白选择保留为 `helped_escort` 旗标。
- 完成故事后不再直接跳独立双人练习，而是开始追兵 3v3 战斗。主菜单的双人／多人入口仍保留为**沙盒试玩**。
- 剧情战斗结束后出现前往结算按钮（Enter），进入 `demo_result.tscn`；能回菜单、重试战斗或结束序章。
- 原双人场景和多人沙盒不会修改剧情会话。每次新游戏重置会话，战斗重试不丢失剧情进度。

## 验证
```bash
godot --headless --path demos/changfeng-battle --script res://checks/test_demo_flow.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_opening_story.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_parties.gd
godot --path demos/changfeng-battle --script res://checks/demo_result_visual_check.gd
```

已使用本地 Windows Godot 4.7.2 完成剧情会话、遭遇配置、队伍规则与结算状态的定向检查，并通过序章和结算页窗口截图检查。Godlink MCP 实测了序章输入、菜单进入单挑及 3v3、两名手动角色切换、AI 行动和重开。剧情结果目前暂不修改数值；修炼和暗伤代价将在 Demo B 实现。
