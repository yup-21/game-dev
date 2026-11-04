# 《长风浮生录》美术生产工作区

本目录是全游戏美术制作的统一入口，供 AI 生成、人工修改、审核及批量生产使用，**不是 Godot 运行时自动扫描目录**。

| 目录 | 用途 |
| --- | --- |
| [standards/](standards/) | 美术、动画、场景与资源质量规范 |
| [prompts/](prompts/) | 可复制的 AI 生成母提示词与分类模板 |
| [templates/](templates/) | 每次资产制作都需填写的工作单 |
| [skills/](skills/) | 角色、场景、VFX、UI、审核导入的仓库级 Agent Skills；通过仓库根目录 `.agents/skills` 软连接自动发现 |
| [candidates/](candidates/) | 按角色、场景、技能、UI 分类的候选资产；同一 ID 的版本放在一起 |
| [reviews/](reviews/) | 人工验收、截图与批准记录 |
| [inventory/](inventory/) | 按需生成的使用中 Resource 引用清单，不是第二套运行配置 |
| [in-use/](in-use/) | 当前 Resource 绑定素材的分类镜像，按类型与拥有者聚合 |
| [tools/](tools/) | 离线库存工具与 Godot 导入导出指南 |

Skills 的 `SKILL.md` 遵循 Agent Skills 的 `name` / `description` YAML frontmatter 规范，详细工作规则由对应 Skill 在使用时按需加载；修改 Skill 只编辑本目录，不维护第二套副本。

## 精灵帧固定点标注与自动重排

- [交互式离线编辑器](tools/sprite-anchor-editor.html)：导入 PNG/WebP 多格图或独立帧，逐帧点击支撑点，按统一坐标和可设定透明边距重排，播放动画并导出 Atlas PNG、脚点 CSV、离线索引 JSON。
- [使用指南与限制](tools/SPRITE_ANCHOR_EDITOR.md)：包含沈长风 v05 多图导入方式、逐帧人工复核、与旧脚本的 CSV 接口区别。工具仅用于 candidate 美术制作，不改变正式 Godot 原生绑定。

## 精灵动作生产与失败返工

- [逐帧/视频/3D 渲染统一质量合同](standards/SPRITE_ANIMATION_QA.md)：集中列出身份变形、侧视角、承重脚、根位移、断剑/越格、Alpha 闪烁、真实补帧、Atlas 装配及 Godot 实速验收的返工闸门。
- 角色生成时调用 `skills/wuxia-character-art`，审核和原生资源接入调用 `skills/wuxia-asset-pipeline`；已有脚点编辑器仍负责候选标注与无损打包。
- 默认先规划动作分镜和真实帧数 N，再让 AI **每次输出一张包含多个连续姿势的透明动作 Sprite Sheet**。预先声明 C×R 等尺寸网格和宽透明留白；程序按固定格子机械切分，检查 N、边界、空格透明与**零重叠、正透明边距、无裁切**，通过后才装配运行时 Atlas。图像模型并不能保证按格准确绘画，违规需重生 Sheet/连续多帧片段。视频工具与脚点自动语义识别均未完成真实验收。

## 目录组织

- `candidates/characters/<actor-id>/`：角色设定、立绘、动作图集和不同候选版本。`baseline/` 为原始生产稿，后续可使用 `sprite-vNN/` 或按动作 `animations/<action-id>/`；不要按日期建目录。
- `candidates/scenes/<scene-id>/`：场景母版、分层图、技术验证版。
- `candidates/vfx/<actor-id>/<skill-id>/`：对应技能特效；多个技能共用的图集可集中在 `martial-forms/` 等明确命名的集合内。
- `candidates/ui/<component-id>/`：界面分件和图标。旧批次清单、提示词放 `candidates/records/`，不构成新状态。
- `in-use/characters|scenes|vfx|ui|placeholders/`：只保存运行时实际引用的图片原字节；游戏侧对应 `assets/imported/in-use/`。候选预览保存在游戏侧 `assets/imported/candidates/`，按角色/图片类型、场景、技能或 UI 组件分类，不继承生产稿的日期/批次目录。
- `assets/imported/` 是纳入版本控制的原始图片所在目录；Godot 自动生成的 `.godot/imported/` 是可重建缓存，不作为素材管理目录。
- 历史 `archive/` 保持原样以便追溯；日期可以是工作单元数据，不是新目录键。

## 核心约束

1. 游戏方向为原创国风手绘、原生 2D 与具有纵深和遮挡的 HD-2D 构图；不强制低像素。
2. 素材生成与使用规格仍以既有分类美术 Skill 和技术合同为准，不因管理精简而降低要求。
3. 管理只区分 `candidate`（可以有多个）和 `in_use`（每个 Resource 槽位只有一个当前绑定）。通过原生合同即可使用，技术接入不另设审批状态。
4. 来源记录只维护**提示词及对应原生 Resource**，不要求模型版本、seed、审批链或重复 JSON 台账；未知历史提示词保持空白。
5. 游戏美术统一从 `res://assets/imported/` 加载；原旧 `assets/` 目录已迁移或归档到 `art-production/archive/`，旧路径不再是运行时入口。
6. `art-production/tools/inventory_assets.py --check` 检查已绑定的图片文件与路径；`--write` 可按需生成仅包含使用中图片的清单，原生 Resource 始终为唯一真值。

## 兼容说明

本目录保存独立副本以便美术团队直接浏览。旧正式文档 `docs/ART_PRODUCTION_STANDARD.md` 与 `docs/ART_STYLE_AI_PROMPTS_V1.md` 目前仍保留，避免打断已发布链接。后续版本应同步更新，不要静默让两份规范分叉。

## 城镇与大地图生成

使用 [城镇分区与世界比例尺规范](standards/TOWN_MAP_SCALE_PRODUCTION.md) 制作城镇、街道和室内地图。**1 世界单位 = 80 世界像素；普通人物站立高度 200px**。运行时仍使用 Godot 原生地图和分层 Resource，城镇采用 1600×1000 单屏分区生产，支持横向、纵向、十字交叉街区；纵向不旋转画布、不缩小角色，不强制生成巨型一张图。

画面构图前用 `python art-production/tools/scene_scale_guide.py --output /tmp/town_scale.png` 生成透明角色、门洞和地面比例尺参照层；纵向街道使用 `--orientation vertical`，十字街口使用 `--orientation mixed`。AI 的提示词只能约束方向，最终需在 Godot 中检验人物与建筑实际比例。

## 第一批生产试点

沈长风（设定、立绘、九类动作）、追兵首领、雨夜断桥分层场景、核心 VFX、物品图标、武学卡面与 CTB/UI 分件。素材通过原生合同即可投入使用；视觉精修是独立制作任务。

- [2026-11-01 四项优先试点工作单](candidates/records/pilot/README.md)：包含剧情场景分层与准确的原生资源目标。
- [运行时代码与存量美术格式差异/验收状态](reviews/2026-11-01/FORMAT_UNIFICATION_STATUS.md)：明确代码已打通但历史图像尚不等于最终批准资产。

## Godot 原生素材导入与导出

Godot 4.7.2 编辑器内的 **Art Production** Dock 提供引用图像导出、角色动画与场景分层导入、批次预检、版本化替换和事务回退。运行时仍只读取 `.tres` Resource，离线清单不充当内容定义。

参见 [Godot 导入/导出指南](tools/GODOT_IMPORTER.md)。新导入资源默认 `candidate`，未经人工审查不得标记为 `approved`。本轮审核分支将候选资源接入原生角色卡及地图供试玩；历史原图已按使用情况迁入 imported 或 archive；保留既有回退素材。
