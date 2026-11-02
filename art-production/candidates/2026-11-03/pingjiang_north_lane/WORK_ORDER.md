# 平江府北街 · 1600×4000 南北长街 QA 候选

- asset_id: `pingjiang_north_lane_qa`
- asset_type: `scene_layer` / `environment`
- target_usage: `story_test`（Demo 标题 V / 东市北门连接点，**不替换正式序幕**）
- status: `candidate`
- source/rights: 原创确定性代码绘制 SVG 简图；无第三方商业游戏贴图
- palette: 宣纸白墙、青灰黛瓦、竹青、浅暖灯笼；与平江主街 / 东市的手绘武侠测试色板一致
- camera: 固定 2.5D 横屏视口 **1600×1000**，世界原生画布 **1600×4000**，纵向 Y 镜头跟随，不改变角色比例
- scale: 1u=80 世界像素，人物 200px 高，地面占位 24px
- native map: `res://data/maps/pingjiang_north_lane_qa.tres`
- art profile: `res://data/native/scene_art/pingjiang_north_lane_qa.tres`
- prompt template: `ART_STYLE_AI_PROMPTS_V1` 场景 / vertical 指导；本次为精确矢量技术占位，不经过随机 AI 生成
- model/version/seed: 不适用（手工程序式 SVG）

## 原始构图提示词

> 《长风浮生录》平江北街纵向地图技术简图：世界画布严格 1600×4000，逻辑窗口始终 1600×1000（不能旋转或缩放横向背景）；固定轻俯视 2.5D 武侠视角，背景铺陈江南白墙黛瓦商铺、狭长河渠、灯笼、柳枝。南北向中央石板路连续贯穿全图，宽约 470px，人物脚点允许在 X=565–1035、Y=30–3970 范围移动；两侧建筑与水渠不可走。画面最北、最南建筑和道路透视与人物比例相同，人物可见身高始终 200px，脚点半径 24px，1u=80px。按同一画布、原点分 background/ground/foreground 三层输出，ground 及 foreground 以真实透明呈现。东市北门目标入口位于本图 (800,3500)，向南移动到 (800,3860) 绿色连接点可回东市 (1320,835)；所有出口和出生点由原生 WuxiaMapDefinition 标注，不将 UI/假人/导航线画进素材。

## 技术交付

- `scene_pingjiang_north_lane_background_v01.svg`：4000px 高的两侧白墙、屋檐、商铺、河渠与灯笼
- `scene_pingjiang_north_lane_ground_v01.svg`：纵向连续石板街面、清晰边界、与背景同原点
- `scene_pingjiang_north_lane_foreground_v01.svg`：透明柳枝与灯笼近景，用于遮挡预览

运行中候选路径：`demos/changfeng-battle/assets/imported/candidates/2026-11-03/pingjiang_north_lane/`，另有 `art-production/in-use/imported/candidates/` 镜像以符合导入流程。尚未获正式美术批准。

## 验收清单

- [ ] 三层 SVG 为原生 1600×4000，不拉伸 1600×1000 旧图
- [ ] 原生 `.tres` 能读取、校验并驱动竖向多边形行走
- [ ] 初始 Y=3500 镜头偏移 -3000；到 Y=2100 为 -1600；到 Y≈200 为 0
- [ ] 最上、最下段角色都维持 200px 视觉高度和 24px 脚点
- [ ] 从东市北门进入、南门返回东市；旧图卸载，目标入口合法
- [ ] 1600×1000、1440×900 GUI 截图人工验证地面、遮挡与门洞

## 结论

技术候选，等待真实截图与人工审查；不是正式商业美术。
