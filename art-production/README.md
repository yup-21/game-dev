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
| [库存清单工具](tools/inventory_assets.py) | 按需生成使用中 Resource 引用清单，不是第二套运行配置；`inventory/` 为按需生成的输出目录，可能尚不存在 |
| [in-use/](in-use/) | 当前 Resource 绑定素材的分类镜像，按类型与拥有者聚合 |
| [tools/](tools/) | 离线库存工具与 Godot 导入导出指南 |

Skills 的 `SKILL.md` 遵循 Agent Skills 的 `name` / `description` YAML frontmatter 规范，详细工作规则由对应 Skill 在使用时按需加载；修改 Skill 只编辑本目录，不维护第二套副本。

## 精灵帧固定点标注与自动重排

- [交互式离线编辑器](tools/sprite-anchor-editor.html)：导入 PNG/WebP 多格图或独立帧，逐帧点击支撑点，按统一坐标和可设定透明边距重排，播放动画并导出 Atlas PNG、脚点 CSV、离线索引 JSON。
- [使用指南与限制](tools/SPRITE_ANCHOR_EDITOR.md)：包含沈长风 v05 多图导入方式、逐帧人工复核、与旧脚本的 CSV 接口区别。工具仅用于 candidate 美术制作，不改变正式 Godot 原生绑定。

## 精灵动作生产与失败返工

- [逐帧/视频/3D 渲染统一质量合同](standards/SPRITE_ANIMATION_QA.md)：集中列出身份变形、侧视角、承重脚、根位移、断剑/越格、Alpha 闪烁、真实补帧、Atlas 装配及 Godot 实速验收的返工闸门。
- 角色生成时调用 `skills/wuxia-character-art`，审核和原生资源接入调用 `skills/wuxia-asset-pipeline`；已有脚点编辑器仍负责候选标注与无损打包。
- 默认先**逐动作规划实际帧数**。**AI Sheet 路径**将各动作连续填入固定 5×5（25 格）批次，普通档标准化后单格 **328×256px**／整图 **1640×1280px**，高个档 384×288／1920×1440；先验 5×5 布局，再统一等比缩放／补透明边距并机械拆格。**逐动作 GIF 路径**每动作一份完整透明 GIF，按单帧 W×H 与真实时长验收，不用 5×5 网格。合格帧优先经已验证的工具或 Godot 编辑器交付 `SpriteFrames.tres`；当前旧 Atlas 导入器仍可交付 Clip 兼容资源，不能宣称混合 Sheet 已支持自动导出 SpriteFrames。角色／武器越格、帧序或 Alpha 边距错误仍需返工，不能拉伸／紧裁；视频提帧与脚点自动语义识别尚未真实验收。

## 目录组织

- `candidates/characters/<actor-id>/`：角色设定、立绘、动作图集和不同候选版本。`baseline/` 为原始生产稿，后续可使用 `sprite-vNN/` 或按动作 `animations/<action-id>/`；不要按日期建目录。
- **候选原生 Resource**：`demos/changfeng-battle/data/art_candidates/` 按 `candidates/` 的分类与原图片文件名一一对应保存 `.tres`；调用 `python3 art-production/tools/sync_candidate_resources.py` 补齐，`--check` 检查缺漏。候选可编辑原始像素尺寸、网格、脚点、参考可见身高及预览比例，但不会成为 Content Manifest 的运行时绑定。
- `candidates/scenes/<scene-id>/`：场景母版、分层图、技术验证版。
- `candidates/vfx/<actor-id>/<skill-id>/`：对应技能特效；多个技能共用的图集可集中在 `martial-forms/` 等明确命名的集合内。
- `candidates/ui/<component-id>/`：界面分件和图标。旧批次清单、提示词放 `candidates/records/`，不构成新状态。
- `in-use/characters|scenes|vfx|ui|placeholders/`：只保存正式 Resource 当前引用的图片原字节镜像；游戏侧统一使用 `assets/imported/<type>/<owner>/`，**不再按候选/使用中划分目录**。少量仅供编辑器预览的旧图与正式图片同处分类目录，但没有正式游戏绑定，其原稿仍归 `candidates/`。
- `assets/imported/` 是纳入版本控制的原始图片所在目录；Godot 自动生成的 `.godot/imported/` 是可重建缓存，不作为素材管理目录。
- 历史 `archive/` 保持原样以便追溯；日期可以是工作单元数据，不是新目录键。

导入到 Godot 的统一文件名范式见 [`assets/imported/README.md`](../demos/changfeng-battle/assets/imported/README.md)：角色和技能目录按稳定 ID 聚合，`portrait/atlas/background/ground` 等主文件采用固定语义名，Resource 手动绑定优先。

## 核心约束

1. 游戏方向为原创国风手绘、原生 2D 与具有纵深和遮挡的 HD-2D 构图；不强制低像素。
2. 素材生成与使用规格仍以既有分类美术 Skill 和技术合同为准，不因管理精简而降低要求。
3. 管理只区分 `candidate`（可以有多个）和 `in_use`（每个 Resource 槽位只有一个当前绑定）。技术预检与**必要的视觉／权属人工审核**均需完成并明确批准替换目标，才可切换已有在用美术；审批结果写在工作单，不另建 `approved` 状态。
4. 来源记录只维护**提示词及对应原生 Resource**，不要求模型版本、seed、审批链或重复 JSON 台账；未知历史提示词保持空白。
5. 游戏美术统一从 `res://assets/imported/` 加载；原旧 `assets/` 目录已迁移或归档到 `art-production/archive/`，旧路径不再是运行时入口。
6. `art-production/tools/inventory_assets.py --check` 检查已绑定的图片文件与路径；`--write` 可按需生成仅包含使用中图片的清单，原生 Resource 始终为唯一真值。

## 兼容说明

**单一维护来源**：正式美术与动画生产规则只维护 `art-production/standards/`，跨领域运行时编辑与交付接口只维护 [`docs/GODOT_NATIVE_AUTHORING_STANDARD.md`](../docs/GODOT_NATIVE_AUTHORING_STANDARD.md)；`docs/ART_PRODUCTION_STANDARD.md` 与 `docs/ART_STYLE_AI_PROMPTS_V1.md` 仅是兼容旧链接的历史入口，禁止再复制、同步修改另一份规则正文。

## 城镇与大地图生成

使用 [城镇分区与世界比例尺规范](standards/TOWN_MAP_SCALE_PRODUCTION.md) 制作城镇、街道和室内地图。**1 世界单位 = 80 世界像素；普通人物站立高度 200px**。运行时仍使用 Godot 原生地图和分层 Resource，城镇采用 1600×1000 单屏分区生产，支持横向、纵向、十字交叉街区；纵向不旋转画布、不缩小角色，不强制生成巨型一张图。

画面构图前用 `python art-production/tools/scene_scale_guide.py --output /tmp/town_scale.png` 生成透明角色、门洞和地面比例尺参照层；纵向街道使用 `--orientation vertical`，十字街口使用 `--orientation mixed`。AI 的提示词只能约束方向，最终需在 Godot 中检验人物与建筑实际比例。

## 第一批生产试点

沈长风（设定、立绘、12 组动作）、追兵首领、雨夜断桥分层场景、核心 VFX、物品图标、武学卡面与 CTB/UI 分件。技术导入不等于艺术批准；正式替换需完成必要视觉／权属审核，持续视觉精修可作为后续独立制作任务。

- [2026-11-01 四项优先试点工作单](candidates/records/pilot/README.md)：包含剧情场景分层与准确的原生资源目标。
- [运行时代码与存量美术格式差异/验收状态](reviews/2026-11-01/FORMAT_UNIFICATION_STATUS.md)：明确代码已打通但历史图像尚不等于最终批准资产。

## Godot 原生素材导入与导出

Godot 编辑器内的 **Art Production** Dock 提供图像导出、Atlas 与场景分层导入、批次预检、版本化替换及事务回退；**Native GIF** Dock 将逐动作 GIF 转成原生 `SpriteFrames.tres`。正式内容通过 `.tres`、已绑定的 `.tscn` 和 Content Manifest 运行，离线清单不充当内容定义；编辑权见 [V2 规范](../docs/GODOT_NATIVE_AUTHORING_STANDARD.md)。

参见 [Godot 导入/导出指南](tools/GODOT_IMPORTER.md)。导入且绑定到正式 Resource 的图片就是当前使用版本；候选原稿仍在 `candidates/`，不会随导入改名。Asset Resource 标记为 `runtime`，表示已接入，不代表动作、脚点或权属已审核。所有正式必需引用必须可解析，不能靠隐式旧图或占位回退。导出 Dock 会补齐按语义文件名自动绑定的图片，`inventory_assets.py` 仅负责静态引用库存。
