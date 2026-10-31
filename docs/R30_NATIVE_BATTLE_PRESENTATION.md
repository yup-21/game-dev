# R30 · Godot 原生战斗角色演出

## 完成范围

- **唯一规则内核不变**：`BattleModel` 继续决定合法行动、伤害、状态、移动提交与版本号；`BattlePresentationCoordinator` 管理演出请求的一次性确认。
- **原生图集播放**：每个战斗 `ActionSprite: Sprite2D` 下增加 `NativeSpriteAnimation: AnimationPlayer`；使用 `AnimationLibrary` 和 `Animation` 资源的离散帧轨、连续缩放/旋转轨，替代 `hd2d_animation.gd` 中每帧手写的 frame/sin/lerp 更新。
- **时序隔离**：`HD2DAnimation` 仍消费 `BattleActionTimeline` 中的语义事件、阶段和视觉 cue。播放器采用 `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`，由演出 tick 推进；不会因引擎自动播放改变规则时机。
- **美术来源不变**：沿用 `ArtCatalog` 的正式原创图优先、`FallbackAssets` 默认中性 6×4 贴图兜底；角色的 `faces_left_unflipped` 朝向元数据保留。
- **可维护性**：所有动作具有可查询的引擎原生 clip 和属性轨，以后可将 clip 保存为可视化编辑的 `.tres` 或放入 `.tscn`；不再需要自研 Sprite2D 帧循环。

## 为什么没有一次性改用所有引擎节点

| 领域 | 现在 | 取舍 |
|---|---|---|
| 角色动画 | `AnimationPlayer`、`AnimationLibrary` | 合适：时间轨与插值由引擎做 |
| 连续及格子寻路 | `AStar2D`、`AStarGrid2D` | 已原生，保留六人站位、代价、路径缓存的游戏规则适配 |
| 动态人群避障 | 现有 `BattleSpatialService` | `NavigationAgent2D`/NavigationServer 适合实时 agent，但不应直接替换可复现的回合制路径结算；先有同图同路径基准才迁移 |
| 命中、武学、姿态、CTB | `BattleModel`、内容 Resource | 引擎没有对应游戏规则，不可移交给动画节点 |
| 输入与 UI 动效 | Godot `Control`、已有 Tween | 保持，引擎负责绘制与插值 |

## 回归与继续迁移

`checks/test_r30_native_animation.gd` 覆盖原生动画轨、手动 tick、原创图与默认图、动作恢复、语义 cue 与规则只读边界，并加入 HUD CI。原有 `test_battle_action_timeline.gd`、`test_actor_facing.gd`、`test_battle_presentation_coordinator.gd` 与截图回归继续运行。

这次**没有**删除技能 ID 兼容映射和仍被正式读取的 7 份 `WuxiaDataDocument`。原生战斗演出并不等于武学配置完全强类型化。下一步应把 `r25_action_timelines` 迁为独立强类型的 `Resource` clip/cue，建立旧值与新值的同一性断言后，再移除生产代码中的 Dictionary 解释器。保留旧 ID 映射的条件是存档、旧测试或导入器仍依赖它；确认没有消费者之后才能删。已经删除的旧场景不必为了历史测试重新放回正式工程。

历史回归是对重构前已确定正确的战斗行为做防退化检测，兼容性测试检查旧存档/旧内容 ID/事件被新加载器识别。它们是可替换、可退役的测试保护，不是保留冗余正式运行代码的理由。
