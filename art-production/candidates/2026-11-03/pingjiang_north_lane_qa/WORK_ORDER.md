# 平江北街 1600×4000 南北长巷技术简图

- asset_id: pingjiang_north_lane_qa
- asset_type: environment / scene_layer
- status: candidate（只在独立 QA 入口中 in_use，未人工批准替换正式剧情美术）
- target_usage: vertical scroll QA
- source / rights: 本项目原创确定性 SVG 矢量构图，没有引用第三方图像
- prompt_version: ART_STYLE_AI_PROMPTS_V1，遵循 TOWN_MAP_SCALE_PRODUCTION
- model / seed: 代码构造矢量几何，不使用图像模型或 seed
- source assets: scene_pingjiang_north_lane_{background,ground,foreground}_v01.svg
- runtime map: res://data/maps/pingjiang_north_lane_qa.tres
- runtime layered profile: res://data/native/scene_art/pingjiang_north_lane_qa.tres
- logical game viewport: 1600×1000；actual world canvas: 1600×4000

## 原始构图提示

> 采用《长风浮生录》统一 80 世界像素/单位、200px 普通角色高度、24px 脚点半径，为平江城设计可实际游玩的竖向南北长巷简图。三层画布均为 1600×4000，在 1600×1000 横屏视口中随人物 Y 坐标滚动。中央 X=620–980 是约 360px 宽的青石巷道，Y=40–3960 连续畅通；两侧每约 440px 设置白墙黛瓦、深青门窗、檐口与少量暖色灯笼，避免空洞。保持固定 2.5D 轻俯视角与同一人物比例，不随远处 Y 缩小角色。分 background、ground 与具有透明 Alpha 的 foreground 三层，原点一致；不绘制 UI、人物、文字或网格。碰撞只从 Godot 原生多边形读取。

确定性构建方法：九组街屋和灯笼沿 Y 循环布局；ground 以全长 360px 石板路独立绘制；foreground 只绘局部檐口及枝叶，其他区域为真透明。未压缩/旋转画布，未调整现有主干道与东市美术。

## 技术及视觉核验清单

- [ ] Godot Import 三层 SVG，均解码成 1600×4000
- [ ] SceneArtProfile.reference_size 和 MapDefinition.viewport_size 均为 1600×4000
- [ ] MapBake 可走区域 X=620–980，Y=40–3960；走到屋墙方向受阻
- [ ] 从 (800,3700) 到 (800,100) 全程可走，镜头 Y 由 -3000 到 0
- [ ] 人物始终 200px 高，场景与脚点、鼠标逆映射一致
- [ ] 1600×1000 与 1440×900 两档 GUI 截图，前景及滚动流畅性人工检查
- [ ] 人工来源/相似性/美术风格验收（当前未批准）
