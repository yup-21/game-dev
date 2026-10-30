# 插画式 HD-2D：唯一正式战斗入口

原本文档描述了旧版 2D 多人剧情战斗与独立 HD-2D 预览同时开放的阶段性架构。此结构**已弃用**。

## 当前玩家路径

| 玩家入口 | 场景 | 规则 |
| --- | --- | --- |
| 主菜单 → 初入江湖 → 雨夜追兵 | `opening.tscn` → `battle_hd2d.tscn` | 剧情会话配置，多人队伍（含玩家与 AI）、CTB、武学卡牌、交锋与连携 |
| 主菜单 → 进入战斗 · HD-2D | `battle_hd2d.tscn` | 独立演示，可直接查看插画角色、雪山背景与战场 UI |
| 战斗结算 → 重新挑战 | `battle_hd2d.tscn` | 从 GameSession 复用剧情遭遇 seed 与规则 |

`battle.tscn` 与 `party_battle.tscn` 仍在仓库中供历史脚本和回归测试使用，但不再有任何玩家菜单入口。不要在序章、结算或新菜单中重新引入它们。

## 视觉素材实际使用

- 战斗运行时：`hd2d_art_catalog.gd` 将已提交角色图集赋予 `Actor_*/Sprite3D`，目前 ID 2–5 使用 24 姿态 PNG；ID 0–1 暂用原有插画图集回退。
- 故事头像：`ArtCatalog.portrait` 使用沈长风、镖头、顾清霜立绘。
- 预览战场：`hd2d_scenery.gd` 接入雪山剑派远景，桥、松林、灯笼和河水由 3D 元素与 Shader 组成。
- 剧情追兵：同一场景运行多人遭遇，采用雨夜布景而非雪山远景。
- 战斗 UI：`hd2d_card_ui.gd` 和 `hd2d_ui_theme.gd` 为唯一卡牌 UI，保留已提交的统一无框水墨 HUD。

## 回归

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_single_battle_entry.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_art_integration.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
```
