# PJ-02 平江四街十字路 — 美术候选工作单

- asset_id: `pingjiang_crossroads`
- asset_type: `environment` / `scene_layer`
- target_usage: `story` / `exploration`
- status: `candidate`（**尚未 `in_use`**）
- 对应企划区：`PJ-02`；建议 `scene_id`: `pingjiang_crossroads`
- 目标 Godot Resource：`res://data/native/scene_art/pingjiang_crossroads.tres`，尚未创建或绑定
- 计划导入路径：`res://assets/imported/scenes/pingjiang_crossroads/{background,ground,foreground}.webp`，**目前未导入**
- 制作基线：`docs/game-design/pingjiang-prefecture-map-plan.md` §7
- 原始提示词：[`PROMPTS.md`](PROMPTS.md)
- 来源与权属：本次 AI 原创生成；项目归属及商业近似性仍须人工复核

## 镜头、尺度与构图

- 逻辑画布：1600×1000，16:10，固定横屏轻俯视 2.5D；左上角为 (0, 0)。
- 比例尺来自 `scripts/combat_scale.gd`：80 世界像素/u，人物参考高度 200px，脚底占位半径 24px。
- 主轴：`mixed`；北南石板巷与东西主街须真实连通。暮秋江南，粉墙黛瓦、青石、蓝灰/竹青、少量灯笼暖金。
- 北：石牌坊与通往府衙的巷道；南：瓮城正南门；西：临河水市；东：苏氏别院。
- 街面设计候选：横向 Y=620–940；纵向 X=640–960，向北贯通。画面中实际道路更宽，**几何需以 Godot 可走多边形复核**，不可直接把矩形当碰撞。
- 本轮新增统一视角：轻俯视近似正交/弱透视，保留店铺立面但压制真实可走路面的消失点收缩；相邻区继续复用同一镜头。参见 [`CAMERA_REVIEW.md`](CAMERA_REVIEW.md)。
- 交互：说书茶棚、悬赏告示、游商、绣坊、当铺；不把图上的装饰物自动识别为 NPC 或障碍。
- 出入口锚点见 [`LAYOUT.md`](LAYOUT.md)，仅是建议坐标，不代表现有地图切换实现。
- 参考引导：本次通过 `python art-production/tools/scene_scale_guide.py --orientation mixed ...` 生成透明标尺；**引导格线未烘焙进母版**。

## 本轮候选产物

| 文件 | 用途 | 技术结果 | 当前结论 |
| --- | --- | --- | --- |
| `environment_pingjiang_crossroads_master_v01.webp` | 完整概念母版 | 1600×1000，不透明画作，四向道路直观可见 | 可先进行视觉评审，非分层正式地图 |
| `environment_pingjiang_crossroads_master_v02.webp` | 统一视角/建筑比例修订母版 | 1600×1000，结合既有路口构图与用户提供的街景氛围 | **首选视觉审查候选**；未通过真实角色比例验收 |
| `scene_pingjiang_crossroads_ground_draft_v01.webp` | 道路独立 Alpha 分离尝试 | 1600×1000，具有真实透明通道 | 道路边界存在少量红/洋红残色，**需返工** |
| `scene_pingjiang_crossroads_background_draft_v01.webp` | 建筑/远景独立 Alpha 分离尝试 | 1600×1000，具有真实透明通道 | 路面空洞周边存在红黄边缘杂色，**需返工** |
| `layout_pingjiang_crossroads_v01.svg` | 不入游戏的路线与锚点设计参考 | 1600×1000 同原点，独立 SVG | 仅供人工对位/碰撞编辑 |

原始 AI 输出分别为 1586×992（母版 v01/v02）、1585×992（ground / background），本轮为便于对位统一整体重采样到 1600×1000；仓库中的 WebP 是候选输出，不是最终无损可编辑分层母版。**两张分层 draft 均取自 v01，不与 v02 配套。**模型将建筑与街面分离时仍存在透明边缘污染，**不得把这两张 draft 贴图组合后宣称已通过图层 QA**。

## 自动检查与人工审核

- [x] 读取 `combat_scale.gd` 的比例尺测试：`scene_scale_guide.py --check` 通过。
- [x] 两张母版、ground draft、background draft 尺寸均为 1600×1000。
- [x] 两张 draft 经解码均有非全不透明 Alpha；母版为 RGB。
- [ ] 基于首选 v02 母版重绘完整分层；现有 v01 分层无色边且像素级对齐的检查 **当前失败**。
- [ ] 有独立透明前景遮挡层，角色可在牌坊/房檐前后正确遮挡。
- [ ] 可走多边形、真实出口、NPC 脚点与图面一致；六人站位/交互距离核准。
- [ ] `WuxiaSceneArtProfile` 和对应 ChapterScene/Map Resource 加载通过。
- [ ] Godot GUI 1600×1000 / 1440×900 行走、遮挡、跨区切换视觉验收。
- [ ] 权属与相似度、整体视觉由负责人批准。

## 结论

**视觉验收：待复核；图层拆分：需返工。**

下一步优先精修独立 background/ground 的透明边缘及前景屋檐，再用本工作单锚点接入真实 `WuxiaSceneArtProfile`、原生地图与相邻区双向 `zone_exit`；在通过技术和人工验收前，不覆盖任何当前使用中的资源。

## 2026-11-05 四区探索测试接入（更新）

v02 已通过具名多边形蒙版无损拆为三张同原点 RGBA PNG，见 `layers-v02/README.md`。新增 `WuxiaSceneArtProfile` / `WuxiaMapDefinition` 与四向出生/出口，south 与 PJ-01、west 与 PJ-03 双向联通。导入采用 `assets/imported/scenes/pingjiang_crossroads/{background,ground,foreground}.png`，上文“尚未创建/导入”是前轮记录，由本节更新。

真实几何：纵向道路 X=680–875（北端）至 X=640–925（街口），横向主要脚点带 Y=570–770，南向 X=620–980；出生点均留有24px脚点净距。北出口设在牌坊内侧 (780,220)，并非穿越画面顶部远景；东/北邻区尚未开放。技术回拼与全程移动通过，GUI、透视、门洞比例、动态遮挡与美术/权属人工审核仍待完成，不替换主线内容绑定。
