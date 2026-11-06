# Godot 原生编辑收口：角色、战斗地图、HUD、VFX

完整编辑权与规则边界请先看 [《Godot 原生内容开发规范 V2》](../../../docs/GODOT_NATIVE_AUTHORING_STANDARD.md)；本页是已经完成原生场景的可视化操作清单，不表示所有历史内容都已迁移。

用 Godot 4 打开 `demos/changfeng-battle/project.godot`，在「文件系统」面板打开下面的资源即可编辑。**F6** 运行当前场景作局部预览，**F5** 进入完整战斗验证跨系统绑定。

| 部位 | Godot 原生入口 | 编辑方式 | 运行时权责 |
| --- | --- | --- | --- |
| 正式角色动画 | `data/native/sprite_frames/<角色>.tres`、`data/native/animations/<角色>.tres` | 在 SpriteFrames 面板调动作帧序、单帧时长、循环；Profile 绑定 | `AnimatedSprite2D` 显示；战斗行动窗口仍由 ActionTimeline 决定 |
| 战斗地图 | `scenes/maps/illustrated_battle_map.tscn` | 编辑四层 TextureRect 的位置、大小、层级和选中光圈；在地图根 Inspector 微调统一校准 | `data/maps/*.tres` 决定合法地形与格位；地图场景实例不再运行时重建 |
| 战斗 HUD/UI | `scenes/ui/battle_hud.tscn`、`scenes/ui/ctb_rail.tscn`、`scenes/ui/ctb_marker.tscn` | 编辑标签、面板、轴线、11 根刻度和头像着色器；动态头像位置只随 CTB 数值变化 | BattleModel 决定状态；原生节点决定排版外观 |
| 战斗 VFX | `scenes/vfx/combat_burst.tscn` | 编辑刀光 Line2D 点位、圆环、两组碎光、发光宽度、锚点及 `VisualAnimations` 中的淡出/缩放时间轴 | 事件只挑选对应形状、颜色、倍率及播放时长，不生成随机视觉几何 |

## 角色迁移说明

- 六位已有正式在用资源的角色各有独立的 `SpriteFrames.tres`，从原图集切出 `AtlasTexture`，未改变或替换已批准原画。
- 旧的九动作和明确映射的 `walk/run/attack1…4` 均可在 Godot 中直接检查，共 15 个动作。原始 Profile 的 Clip 保留以兼容以前的逻辑和局部脚步偏移。
- 尚未正式迁移的旧 Atlas/GIF 仍能通过兼容入口工作；素材导入工具产出的 `SpriteFrames` 也是同一原生结构。
- `tools/migrate_native_actor_frames.gd` 是一次性转换入口：**已有目标资源绝不覆盖**，避免艺术人员在 Godot 中微调后被再次生成抹去。

## 地图和特效的注意事项

- 每个战斗区域仍通过 `WuxiaMapDefinition`／`WuxiaGridMapDefinition` 决定尺寸、可行走区域和动态纹理；不要通过拖动背景来更改合法格位。
- 四层地图位于 `FlatBattle/ArtCalibration`。脚本只改变整体校准容器的变换，不覆盖各 `TextureRect` 的编辑器偏移；独立修改前景遮挡、雨层位置会保存并生效。
- VFX 的 `AuthoredVFX` 节点仍可替换为正式透明素材；若某技能显式声明了 PackedScene，运行时会直接实例化其原生场景。
- 所有改变仅属于表现层；不修改命中、CTB、角色行动、碰撞和跨区规则。

## 自动验收

导入资源后执行：

```bash
godot --headless --editor --path demos/changfeng-battle --import
godot --headless --path demos/changfeng-battle --script res://checks/test_native_visual_closure.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_native_scene_authoring.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_native_gif_animation.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_ctb_rail.gd
```
