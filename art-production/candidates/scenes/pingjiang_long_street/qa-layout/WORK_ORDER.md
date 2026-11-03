# 平江府主干道与东市 · 五屏双区拼接滚屏候选

- asset_id: `pingjiang_long_street_qa`
- status: `candidate`
- scene: `Screen_West` / `horizontal`
- authored world canvas: **4800×1000**, fixed game viewport: **1600×1000**
- world scale: 1u=80px, ordinary hero=200px, footprint radius=24px
- purpose: test actual Godot horizontal follow scrolling, mouse coordinate conversion, polygon movement, layer alignment, and bidirectional movement across two stitched native map areas.
- source: deterministic SVG blockout, NOT the previous image-generation preview and NOT approved final background art.
- live visual entry: Demo title menu **P · 平江双区滚屏测试** (shortcut P), or `res://scenes/pingjiang_scroll_qa.tscn`; Esc returns to title.
- native Resource: `res://data/maps/pingjiang_long_street_qa.tres`
- layered Resource: `res://data/native/scene_art/pingjiang_long_street_qa.tres`

## 素材生成指令（保留原始简图设计提示）

> 使用《长风浮生录》统一世界比例尺，为江南府平江城临河水市主大街创建一张可滚屏的简化 2D 横向地图。完整世界画布 4800×1000，游戏视口为 1600×1000，场景中人物视觉高度固定 200px、地面占位半径 24px、1 游戏单位等于 80 世界像素。沿 X 轴连续排布江南白墙黛瓦、药铺、铁匠铺、茶摊、运河白石栏及乌篷船；青石道路全程连续，人物可走地面位于 Y≈635–930，沿全图左右进出，不得塞入障碍或随滚屏缩小人物。分层交付背景、地面及可选近景，所有层 4800×1000、同原点、Alpha 合法；地图碰撞另由 Godot WuxiaMapDefinition 多边形定义，不从贴图颜色推断。

## 新增拼接区：东市

- independent native map: `res://data/maps/pingjiang_east_market_qa.tres`
- independent layered profile: `res://data/native/scene_art/pingjiang_east_market_qa.tres`
- authored second canvas: **3200×1000**, joined at world X=4800; total world width **8000×1000**
- three additional distinct SVG layers: `scene_pingjiang_east_market_{background,ground,foreground}_v01.svg`
- the existing long street walkable eastern polygon edge extends to X=4799; the east map begins at its own local X=0.
- the actor and camera use continuous world coordinates: no teleport and no change in 80px/u / 200px actor scale.
- both sides of the shared walkable edge must be valid for the 24px footprint; F3 outlines can show the two local polygons.

## 技术交付

| 文件 | 用途 |
| --- | --- |
| `scene_pingjiang_long_background_v01.svg` | 天空、城市街屋、店面、两处运河与乌篷船的 4800×1000 QA 母图 |
| `scene_pingjiang_long_ground_v01.svg` | 全程连续、透明外缘的青石街面 |
| `scene_pingjiang_long_foreground_v01.svg` | 少量近景柳枝（真实透明） |

三层保存在 `demos/changfeng-battle/assets/imported/in-use/scenes/pingjiang_long_street/`，是可被 Godot SVG Importer 导入的技术测试占位素材，不等于正式高清美术，也不应直接替换主线剧情地图。

## 视觉验收点

- [ ] Godot 载入原生资源，无 SVG 解码／尺寸异常
- [ ] 主角从 X=200 行至 X=2400，场景向左滚动 1600px
- [ ] 主角再行至 X=4600，场景继续偏移至 -3800px（因为后面还有东市地图）
- [ ] X=4800 无障碍地走到东市、左行再返回主干道；HUD 跨区计数依次增加
- [ ] 东市 X=7800 时场景偏移钳制在 -6400px
- [ ] 左右边缘不出现背景空白、人物世界比例保持 200px
- [ ] Y=635–930 可走区范围内横向行走，超出边界被阻挡
- [ ] 任意滚屏位置点击街面，鼠标屏幕坐标正确转换为人物目标世界坐标
- [ ] 1600×1000 与 1440×900 两种窗口截图人工确认

## 后续

先通过完整运行和截图验收，再将代码占位风格升级为正式原创分层 PNG；保留同一世界坐标和 `.tres` 合同。两区无传送的双向移动现已纳入验证，动态分块流送、正式区域载入流程与独立动态遮挡物仍不在本次验证范围。
