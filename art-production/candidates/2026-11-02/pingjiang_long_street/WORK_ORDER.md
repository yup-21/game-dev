# 平江府临河水市主大街 · 三屏滚屏候选

- asset_id: `pingjiang_long_street_qa`
- status: `candidate`
- scene: `Screen_West` / `horizontal`
- authored world canvas: **4800×1000**, fixed game viewport: **1600×1000**
- world scale: 1u=80px, ordinary hero=200px, footprint radius=24px
- purpose: test actual Godot horizontal follow scrolling, mouse coordinate conversion, polygon movement and layer alignment.
- source: deterministic SVG blockout, NOT the previous image-generation preview and NOT approved final background art.
- live visual entry (QA only): `res://scenes/pingjiang_scroll_qa.tscn`
- native Resource: `res://data/maps/pingjiang_long_street_qa.tres`
- layered Resource: `res://data/native/scene_art/pingjiang_long_street_qa.tres`

## 素材生成指令（保留原始简图设计提示）

> 使用《长风浮生录》统一世界比例尺，为江南府平江城临河水市主大街创建一张可滚屏的简化 2D 横向地图。完整世界画布 4800×1000，游戏视口为 1600×1000，场景中人物视觉高度固定 200px、地面占位半径 24px、1 游戏单位等于 80 世界像素。沿 X 轴连续排布江南白墙黛瓦、药铺、铁匠铺、茶摊、运河白石栏及乌篷船；青石道路全程连续，人物可走地面位于 Y≈635–930，沿全图左右进出，不得塞入障碍或随滚屏缩小人物。分层交付背景、地面及可选近景，所有层 4800×1000、同原点、Alpha 合法；地图碰撞另由 Godot WuxiaMapDefinition 多边形定义，不从贴图颜色推断。

## 技术交付

| 文件 | 用途 |
| --- | --- |
| `scene_pingjiang_long_background_v01.svg` | 天空、城市街屋、店面、两处运河与乌篷船的 4800×1000 QA 母图 |
| `scene_pingjiang_long_ground_v01.svg` | 全程连续、透明外缘的青石街面 |
| `scene_pingjiang_long_foreground_v01.svg` | 少量近景柳枝（真实透明） |

三层保存在 `demos/changfeng-battle/assets/imported/candidates/2026-11-02/pingjiang_long_street/`，是可被 Godot SVG Importer 导入的技术测试占位素材，不等于正式高清美术，也不应直接替换主线剧情地图。

## 视觉验收点

- [ ] Godot 载入原生资源，无 SVG 解码／尺寸异常
- [ ] 主角从 X=200 行至 X=2400，场景向左滚动 1600px
- [ ] 主角再行至 X=4600，场景偏移钳制在 -3200px
- [ ] 左右边缘不出现背景空白、人物世界比例保持 200px
- [ ] Y=635–930 可走区范围内横向行走，超出边界被阻挡
- [ ] 任意滚屏位置点击街面，鼠标屏幕坐标正确转换为人物目标世界坐标
- [ ] 1600×1000 与 1440×900 两种窗口截图人工确认

## 后续

先通过完整运行和截图验收，再将代码占位风格升级为正式原创分层 PNG；保留同一世界坐标和 `.tres` 合同。街区自动切换、分块流送、独立动态遮挡物不在本次验证范围。
