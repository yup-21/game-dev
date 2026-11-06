---
name: wuxia-scene-art
description: "为《长风浮生录》设计、生成、拆分、导入或审核剧情与战斗地图美术时使用；落实分层贴图、镜头与脚点、Godot 原生可编辑 .tscn 地图及 WuxiaSceneArtProfile／WuxiaMapDefinition 绑定。"
---

# 武侠场景分层制作

## 依据

- 先读取 art-production/standards/ART_PRODUCTION_STANDARD.md、art-production/standards/TOWN_MAP_SCALE_PRODUCTION.md 的场景与比例尺合同，以及 [Godot 原生内容开发规范 V2](../../../docs/GODOT_NATIVE_AUTHORING_STANDARD.md) 的探索／战斗地图编辑权；AI 制作时读取 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md 的场景提示词。
- 复制 art-production/templates/asset-work-order.md 至 art-production/candidates/<asset-type>/<asset-id>/WORK_ORDER.md，记录参考母图、镜头、色板、地标、原点、图层、版权和版本。
- 全游戏采用原创手绘自然材质、清晰地面空间及真实前后景遮挡；正式 **2D 分层场景**保持既定镜头合同，不用 3D 棋盘叠加背景伪造场景。真实简易 3D 几何加手绘贴图的已验证 **2.5D 技术原型**属于独立入口，不等同于 2D 分层交付，也不由本条禁止；正式采用时仍须显式定义相应场景 Resource/碰撞与镜头合同并做实机验收。
- Agent 先选定 `horizontal/vertical/mixed`、镜头、出口拓扑、画布像素尺寸及当前图层，再把 `ART_STYLE_AI_PROMPTS_V1.md` §6 的场景／分层短模板**全部填成确定值**后发送；不让生图模型选择街区方向、图层或画布。80px/u、碰撞范围、同画布对齐等保留在本 Skill 和检查工具，不逐项拼成绘图提示词。

## 制作流程

1. **构图合同**：以 1600×1000、16:10 逻辑画布及 **80 世界像素/单位、普通角色 200px 高**确定镜头、脚点、可走区域和地标；城镇街区先用 `python art-production/tools/scene_scale_guide.py --output /tmp/town_scale.png` 输出比例参照层。1440×900 仅缩放窗口，不改世界比例。
2. **先出概念母版**：城镇先选 `horizontal`、`vertical` 或 `mixed`，规划横向主街、南北向纵深街道或十字街口及上/下/左/右出口；用 `scene_scale_guide.py --orientation vertical` 或 `--orientation mixed` 生成相应比例参照图，不把超大城市缩成一幅贴图；明确主角、敌人、NPC 的站位及路线。战斗场景需支持至少六人清晰分布；地图可走区、视觉障碍、前景装饰要分离。整张概念图不是可运行地图。
3. **分层交付**：以同一画布原点和尺寸输出 background（远景，必需）、ground（可站立地面，必需）、foreground（可遮挡，按需）、weather（雨雾等，按需）；不属于当前图层的像素使用真实透明 Alpha。保留可编辑分层母版。
4. **保持空间合同**：纵向街道的**屏幕**仍是 1600×1000 横屏；超出单屏时可制作 1600×2400 等同尺寸完整层并设置原生 `world_size` / `viewport_size`，镜头沿 Y 滚动但人物仍为 200px 高；上/下出口不得伪造为旋转横向图片。所有地标在各层的坐标一致，前景对象可在 Node2D 层独立遮挡角色；雨、雾、灯光等表现层可关闭，且关闭后不影响路径、LOS、出生点或触发区域。
5. **接入 Godot**：按 `assets/imported/scenes/<scene-id>/background|ground|foreground|weather|story_preview.<ext>` 导入并创建／更新 `WuxiaSceneArtProfile`；空纹理槽位依精确文件名绑定，Inspector 手动引用优先，缺少必需层直接报错。单屏 `reference_size` 为 1600×1000，长画布（如 1600×2400）与 `WuxiaChapterSceneDefinition.world_size`／`WuxiaMapDefinition.viewport_size` 同尺寸，`pixels_per_unit=80`，**新地图不擅自改变比例与旋转**；已校准的旧地图变换不得被导入器重置。**探索区域原生化后**在 `.tscn` 编辑分层节点、`WalkableArea/Boundary`、`Obstacles`、`Markers`、`Exits`，保存场景后通过 Inspector 显式同步地图 `.tres` 快照；**战斗地图**仍由 Map Resource 决定合法区域，原生 `.tscn` 只调整画面分层与遮挡。未迁移旧地图继续以原 `.tres` 编辑；导入层纹理不能覆盖手动保存的几何、脚点、Marker／出口。
6. **核验对位**：在 Godot Editor 中按剧情和战斗玩法实际移动角色，检查横向／纵向脚点、道路、遮挡、地图碰撞及美术对应；探索区域额外检查场景保存后的资源同步、四向出口／出生点防反跳与跨区入口登记。使用 1600×1000、1440×900 两套 GUI 截图。

## 交付门槛

- 提交按统一世界比例生产的分层贴图、必要的可编辑母版、**原始提示词和绑定的 Godot Resource**；已原生化地图额外交付可在 Godot 直接打开的 `.tscn` 及其关联 `.tres`，明确几何同步状态。候选与使用中是唯一素材状态；不另建审批状态或重复的版本来源表。
- 自动检查必需图层存在、可解码、共享同一原点与**当前场景 Resource 声明的真实世界画布尺寸**且引用可加载：单屏为 1600×1000，纵向长图可为 1600×2000／1600×2400 等（全部图层与 `WuxiaSceneArtProfile.reference_size`、相应 Map/Chapter 世界尺寸一致）。1600×1000／1440×900 为 GUI 视口截图验证尺寸，不是长图贴图的统一硬限制；人工检查透视、脚点、六人站位、遮挡、性能与授权。
- 单张概念场景不能代替分层地图；原稿保留 candidate，导入并绑定到地图 Resource 后成为当前 `in_use`，先预检与备份再切换。视觉与权属审核独立记录，不另建 `approved` 状态。
- 汇报未解决的几何/遮挡问题和待冻结参数，不自行修改战斗规则或地图拓扑以迁就画面。
