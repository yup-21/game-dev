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
- 绘图提示词只取 `prompts/ART_STYLE_AI_PROMPTS_V1.md` 中目标类别的短模板和参考图；**Agent 先决定素材类别、角色尺寸档位、帧数、构图和所有可选项，填成唯一确定版后再调用生图模型**。不得传入未替换占位符、`A/B` 选项或让生图模型自行选规格；机器校验细则只用于导入预检。工作单记录**实际发送的提示词**，不另附整套风格规范、失败清单或长负面词表。

## 可重复流程

1. **发现与归档**：从实际游戏 Resource/scene/脚本读取当前绑定；仅使用中素材进入清单。执行 `python3 art-production/tools/inventory_assets.py --check` 检查静态引用与镜像；按文件名自动解析的 Resource 图片须以 Godot Dock「全部实际使用图片」导出预检为准。其他未用素材按原始身份放在候选或归档区。
2. **创建候选包**：在 `art-production/candidates/<asset-type>/<asset-id>/` 保留候选及实际发送的短提示词，记录目标 `.tres`。角色动画先按 `action_id` 留完整分镜/真实 N，再按 **5×5、25 格**的混合动作批次保存原始 Sheet、源图实际尺寸、批次编号和 `cell_index(0..24) -> action_id + action_frame_index`。普通角色标准化目标单格 328×256/整图 **1640×1280**；高个档例外 384×288/整图 **1920×1440**，一角色保持同档。生成后运行 `python3 art-production/tools/sync_candidate_resources.py` 为候选图片生成独立 `WuxiaArtCandidateDefinition.tres`；在候选 Resource 声明真实像素与网格，未标准化原图**不得伪报**目标尺寸。候选不加入 Manifest；不增加第二套 JSON 运行时定义。
3. **两级技术校验**：先逐动作核对 12 组分镜、`weapon_contract`、源身高 100px/米；再逐批核对 AI 原图是否真有固定 **5×5** 格位、指定的 25 格动作/帧映射。由于生图接口不保证像素尺寸，原图先按共同等比变换与透明补边做尺寸标准化，禁止非等比拉伸、逐帧缩放、紧裁/居中或隐式补丢失的像素。标准化后按 328×256（批准高个档用 384×288）机械拆格，检查 Alpha、至少 8px 留白、零越格、末批空格透明及各动作跨批连续。然后按实际帧序播放检查模型/武器/O、循环或收势，`defeat` 停留倒地；失败返工源 Sheet，技术校验不能替代语义识别。仅把通过的切片装配为运行时 Atlas，显式生成 `action_id -> ordered absolute frame_indices`；一个源图中多个动作**不能**作为一个 Clip 直接导入。Godot 支持 `idle/walk/run/attack1-4/skill/evade/guard/hit/defeat`；旧动作名不作为隐式 fallback。其他素材检查原有 Alpha、依赖与尺寸合同；未见 Godot 实速证据，不报告动画完成。
4. **原生导入**：角色由 WuxiaActorAnimationProfile/WuxiaCharacterDefinition.animation_profile 引用，场景由 WuxiaSceneArtProfile 和 WuxiaMapDefinition/WuxiaGridMapDefinition.scene_art 引用；素材按 `assets/imported/README.md` 的固定目录与语义文件名安装，空的纹理槽位按身份精确自动解析，Inspector 手动指定优先；非法引用和缺失的必需图直接报错。已导入并由 Resource 绑定的版本即为 `in_use`，无需另建状态目录。Content Manifest 登记对应正式内容，不给 BattleModel 添加特殊分支。
5. **验证**：可运行时执行 godot --headless --path demos/changfeng-battle --editor --import --quit，并运行相关项目检查；随后必须在 Godot Editor 实测动画、场景、遮挡、点击与导出，留存 1600×1000 和 1440×900 GUI 截图。headless 成功不等于美术验收。
6. **切换使用版本**：用导入器预检、版本化替换及事务备份，把选中候选切换为 Resource 当前使用的唯一图像；未使用版本仍留在候选区。导入前保存旧绑定以便撤销，切换后运行原有验证，不重绘合格素材。

## 输出与停止条件

- 输出当前使用中 Resource 引用、合同不合格项与实际执行的验证结果；缺少人工试玩时只说明尚未执行，不增加管理状态。
- 素材生成与使用合同仍遵循对应专业 Skill；版权事宜作为发行前事项独立处理。
- 对现有运行图的替换、删除或移动必须明确目标、可回退路径和审核授权；不要擅自清除历史素材。
