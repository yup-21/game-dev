# 战斗 Demo 入口状态（2026-10-30）

| 场景 | 状态 | 当前用途 |
| --- | --- | --- |
| `opening.tscn` | 保留（启动/剧情） | 唯一公开主菜单；序章与游戏流程 |
| `battle_hd2d.tscn` | **唯一正式战斗场景** | 手绘战场 + Sprite2D 角色、统一 HUD、独立双人演示、序章多人遭遇、战后重试（已迁为 Node2D + Camera2D） |
| `battle.tscn` | **DEPRECATED** | 旧双人 2D 引擎显示测试；不再暴露玩家入口 |
| `party_battle.tscn` | **DEPRECATED** | 旧多人 2D 模型/界面测试；不再暴露玩家入口 |
| `demo_result.tscn` | 保留（剧情结算） | 剧情战斗结束后展示结算；「重新挑战」回到 HD-2D |

## 路由约束

- 主菜单按钮仅有 `start`、`hd2d`、`quit`。按「初入江湖」体验完整剧情，快速进入战斗则直接加载 `battle_hd2d.tscn`。
- 序章完成后仅显示「迎战追兵」和「返回主菜单」；遇敌由 `GameSession.begin_encounter()` 读取配置并进入同一 HD-2D 场景。
- 结算页的「重新挑战」必须经 `GameSession.retry_encounter()` 并加载 `battle_hd2d.tscn`，绝不能掉回旧多人战斗。
- 保留旧 `.tscn`、旧视图脚本与其独立回归，方便核对 CTB/卡牌规则及后续迁移，不主动删除资源或引擎代码。
- 正式战斗逻辑唯一由 `BattleModel` 管理，HUD 不实现第二份状态真值。

## 运行时渲染与重构边界

正式战斗 `battle_hd2d.tscn` 已为 `Node2D + Camera2D`，地形与演员均来自 `illustrated_battle_map.gd` 的 `Sprite2D` 与 CanvasLayer，剑光使用 `battle_vfx_2d.gd`。旧 3D 模块暂作历史代码保留，正式路径不再加载。脚点、目标落点、特效、朝向及 3v3 已加入新回归。参考 [技术架构](ARCHITECTURE.md) 与 [重构路线图](REFACTOR_ROADMAP.md)。

## 美术覆盖现状与缺口

使用的图集：`assets/concepts/2026-10-30/characters/*_24_pose.png` 映射至 ID 2–5 的 6×4 角色动作。主角（ID 0）及追兵首领（ID 1）仍走已有插画动态图集回退；完整原创24姿态尚未齐全。正式独立战斗及剧情追兵均使用 `data/maps/rainy_bridge.json` 对应完整断桥战场；雪山图属于保留的概念设计稿，不是当前战术底图。未来继续统一这两套**角色素材品质**时应替换美术文件而不是新增另一套战斗 Demo。
