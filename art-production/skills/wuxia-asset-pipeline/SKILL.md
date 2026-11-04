---
name: wuxia-asset-pipeline
description: "为《长风浮生录》检查美术素材规格、盘点在用资源、审核候选、准备 Godot 原生 Resource 导入及批准替换时使用；管理 art-production 与游戏资产之间的可追溯关系。"
---

# 美术素材验收、归档与原生接入

## 单一事实来源

- 先读取 art-production/standards/ART_PRODUCTION_STANDARD.md、art-production/templates/asset-work-order.md；对 AI 候选再读 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md。
- art-production 是制作、审核、索引和交付区，不是运行时自动扫描目录。游戏的角色、地图、物品和武学由 Godot 原生 .tres Resource 及 data/content_manifest.tres 管理。
- 素材管理仅有 `candidate` 与 `in_use` 两种：候选数量不限，同一原生 Resource 槽位只能绑定一个使用中的版本。符合既有 Godot 合同即可使用，无额外人工批准门槛。
- 已有图像能正常通过合同则不强制返工；历史文件仅在确认无运行时引用后归档，不重新接入旧路径。原生 Resource 是唯一真值，不建立 JSON/YAML 运行时配置。

## 可重复流程

1. **发现与归档**：从实际游戏 Resource/scene/脚本读取当前绑定；仅使用中素材进入清单。执行 `python3 art-production/tools/inventory_assets.py --check` 检查静态引用与镜像；按文件名自动解析的 Resource 图片须以 Godot Dock「全部实际使用图片」导出预检为准。其他未用素材按原始身份放在候选或归档区。
2. **创建候选包**：在 art-production/candidates/<asset-type>/<asset-id>/ 保存候选图及提示词，标明要绑定的正式 Resource；角色动画按 `action_id` 保存分镜、多帧 Sheet 及**实际发送的简版提示词**（记录 N、C、R、格宽高和帧序），便于只对失败片段定向重试。按需要保留多个版本，不重复记录模型/seed/审批字段。随后运行 `python3 art-production/tools/sync_candidate_resources.py`，为每张候选图片在 `data/art_candidates/` 生成独立 Godot `WuxiaArtCandidateDefinition.tres`；编辑候选 `.tres` 记录实际像素、声明网格、脚点及站姿可见高度，生成器不得覆盖已有人工配置。候选 `.tres` 绝不加入 Manifest。
3. **两级技术校验**：先按 `standards/SPRITE_ANIMATION_QA.md` **逐动作**核对 12 组分镜与当前角色 `weapon_contract`（允许徒手、单持、双持或双手握持）；每张 AI 生成的多帧 Sheet 需按预先声明的 C×R 网格进行确定性拆格，检查 N 个有效帧、尺寸整除、每格真 Alpha/完整轮廓/足够留白、未用格透明、零跨格侵入。然后按帧序预览相同基准模型/O、动作连续性、循环首尾及非循环复位（defeat 终止态除外）；失败则重生对应连续多帧组，不能靠自动识别动作边界。仅将通过预检的帧装配为运行时 Atlas，核对统一根锚点、各动作有序绝对帧索引、列行整除与空格全透明；**自动拒绝重叠、越界、边距不足、错序或索引错误**。AI 视觉仅初筛，不能自动识别真实支撑脚/动作阶段/根位移，视频提帧尚未真实验收；疑难与最终少量样片再人工复核。Godot 现在支持 `idle/walk/run/attack1-4/skill/evade/guard/hit/defeat` 共 12 个动作 ID，允许 Skill 绑定单一动作和独立 VFX Cue；老 `move/attack/combo` 只在原生 Profile 明确声明时生效，不能隐式代替缺失配置。没有 Godot 实速播放证据，不得报告动画视觉完成。其他素材仍检查解码、真实 Alpha、纹理与文件名、场景 ground/同画布分层及依赖；地图验证 `pixels_per_unit=80`、贴图 1:1、角色 200px 比例，参考 `standards/TOWN_MAP_SCALE_PRODUCTION.md`；不要把建议尺寸或 FPS 宣称已冻结。
4. **原生导入**：角色由 WuxiaActorAnimationProfile/WuxiaCharacterDefinition.animation_profile 引用，场景由 WuxiaSceneArtProfile 和 WuxiaMapDefinition/WuxiaGridMapDefinition.scene_art 引用；素材按 `assets/imported/README.md` 的固定目录与语义文件名安装，空的纹理槽位按身份精确自动解析，Inspector 手动指定优先；非法引用和缺失的必需图直接报错。已导入并由 Resource 绑定的版本即为 `in_use`，无需另建状态目录。Content Manifest 登记对应正式内容，不给 BattleModel 添加特殊分支。
5. **验证**：可运行时执行 godot --headless --path demos/changfeng-battle --editor --import --quit，并运行相关项目检查；随后必须在 Godot Editor 实测动画、场景、遮挡、点击与导出，留存 1600×1000 和 1440×900 GUI 截图。headless 成功不等于美术验收。
6. **切换使用版本**：用导入器预检、版本化替换及事务备份，把选中候选切换为 Resource 当前使用的唯一图像；未使用版本仍留在候选区。导入前保存旧绑定以便撤销，切换后运行原有验证，不重绘合格素材。

## 输出与停止条件

- 输出当前使用中 Resource 引用、合同不合格项与实际执行的验证结果；缺少人工试玩时只说明尚未执行，不增加管理状态。
- 素材生成与使用合同仍遵循对应专业 Skill；版权事宜作为发行前事项独立处理。
- 对现有运行图的替换、删除或移动必须明确目标、可回退路径和审核授权；不要擅自清除历史素材。
