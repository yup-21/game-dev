# 统一版 · 无框水墨战斗 HUD

以 **场景第一，卡牌第二，操作按需浮现** 为唯一视觉方向。替换此前的三大框（顶部章节面板、左侧阵容面板、右侧交锋面板）和底部实心托盘。底部卡牌保留真实可点击 `Button`，其余区域通过透明幕影与文字层次融入战场。

## 唯一运行时实现
- `scripts/hd2d_battle.gd`：所有 HUD 组合、状态绑定、合法指令分发。统一 `CanvasLayer/WuxiaCombatHUD/UnifiedHUD`。
- `scripts/hd2d_card_ui.gd`：唯一卡牌绘制组件，独立插画 + 招式名 + usage 名 + 气血消耗。
- `scripts/hd2d_ui_theme.gd`：统一墨青/古金/青玉色板、无框指令按钮、角色状态条、卡牌选中态。
- `scripts/hd2d_card_art.gd`：只提供素材映射与可选高清 PNG，不提供第二套卡牌视图。
- `assets/ui/veil_*.svg`：原创透明渐隐背景，消除硬边框，鼠标事件全部忽略。

## 版式
1. **ChapterRibbon**：顶部窄丝绢、章节、tick/行动者、输入提示（常驻）。
2. **FloatingRoster**：左侧头像与三条紧凑信息（HP、Qi、CTB 文本）；所有角色对应真实 model snapshot。
3. **ContextActions**：右侧漂浮式合法命令；交锋期间才显示响应层说明与加强幕影，不能替代 BattleModel 判定。
4. **HandStage**：底部可水平滚动的原画卡牌，悬停微放大、选中微抬升、使用法独立的点击选择。
5. **Battlefield**：中景无 GUI 硬遮罩，模型目标格与 Sprite3D 保持可点击。

## 规则边界与迁移
不修改 `BattleModel`、CTB、3v3、卡牌费用、连携、LIFO 响应、动画 ticket、AI 或剧情事件。`_submit_legal` 仍二次向 `model.legal_actions()` 校验。没有引入另一套 HUD 可切换入口。保留旧卡牌 PNG 图集，同时兼容 PR #32 的可选原画 PNG 素材。

## 验收
```bash
godot --headless --editor --path demos/changfeng-battle --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_unified_hud.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_ui_assets.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
```
实际 1600×1000 / 1440×900 仍应检查交锋指令的显隐、滚动边界、鼠标命中及长武学名称的截断。