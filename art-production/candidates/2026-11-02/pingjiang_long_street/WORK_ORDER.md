# 平江府主干道与东市 · 独立区域连接点跳转候选

- asset_id: `pingjiang_long_street_qa`
- status: `candidate`
- scene: `Screen_West` / `horizontal`
- authored world canvas: **4800×1000**, fixed game viewport: **1600×1000**
- world scale: 1u=80px, ordinary hero=200px, footprint radius=24px
- purpose: test actual Godot horizontal follow scrolling, mouse coordinate conversion, polygon movement, layer alignment, and bidirectional zone_exit → spawn scene switching across two independent native maps.
- source: deterministic SVG blockout, NOT the previous image-generation preview and NOT approved final background art.
- live visual entry: Demo title menu **P · 平江跨地图跳转** (shortcut P), or `res://scenes/pingjiang_scroll_qa.tscn`; Esc returns to title.
- native Resource: `res://data/maps/pingjiang_long_street_qa.tres`
- layered Resource: `res://data/native/scene_art/pingjiang_long_street_qa.tres`

## 素材生成指令（保留原始简图设计提示）

> 使用《长风浮生录》统一世界比例尺，为江南府平江城临河水市主大街创建一张可滚屏的简化 2D 横向地图。完整世界画布 4800×1000，游戏视口为 1600×1000，场景中人物视觉高度固定 200px、地面占位半径 24px、1 游戏单位等于 80 世界像素。沿 X 轴连续排布江南白墙黛瓦、药铺、铁匠铺、茶摊、运河白石栏及乌篷船；青石道路全程连续，人物可走地面位于 Y≈635–930，沿全图左右进出，不得塞入障碍或随滚屏缩小人物。分层交付背景、地面及可选近景，所有层 4800×1000、同原点、Alpha 合法；地图碰撞另由 Godot WuxiaMapDefinition 多边形定义，不从贴图颜色推断。

## 第二张独立地图：东市（不拼接）

- independent native map: `res://data/maps/pingjiang_east_market_qa.tres`
- independent layered profile: `res://data/native/scene_art/pingjiang_east_market_qa.tres`
- second canvas **3200×1000**, its own local X coordinates and camera clamp -1600; main street remains **4800×1000** and clamps -3200.
- three additional SVG scene layers: `scene_pingjiang_east_market_{background,ground,foreground}_v01.svg`
- main street `to_east` (4690,790) → East `from_west` (400,790); East `to_west` (140,790) → main street `from_east` (4380,790).
- East north doorway `to_north` (1305,700) → separate 1600×4000 north lane `from_south` (800,3500). Returning uses the vertical south exit.
- `WuxiaMapMarkerDefinition` is the single source of zone routing; at runtime only one map's art and collision resource are active. Actor height 200px/80px=u stays unchanged.

## 技术交付

| 文件 | 用途 |
| --- | --- |
| `scene_pingjiang_long_background_v01.svg` | 天空、城市街屋、店面、两处运河与乌篷船的 4800×1000 QA 母图 |
| `scene_pingjiang_long_ground_v01.svg` | 全程连续、透明外缘的青石街面 |
| `scene_pingjiang_long_foreground_v01.svg` | 少量近景柳枝（真实透明） |

三层保存在 `demos/changfeng-battle/assets/imported/candidates/2026-11-02/pingjiang_long_street/`，是可被 Godot SVG Importer 导入的技术测试占位素材，不等于正式高清美术，也不应直接替换主线剧情地图。

## 视觉验收点

- [ ] 主街 X=2400 镜头偏移 -1600；靠近东端钳制在 -3200
- [ ] 接触 X≈4690 的绿色出口后旧地图节点卸载，进入东市 X=400，镜头偏移清零
- [ ] 东市西端连接点返回主干道指定出生点，而不是走 8000px 的连续全局长图
- [ ] 东市北门进入独立 1600×4000 南北长街，并可从其南门双向返回
- [ ] F3 显示各地图独立可走多边形；纵向相机只沿 Y 跟随
- [ ] 80px/u、200px 角色、24px 脚点尺度均不变，鼠标点选转场后仍准确
- [ ] 1600×1000 / 1440×900 两套窗口人工截图确认图层与遮挡

## 后续

先通过完整运行和截图验收，再将代码占位风格升级为正式原创分层 PNG；保留同一世界坐标和 `.tres` 合同。此轮新增独立地图之间按 zone_exit/spawn 的测试性加载跳转；正式剧情的区域管理、动态流送与独立动态遮挡物仍不在本次验证范围。
