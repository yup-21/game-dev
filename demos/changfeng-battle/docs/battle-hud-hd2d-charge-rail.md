# HD-2D 战斗 UI：纵向集气跑轴与轻量化布局

## 原则

唯一玩家入口仍为 `battle_hd2d.tscn`。本次只改呈现层：
`BattleModel`、`TurnManager`、CLASH 响应、卡牌合法性、连携和六人序章保持原样。

- 中央：维持斜俯视正交 3D 场景、现有 2D 角色动作精灵和雨夜插画。
- 左侧：约 214px 宽的己方头像、气血／真气细条；敌人信息由场上血条及右侧集气头像承担。
- 顶部：约 61px 的章节与简洁阶段提示，移除重复 CTB 文案。
- 右侧：约 108px 的**真实纵向集气跑轴**，下方「集气」、上方「出手」。
- 底部：缩小到 148×186 的武学卡面，保留各 usage 的原生可点击 Button、插画和完整 tooltip，横向溢出时仍可滚动。
- 交锋：仅在有合法操作或 CLASH 时出现，浮动命令区在跑轴左侧，不能取代跑轴。

## 集气数据绑定

`hd2d_ctb_rail.gd` 消费 `BattleModel.snapshot(observer_id).actors`。
纵轴满值引用 `TurnManager.CHARGE = 10000` 的现有数值；位置按
`clamp(gauge / 10000, 0, 1)` 插值，头像颜色按 `team_id` 区分，
`_decision_owner()` 用于高亮当前响应权。实际数值可能超过阈值，只有
UI 投影被截断，**不改变 gauge、tick 或行动顺序**。

角色集气很接近时，头像会小幅错位以防遮挡；轴心圆点仍停在真实进度位置，
细引线对应头像。死亡角色不占可见进度位。悬停显示角色名及准确集气值。

## 验证

在 Godot 4.7.2 导入资源后运行：

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_ctb_rail.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_unified_hud.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
```

还应检查 GitHub Actions 上传的实际战斗截图（1600×1000），以及
1440×900 / 1920×1080 下跑轴、弹出命令和底部五张牌的互不遮挡。
本 PR 使用仓库既有的可用素材，不把概念效果图假装为可运行的独立资源。
