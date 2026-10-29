# HD-2D 战斗场景：第一阶段垂直切片

## 范围

这是一个**独立实验场景**，不会替换默认的 `opening.tscn` 或原 `battle.tscn`。

入口：`res://battle_hd2d.tscn`。

现有 `BattleModel` / `CombatRules` / `EnemyAI` 仍然是唯一战斗规则来源，3D 场景只负责显示状态、接受输入和消费动作结果。15×10 格的逻辑坐标映射为水平 X/Z 世界坐标，地形类型来自 `snapshot.terrain`。

### 已实现

- Camera3D 正交斜俯视镜头、环境雾、定向光与阴影。
- 由既有地形字典生成地面、河流、桥面木板和基础障碍表现。
- 读取已提交的 Kenney CC0 PNG，用 Sprite3D billboard 表现双方人物。
- 用 Camera3D ray 投影到地面，根据现有合法动作列表高亮/点击移动。
- Q 普攻、G 格挡、Space/Enter 结束行动或 Pass、R 同种子重开、Esc 返回菜单。
- 底部列表自动枚举当前合法的卡牌用法和武学续式；选中后点击合法目标格或角色。连锁截势显示可选 link_id；右键取消选择。
- 使用 ATTACK_DECLARED、DAMAGE、SHIELD、MOVE 等语义事件触发角色附近的短时光照反馈。
- 复用 `model.submit()`、`model.snapshot()`、`model.legal_actions()` 和 `EnemyAI.choose_action()`；提交后等待短动画时隙，再用 ticket 确认事件。
- 顶部显示双方气血、内息、阶段与逻辑 tick。

### 尚未实现

- 真正的高精度美术模型与动画（目前只是程序化几何和原有 16px 精灵）。
- 完整的美术化卡牌、牌区管理、响应栈可视化、招式说明和多层技能动画。当前仅提供合法动作按钮与目标交互，**不是最终战斗 UI**。
- 地形高度、遮挡/透明排序调优、动作特效、相机变焦、真实水 Shader 和后期景深。
- 多人战斗场景支持、世界探索、资源缓存与性能优化。
- Forward+ 切换：原项目 Compatibility 仍保持默认，以免影响已有场景。开启 DOF/Volumetric Fog 需另行切换 Forward+ 并验证。

## 运行

使用仓库现有的 Godot 4.x 引擎，先导入资源，再运行：

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --path demos/changfeng-battle res://battle_hd2d.tscn
```

## 第一阶段验收

1. 原默认 `opening.tscn`、旧 `battle.tscn` 可正常启动，旧 UI 回归检查不退化。
2. HD-2D 场景地面、桥与河流匹配当前规则地形，人物初始格与 `BattleModel` 一致。
3. 鼠标只高亮合法 MOVE；点击非法或水域格不会向模型提交移动。
4. Q、G、Space、R 等动作经相同的版本化请求验证；AI 只通过当前模型合法动作决策。
5. 能在自由 ACTION 中选择卡牌用法并点目标；CLASH 可以选择合法响应或 Pass，链接目标必须来自合法列表。
6. 角色响应语义事件产生短时光照，动画未确认时不再受理新操作。
7. 测试输入时，动画期间不能重复提交请求；ticket 被确认后才进入下一次决策。
8. 通过 Godot 编辑器导入与场景运行，不出现 parser/runtime ERROR。
9. 按原 `checks/verify.ps1` 的 Rules、Edges、SchoolPlaythrough 和 UI 项目做回归。

目前 GitHub 写入环境没有 Godot 可执行程序，**尚未完成第 1–9 项实机验证**。合并前需由有图形环境的开发者运行并附截图。

## 后续推荐顺序

1. 抽出独立 `GridProjection`，统一世界投影、raycast 和高差。
2. 抽出 `BattlePresenter`，让事件动画队列完全消费 `result.events`，保证移动、受击、交锋动画与 acknowledge 对齐。
3. 按原 `battle_view.gd` 的输入功能补齐卡牌、用法、响应层选择；UI 用 CanvasLayer/Control 组件重建。
4. 新增正式角色 Sprite Sheet、桥梁与树林美术资源，记录 SPDX/许可证来源。
5. 独立性能基准后再试 Forward+、Glow、DOF、Volumetric Fog 等后处理。
