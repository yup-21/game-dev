# 武侠 HD-2D 视觉改造：断桥论剑

目标：参考现代像素武侠 RPG 的镜头、美术语言与操作层次，开发原创《长风浮生录》画面。任何商业游戏角色、贴图、界面图片或关卡均不复制。

## 本轮实现

- **地图**：在原15×10权威战场外添加程序化立体松林、石块、远山轮廓、断桥栏杆和暖色灯笼；不添加碰撞或更改移动规则。
- **光影与水面**：沿用 3D 斜俯视和水波 Shader，暖色灯光与冷绿环境色构成武侠暮色氛围。
- **角色**：改由 `hd2d_sprite_factory.gd` 生成两套原创、透明、严格按6列×4行排列的角色 atlas（青衣剑客/赤褐衣刀客），继续 nearest 采样，增加3D姓名牌与事件光照。
- **角色动画**：`hd2d_animation.gd` 从 `BattleModel` 的语义事件驱动待机、行走、攻击、护体、受击、闪避和连携状态；每个角色使用独立动画游标，结束后回到待机。
- **HUD**：原创青玉/墨色/宣纸/金色配色；顶部角色资源，右侧行动与响应状态，底部武学和卡牌用法面板。
- **战斗交互**：仍读取原 BattleModel 的合法动作，保留所有卡牌使用条件、目标选择、LIFO与动画票据，不把 UI 变成规则真值。

生成的角色帧行布局：

| 行 | 帧 | 用途 |
|---|---|---|
| 0 | 0–5 | Idle 循环 |
| 1 | 0–5 | Walk 循环 |
| 2 | 0–5 | Attack 连续动作 |
| 3 | 0/1/2–3/4–5 | Guard / Hit / Evade / Skill |

角色 PNG 不依赖外部版权素材，由 Godot 在运行时从像素图元生成。可以通过 `checks/export_hd2d_sprites.gd` 输出两张 PNG 到 Godot `user://` 供美术核对。生成器是开发阶段的原创占位资产，正式美术版应以相同 atlas 契约替换，而不必改规则或事件映射。

代码分层：
- `scripts/hd2d_scenery.gd`：视觉性地图装饰；
- `scripts/hd2d_sprite_factory.gd`：透明角色 atlas 生成；
- `scripts/hd2d_animation.gd`：语义事件动画状态控制；
- `scripts/hd2d_ui_theme.gd`：界面 StyleBox、颜色与按钮；
- `scripts/hd2d_battle.gd`：场景装配与现有模型事件适配。

## 运行与验收

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_startup.gd
godot --headless --path demos/changfeng-battle --script res://checks/export_hd2d_sprites.gd
godot --path demos/changfeng-battle res://battle_hd2d.tscn
```

需要人工核对：

1. 地形、河流、桥梁、角色和灯笼都可见，且场景没有 GDScript parse/runtime ERROR。
2. 底部卡牌按钮可展开当前合法用法；点击高亮目标发出合法请求。
3. 进入CLASH时右侧状态正确更新，敌方响应和Pass按权威模型推进。
4. 3D地形装饰不遮挡主角，也不改变15×10网格移动、射程和可达性。
5. 1600×1000与较小窗口下，HUD 不遮住关键可操作区域。
6. 原 `battle.tscn` 与 `opening.tscn` 均可正常运行。

## 仍需继续

- 当前角色已接入原创程序化 Sprite Sheet，但人体和服饰细节有限。正式版可替换为美术制作的高精度多方向 Sprite Sheet；需先按帧格和透明边界验收。
- 树与远景目前是程序化 low-poly 占位，后续可换成统一像素画材质和手工布局的 3D 场景。
- 现有HUD是功能性风格化控件，后续可将手牌、响应栈做成动画式独立 Control 场景。
- Forward+ 的 DOF/Glow/体积雾需要性能验收，不能直接破坏现有 Compatibility 模式。
- 尚未在当前执行环境中运行 Godot（未找到二进制）；所有场景测试均等待真实引擎执行。
