# 《长风浮生录》美术生产工作区

本目录是全游戏美术制作的统一入口，供 AI 生成、人工修改、审核及批量生产使用，**不是 Godot 运行时自动扫描目录**。

| 目录 | 用途 |
| --- | --- |
| [standards/](standards/) | 美术、动画、场景与资源质量规范 |
| [prompts/](prompts/) | 可复制的 AI 生成母提示词与分类模板 |
| [templates/](templates/) | 每次资产制作都需填写的工作单 |
| [skills/](skills/) | 角色、场景、VFX、UI、审核导入的仓库级 Agent Skills；通过仓库根目录 `.agents/skills` 软连接自动发现 |
| [candidates/](candidates/) | 后续生成的概念图和待审批图；按批次、类型存放 |
| [reviews/](reviews/) | 人工验收、截图与批准记录 |

Skills 的 `SKILL.md` 遵循 Agent Skills 的 `name` / `description` YAML frontmatter 规范，详细工作规则由对应 Skill 在使用时按需加载；修改 Skill 只编辑本目录，不维护第二套副本。

## 核心约束

1. 游戏方向为原创国风手绘、原生 2D 与具有纵深和遮挡的 HD-2D 构图；不强制低像素。
2. 角色 identity、场景镜头、色板和材质必须先冻结参考，再出变体。所有 AI 候选保存模型版本、提示词、参考图、修改记录及权属。
3. 候选放在 `candidates/YYYY-MM-DD/<asset-id>/`，源图和编辑母版保留。文件名建议 `<asset-type>_<asset-id>_<variant>_vNN.png`。人工批准前不可覆盖正式运行素材。
4. 角色最终 Atlas / 场景贴图在通过审核后，按 Godot 原生资源接口接入 `demos/changfeng-battle/assets/` 和相应 `.tres`，并加入正式 Content Manifest。**不要用这里的 JSON/YAML 工作单替代原生运行时定义**。
5. 因为当前游戏已有资源引用，旧 `demos/changfeng-battle/assets/concepts/` 中的历史素材**暂不搬迁**；保持其路径和可追溯性。新批次统一进入本目录。
6. `candidate` 表示待审核，`runtime` 表示可加载，不等于 `approved`；批准需技术、视觉、实机、授权共同通过。

## 兼容说明

本目录保存独立副本以便美术团队直接浏览。旧正式文档 `docs/ART_PRODUCTION_STANDARD.md` 与 `docs/ART_STYLE_AI_PROMPTS_V1.md` 目前仍保留，避免打断已发布链接。后续版本应同步更新，不要静默让两份规范分叉。

## 第一批生产试点

沈长风（设定、立绘、九类动作）、追兵首领、雨夜断桥分层场景、核心 VFX、物品图标、武学卡面与 CTB/UI 分件。所有候选经过人工批准，才可以冻结 V2 规格。
