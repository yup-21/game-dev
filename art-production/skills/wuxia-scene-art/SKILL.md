---
name: wuxia-scene-art
description: "为《长风浮生录》设计、生成、拆分或审核剧情与战斗地图美术时使用；落实 1600×1000 分层贴图、镜头与脚点、遮挡和 Godot WuxiaSceneArtProfile/WuxiaMapDefinition 资源合同。"
---

# 武侠场景分层制作

## 依据

- 先读取 art-production/standards/ART_PRODUCTION_STANDARD.md 的场景合同；AI 制作时读取 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md 的场景提示词。
- 复制 art-production/templates/asset-work-order.md 至 art-production/candidates/YYYY-MM-DD/<asset-id>/WORK_ORDER.md，记录参考母图、镜头、色板、地标、原点、图层、版权和版本。
- 全游戏采用原创手绘自然材质、固定镜头、清晰地面空间及真实前后景遮挡；不用 3D 棋盘叠加背景伪造场景。

## 制作流程

1. **构图合同**：以 1600×1000、16:10 逻辑画布确定镜头、地平线、人物比例、地面脚点、可走区域和固定地标；同时规划 1440×900 的裁切表现。
2. **先出概念母版**：明确主角、敌人、NPC 的站位及路线。战斗场景需支持至少六人清晰分布；地图可走区、视觉障碍、前景装饰要分离。整张概念图不是可运行地图。
3. **分层交付**：以同一画布原点和尺寸输出 background（远景，必需）、ground（可站立地面，必需）、foreground（可遮挡，按需）、weather（雨雾等，按需）；不属于当前图层的像素使用真实透明 Alpha。保留可编辑分层母版。
4. **保持空间合同**：所有地标在各层的坐标一致，前景对象可在 Node2D 层独立遮挡角色；雨、雾、灯光等表现层可关闭，且关闭后不影响路径、LOS、出生点或触发区域。
5. **接入 Godot**：创建/更新 WuxiaSceneArtProfile，reference_size 与各贴图尺寸统一为 1600×1000；将其挂到战斗地图 WuxiaMapDefinition / WuxiaGridMapDefinition.scene_art，或剧情章节 WuxiaChapterSceneDefinition.scene_art。前景/天气在剧情探索阶段独立渲染，剧情对白不遮挡 UI。障碍、地面、出生点、剧情标记与碰撞由原生资源定义；绝不依赖 PNG 颜色推断碰撞。
6. **核验对位**：在 Godot Editor 中按剧情和战斗玩法实际移动角色，检查脚点、道路边缘、遮挡顺序、地图碰撞与美术对应，并使用 1600×1000、1440×900 两套 GUI 截图。

## 交付门槛

- 提交概念母版、每层贴图、可编辑工程、WORK_ORDER.md、坐标约定及 Godot 截图，保留原始提示词/修订记录。
- 自动检查所有必需层存在、可解码、每层为同一 1600×1000 画布、Resource 引用可加载；人工检查透视、脚点、六人站位、遮挡、性能与授权。
- 单张概念场景不作为 approved；技术合格进入 candidate，人工审查通过后方可批准并替换正式地图素材。
- 汇报未解决的几何/遮挡问题和待冻结参数，不自行修改战斗规则或地图拓扑以迁就画面。
