# 序幕原生地图结构 · 破庙初醒／外出探索／返庙遇敌

本结构是**独立 Godot 原生场景 QA / 灰盒**，用于确定序幕的空间、行走区、剧情锚点与跨区节奏。它尚未接入正式 `WuxiaChapterDefinition`、`WuxiaStoryDefinition` 或 Content Manifest，也不会修改 `GameSession` 的存档旗标；不能当成正式序章已经完成。

## 场景与出口

入口：主菜单 **K · 序幕地图**，或在 Godot 中打开 `res://scenes/prologue/prologue_exploration.tscn` 并运行当前场景（F6）。四张独立场景均可在 Godot **2D 编辑器中直接打开**：

| 原生 `.tscn` | 内容 | 入口／出口 | 美术状态 |
| --- | --- | --- | --- |
| `zones/temple_hall.tscn` | 主角在内殿火边醒来；篝火、断梁、神像、神像后藏身点；返庙后出现两名鬼面刀卫 | `WakeByFire`／`FromCourtyard`；`ToCourtyard` | Godot `Polygon2D` 可编辑灰盒，尚需室内原画 |
| `zones/temple_courtyard.tscn` | 空院、内殿门和出山口；后续韩骁决战预留空间 | `FromHall`／`FromRoad`；`ToHall`／`ToRoad` | 使用现有破庙背景／地面／前景，尚需对齐美术视角 |
| `zones/mountain_road.tscn` | 雨夜古道、破损镖车和新鲜刀痕；给玩家一段自由探索的时间 | `FromCourtyard`／`FromBridge`；`ToCourtyard`／`ToBridge` | Godot `Polygon2D` 可编辑灰盒，尚需山路原画 |
| `zones/broken_bridge.tscn` | 断桥、追兵线索方向；暂不接通后续渡口 | `FromRoad`；`ToRoad` | 使用现有断桥背景／地面／前景 |

地图拓扑为 **内殿 ↔ 前院 ↔ 古道 ↔ 断桥**。每个场景为 1600×1000 世界像素，玩家按当前探索约 170px 身高显示；不会将四张画面永久合并成一张大图。

## 交互和剧情门槛

1. **初醒**：玩家位于内殿篝火旁，可自由走动，鬼面刀卫节点默认隐藏。靠近内殿出口按 `E` 到前院。
2. **自由探索**：可以先回庙；如果没有外部探索成果，**返回时不会刷敌**，避免刚出门就误触发。
3. **外部成果**：走至古道破车，靠近线索按 `E` 调查；或者一路走到断桥。任一项完成即记录本次 QA 的外出探索里程碑，不依赖玩家待机时长。
4. **返庙遇敌**：从前院重新进入内殿时，第一次展示两名鬼面刀卫，以及严守诚藏于神像后方的锚点；再次出入不会重复触发。
5. **后续剧情**：严守诚交付旧镖文书、韩骁在前院决战（`StoryAnchors/HanXiaoForecourtBattle`）、烟水渡收束（断桥 `StoryAnchors/FutureFerryTrailNotConnected`），均**只预留地图位置与连接方向**。对白、战斗和奖励仍由正式章节 Resource 决定，此 QA 暂不伪造联动。

## 在 Godot 原生编辑器里修改

- 选择对应 `zones/*.tscn` → **2D 视图**修改 `Architecture`／`BlockoutArt`／`PaintedLayers` 下的图层。
- `Navigation/Walkable` 的 `Polygon2D.polygon` 是此灰盒中玩家脚点可走范围的权威数据；`Navigation/Blockers` 下的多边形是不可走的篝火、神像、障碍物。按 `F3` 可在游戏里显示／隐藏可走范围；角色脚点使用约 20px 的周边检测。
- `Entries/` 下的 `Marker2D` 是出生／换区落点；`Exits/` 下的标记使用 `prologue_portal.gd`，在 Inspector 设置 `target_zone_id` 和 `target_entry_id`，运行时校验落点合法。出口和落点不要重合以免返回后误触发。
- `Landmarks/CartTraces` 使用 `prologue_landmark.gd`；查看线索和断桥到达会改变本次 QA 的内存状态。`AmbushActors/` 是返庙后出现的人物锚点，目前的彩色剪影不是正式角色贴图。
- 在运行的 QA 场景里 **WASD/方向键**移动，靠近标记按 **E**，**Esc** 返回菜单。玩家实际操作可验收首次返回安全、探索后返庙遇敌。

## 测试与后续接入

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_native_scenes.gd
```

正式接入顺序：确认内殿／山路两张美术 → 为四张地图建立／校准正式 `WuxiaMapDefinition` 与 SceneArtProfile → 把退出／调查／返庙状态挂到章节原生 Story 事件 → 驱动严守诚对话与战斗遭遇 → 继续制作烟水渡。正式 Resource 应保持单一配置来源，**不要把这套 QA 状态直接写回正式章节数据**。

## 新增内殿／古道候选美术预览（PR #141 第二阶段）

两张美术母版已按 **1600×1000** 生成并拆为同画布的背景、地面与前景三层。为避免 AI 独立分层产生不对位，本轮采用**从同一母版按遮罩分割**的方法，构建后的 `preview.png` 必须逐像素还原 `master.png`；真实动态篝火与雨雾仍需单独开发。

完整高分辨率 PNG 尚未上传到 GitHub，本 PR 的新增内容是可复用的构建工具、验收工作单、独立原生预览入口和自动结构测试。图层需要从单独交付的候选素材包导入；**缺图时预览器应自动保留原灰盒**，不得被误认为艺术验收通过。

将原始 `雨夜残寺篝火.png` 和 `雨中竹山古道与破车.png` 放在同一目录，在仓库根目录执行：

```sh
python art-production/tools/build_prologue_candidate_layers.py \
  --source-root /path/to/masters \
  --out demos/changfeng-battle/assets/candidates/prologue
```

Godot 预览入口：

- `res://scenes/prologue/prologue_hall_art_review.tscn`
- `res://scenes/prologue/prologue_road_art_review.tscn`

测试命令：

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_candidate_art.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_native_scenes.gd
```

候选美术的单独审核依据见 `art-production/candidates/scenes/prologue_temple_hall/WORK_ORDER.md` 与 `art-production/candidates/scenes/prologue_mountain_road/WORK_ORDER.md`。碰撞和人物脚点仍由原生区域节点控制，**候选贴图仅用于预览，不直接写入正式 WuxiaMapDefinition 或 SceneArtProfile**。
