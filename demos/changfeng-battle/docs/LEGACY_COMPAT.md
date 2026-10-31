# 历史场景与兼容边界（仅保留有消费者的内容）

## 正式/历史入口边界

| 文件 | 用途 | 是否玩家入口 |
| --- | --- | --- |
| `opening.tscn` | 序章及主菜单 | 是 |
| `battle_hd2d.tscn` | 唯一正式 Node2D 战斗，1v1 与 3v3 | 是 |
| `battle.tscn` + `battle_view.gd` | 原双人 2D 引擎/UI 回归 | 否 |
| `party_battle.tscn` + `party_battle_view.gd` | 原多人 2D 引擎/UI 回归 | 否 |

历史场景仍有回归测试通过 `load("res://battle.tscn")`、`load("res://party_battle.tscn")` 直接加载，故保留这两个场景及其脚本；玩家菜单与剧情不再进入它们。

R28 静态审计确认 `hd2d_party_bridge.gd`、`hd2d_scenery.gd`、`hd2d_vfx.gd` 在生产场景、原生资源、测试脚本和启动脚本中均无消费者，已删除。它们不属于历史场景的必需依赖。

## 后续删除门槛

1. `rg` 搜索所有 `preload/load`、`.tscn`、脚本与检查用例引用，列出真实消费者。
2. 用等价正式场景测试替换依赖，核对失败场景的可复现证据。
3. 移动资源单独提交，Godot 导入和完整 CI 均通过。
4. 不得删除玩家提交的原创图片、姿态稿与概念原画。

**保留对象必须有可指认的消费者或兼容合同；不再把“历史代码”本身作为无限期保留理由。**
