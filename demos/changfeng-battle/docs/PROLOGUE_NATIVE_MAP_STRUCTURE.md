# 序幕原生场景 · 正式 V2 与独立地图 QA

本页以当前 Godot 工程为准，关联企划稿：`docs/game-design/chapters/act-0-prologue-v2.md`。**正式序幕**与**独立地图 QA**共用四张可编辑地图，但有两套独立的剧情状态；不要把旧的返庙遭遇误认为正式 V2 剧情。

## 入口与玩法

- 正式序幕：主菜单新游戏，通过 `GameSession.activate_prologue_chase()` 进入 `res://scenes/prologue/prologue_exploration.tscn`；对白数据在 `res://data/native/stories/prologue_chase_story.tres`。玩家因送家书路过，雨夜在殿内醒来，调查劫镖，选择救严守诚，包扎，击退庙外两名与古道三名探子，断桥托卷、诱敌，最终洞察单名哨探当前手牌并逃向平江府。
- 独立 QA：主菜单 `K · 序幕地图`，或者在 Godot 中打开 `prologue_exploration.tscn` 运行当前场景（F6，且不处在正式故事会话）。测试自由探索、调查线索、早归安全、探索后返庙首次遇敌。此测试保留旧版 `AmbushActors`，**不代表正式剧情有返庙 Boss 战**。
- 操作：WASD/方向键移动，靠近入口或互动点按 `E`，`F3` 显示可走区；正式剧情中的 `Esc` 可返回菜单。

## 四张可编辑地图

每张世界画布 **1600×1000**；主角在探索场景约 **170 像素**高。四区依次为**破庙内殿 ↔ 前院 ↔ 荒山古道 ↔ 断桥**，不合并成一张长图。

| 原生 `.tscn` | 内容／正式剧情 | 原生图层与美术资源 |
| --- | --- | --- |
| `scenes/prologue/zones/temple_hall.tscn` | 篝火初醒、避雨、救人后包扎 | `PaintedLayers/{Background,Ground,Foreground}`，引用在用 `prologue_temple_hall` WebP 三层；`Architecture` 灰盒隐藏；`Campfire` 独立火焰演出，`StoryAnchors/YanRestByFire` 为严的固定疗伤位 |
| `scenes/prologue/zones/temple_courtyard.tscn` | 救人后第一波两名探子（1v2） | 复用在用 `ruined_temple` 三层；`StoryAnchors/ScoutWave1Entry`、`ChaseActors/ScoutA,B`；**没有韩啸出场锚点** |
| `scenes/prologue/zones/mountain_road.tscn` | 劫镖残局与破车线索、第二波三名探子（1v3） | `PaintedLayers/{Background,Ground,Foreground}`，引用在用 `prologue_mountain_road` WebP 三层；`BlockoutArt` 和重复破车隐藏；`StoryAnchors/ScoutWave2Entry`、`ChaseActors/ScoutA,B,C` |
| `scenes/prologue/zones/broken_bridge.tscn` | 严守诚因两场护送而信任主角，留下残卷并沿明路诱敌；主角下溪谷对上哨探（1v1） | 复用在用 `rainy_bridge` 三层；`StoryAnchors/YanDecoy`、可调整的 `YanDecoyRoute`、五处 `SearchPartyTorches`、`FutureFerryTrailNotConnected` |

**正式演出状态：** 前院两名、古道三名追兵是独立场景节点，分别只在 `wave1_ready` 与 `wave2_ready` 显示；断桥远处搜山火光在第二波击退后出现。它们是当前阶段的简易场景剪影／灯光标记，正式战斗人数以 `GameSession`、`BattleModel` 为准。独立 QA 不显示这些追击节点。

**严守诚护送／诱敌状态：** `EscortFollower` 在 `healing` 时用已在用的受伤坐姿，固定于 `YanRestByFire`；疗伤后复用其已有站姿作为临时行走表现，主角护送速度变慢，老人以限速跟随。断桥托卷完成后，原随行实例隐藏、场景内 `YanDecoyRoute/Traveler` 从同一脚点沿编辑器定义的 `Curve2D` 向旧关卡折返，带简易断旗并淡出。全程不对 `BattleModel`、NPC 生死或道路碰撞作任何剧情豁免。

## Godot 编辑约定

1. **改图层**：直接打开对应 `zones/*.tscn`，在 `PaintedLayers` 里调 `Sprite2D`；三张 1600×1000 同画布图层与 `data/native/scene_art/prologue_temple_hall.tres`、`prologue_mountain_road.tres` 保持一致。`prologue_zone.gd` 只做绑定一致性检查，**不再运行时动态创建图层或从候选目录选图**。
2. **改碰撞**：`Navigation/Walkable` 的多边形权威定义人物可站立区域；`Navigation/Blockers` 是不可通行实体。图片不决定通行范围。修改建筑、镖车等画面时，须同步检查脚点与遮挡。
3. **改换区**：`Entries` 为出生标记，`Exits` 为 `prologue_portal.gd` 入口；设置 `target_zone_id` 与 `target_entry_id`。出口及落点留足距离，避免一加载就返回。
4. **改互动／剧情**：`Landmarks` 管调查，`StoryAnchors` 管演出站位；正式对白／奖励编辑 `prologue_chase_story.tres`，章节与战斗阶段逻辑在 `prologue_exploration.gd`、`GameSession`。不能仅移动场景锚点而忘记更新正式互动距离。
5. **改角色**：场景追兵剪影不是正式帧动画资产。主角仍使用在用角色动画配置；严守诚当前随行显示受伤静态姿势。替换角色动画需遵循动画导入规范并在 Godot 中重新验收比例。

## 已有资源与待补素材

- **已绑定**：四张地图各三层（内殿、古道为已导入的 WebP，前院、断桥复用既有正式素材）；篝火轻微火焰动画；主角角色资源；受伤严守诚静态图；战斗系统通用敌人资源。
- **待美术／演出验收（P0）**：四地图连续走图的脚点与前景遮挡；古道破车现场的伤痕、血迹／断旗是否容易读懂；严守诚目前只是受伤／站姿静态图加移动与轻微摆动，尚需正式搀扶动作、跛行及转身递卷帧，断桥路线也需实机检查镜头中的停顿与遮挡；鬼面探子的实际逐帧动作素材替换场景剪影。
- **待独立交付（P1）**：溪谷小径／烟水渡真实过场地图、船只与脚夫环境图、雨雾与远景火光 VFX；第一波和第二波区分的战斗背景（目前三场共用雨夜断桥战斗图）。尚不能把 `FutureFerryTrailNotConnected` 当作已完成的渡口地图。
- **保留悬念**：韩啸不在序幕与主角碰面，不知道残卷存在；受上级交差后才得知少了关键物品。卷名、严的生死都不在序幕揭晓。

> 内殿／古道候选美术原工作单仍可在 `art-production/candidates/scenes/` 查阅。当前场景引用的是 `assets/imported/scenes/prologue_*` 下**已有在用**的 WebP，未将新的候选版本擅自替换成正式资源。画面比例、人物脚点与前景遮挡仍需在 Godot 窗口里人工验收。

## 自动检查

从仓库根目录执行：

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_candidate_art.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_native_scenes.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_chase_flow.gd
```

两个独立预览入口仍可用：`res://scenes/prologue/prologue_hall_art_review.tscn`、`prologue_road_art_review.tscn`。界面标注“原生分层实景（视觉待验收）”，不暗示人工视觉验收已完成。
