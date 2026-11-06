---
name: wuxia-asset-pipeline
description: "为《长风浮生录》检查美术素材规格、盘点在用资源、审核候选、准备 Godot 原生 Resource／SpriteFrames／场景导入及批准替换时使用；管理 art-production 与游戏资产之间的可追溯关系。"
---

# 美术素材验收、归档与原生接入

## 单一事实来源

- 先读取 art-production/standards/ART_PRODUCTION_STANDARD.md、[Godot 原生内容开发规范 V2](../../../docs/GODOT_NATIVE_AUTHORING_STANDARD.md)、art-production/templates/asset-work-order.md；对 AI 候选再读 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md。
- art-production 是制作、审核、索引和交付区，不是运行时自动扫描目录。游戏的角色、地图、物品和武学由 Godot 原生 .tres Resource 及 data/content_manifest.tres 管理。
- 素材管理仅有 `candidate` 与 `in_use` 两种状态；候选数量不限，同一原生 Resource 槽位只有一个当前在用绑定。**候选通过技术预检仍须完成该素材必要的视觉／权属人工验收并明确批准，才允许替换正式在用素材**；批准结论记录在工作单中，不新增 `approved` 管理状态。实际显式导入并绑定后才成为 `in_use`，`in_use` 本身不代表已通过美术质量审核。
- 已有图像能正常通过合同则不强制返工；历史文件仅在确认无运行时引用后归档，不重新接入旧路径。原生 Resource 是唯一真值，不建立 JSON/YAML 运行时配置。
- 绘图提示词只取 `prompts/ART_STYLE_AI_PROMPTS_V1.md` 中目标类别的短模板和参考图；**Agent 先决定素材类别、角色尺寸档位、帧数、构图和所有可选项，填成唯一确定版后再调用生图模型**。不得传入未替换占位符、`A/B` 选项或让生图模型自行选规格；机器校验细则只用于导入预检。工作单记录**实际发送的提示词**，不另附整套风格规范、失败清单或长负面词表。

## 可重复流程

1. **发现与归档**：从实际游戏 Resource/scene/脚本读取当前绑定；仅使用中素材进入清单。执行 `python3 art-production/tools/inventory_assets.py --check` 检查静态引用与镜像；按文件名自动解析的 Resource 图片须以 Godot Dock「全部实际使用图片」导出预检为准。其他未用素材按原始身份放在候选或归档区。
2. **创建候选包**：在 `art-production/candidates/<asset-type>/<asset-id>/` 保留候选及实际发送的短提示词，记录目标 `.tres`／`.tscn`。角色动画先按 `action_id` 留完整分镜与真实 N：**AI Sheet 路径**按 **5×5、25 格**保存原始 Sheet、实际尺寸、批次编号和 `cell_index(0..24) -> action_id + action_frame_index`，普通档单格 328×256／整图 1640×1280，高个档 384×288／整图 1920×1440；**逐动作 GIF 路径**每动作一份透明 GIF，声明实际完整单帧尺寸和 `action_id`，**不虚构 C×R 网格**。同角色同档。运行 `python3 art-production/tools/sync_candidate_resources.py` 或使用 Native GIF Dock 登记每张候选的 `WuxiaArtCandidateDefinition.tres`，真实尺寸和网格不得虚报。候选不加入 Manifest；不增加 JSON 运行时定义。
3. **两级技术校验**：先逐动作核对 12 组正式美术分镜、`weapon_contract`、源身高 100px/米；再按来源检查：AI Sheet 必须有固定 5×5 格位及 25 格帧映射，先共同等比标准化／透明补边，再机械拆格，验证 Alpha、至少 8px 留白、零越格、空格透明与跨批连续；逐动作 GIF 核对完整 W×H 画布、逐帧真实 Alpha、时长与独立动作身份，不执行 5×5 拆格。禁止非等比拉伸、逐帧缩放、紧裁或隐式补损失像素；实际播放检查模型／武器／O、循环、收势及 `defeat` 终帧。**优先使用已验证的原生 `SpriteFrames.tres` 路径；现有 5×5 Atlas 导入器若尚不能直接生成 SpriteFrames，保留显式 `action_id -> ordered absolute frame_indices` 兼容输出或在 Godot 人工装配并验收，不冒充自动转换已经完成**。混合源图不得直接当一个 Clip，旧动作名无隐式 fallback。其他素材检查 Alpha、依赖和尺寸；未见 Godot 实速证据，不报告动画完成。
4. **原生导入**：角色 `WuxiaCharacterDefinition.animation_profile` 引用 `WuxiaActorAnimationProfile`，新动画经 `native_frames` 引用 `SpriteFrames.tres`，旧 Clip 仅作兼容；场景纹理由 `WuxiaSceneArtProfile`／地图或章节 Resource 引用，已迁移探索几何在 `.tscn` 编辑并显式同步 `.tres`，战斗合法区域仍归地图 Resource，HUD／VFX 交付原生 `.tscn`。按 `assets/imported/README.md` 的语义目录安装，空纹理槽位按身份精确解析，Inspector 手动指定优先；非法引用和缺失必需图直接报错。导入前显示修改路径和范围，保护保存后的 `.tscn`／`SpriteFrames` 手工微调，保留哈希／事务备份／撤销；只有完成必要人工批准才替换已有 `in_use`。Content Manifest 登记正式定义，不给 BattleModel 添加特判。
5. **验证**：可运行时执行 godot --headless --path demos/changfeng-battle --editor --import --quit，并运行相关项目检查；随后必须在 Godot Editor 实测动画、场景、遮挡、点击与导出，留存 1600×1000 和 1440×900 GUI 截图。headless 成功不等于美术验收。
6. **切换使用版本**：在候选完成技术预检及必要的视觉／权属验收、明确批准替换目标后，使用导入器预检、版本化替换及事务备份，将该候选切换为 Resource 当前使用的唯一图像；未使用版本留在候选区。保留旧绑定以便撤销，切换后运行原有验证；不因本流程额外添加管理状态，也不重绘合格素材。

## 输出与停止条件

- 输出当前使用中 Resource 引用、合同不合格项与实际执行的验证结果；缺少人工试玩时只说明尚未执行，不增加管理状态。
- 素材生成与使用合同仍遵循对应专业 Skill；版权事宜作为发行前事项独立处理。
- 对现有运行图的替换、删除或移动必须明确目标、可回退路径和审核授权；不要擅自清除历史素材。
