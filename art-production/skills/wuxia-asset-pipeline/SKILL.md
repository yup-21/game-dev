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

1. **发现与归档**：从实际游戏 Resource/scene/脚本读取当前绑定；仅使用中素材进入清单。执行 `python3 art-production/tools/inventory_assets.py --check` 检查旧路径与缺图，其他未用素材放入 `art-production/archive/`。
2. **创建候选包**：在 art-production/candidates/YYYY-MM-DD/<asset-id>/ 保存候选图及提示词，标明要绑定的 Resource；按需要保留多个版本，不重复记录模型/seed/审批字段。
3. **技术校验**：检查解码、真实 Alpha（角色和 VFX 必需）、纹理尺寸、Atlas 整除和帧索引、脚点、动作末帧复位/终止、场景必需 ground 及同画布图层、透明边缘、文件名及资源依赖。对动画候选先按 `standards/SPRITE_ANIMATION_QA.md` 核对完整 12 组生产动作分镜、同一待机基准模型和 O 坐标、合理逐动作帧数、循环/复位规则；**自动拒绝任何格子重叠、越界、透明边距不足和索引错误**。优先独立帧的确定性装配；**允许多个动作合并一张 Atlas**，但需逐动作有序绝对帧索引、统一格子/根锚点和可验证的跨动作隔离；自动 Alpha/脚点猜测不能识别真实承重脚、动作阶段与根位移，视频提帧尚未真实验收。AI 视觉初筛仅标记疑难，少量人工复核；现有 Godot 仍仅支持旧九动作 ID，walk/run 与四攻击变体须有运行时映射后才可绑定为 in_use；没有实际 Godot 播放证据不得报告动画视觉完成。对城镇/地图还须验证 `pixels_per_unit=80`、运行时贴图 1:1 不旋转、分层同画布和角色 200px 比例参照，参考 `standards/TOWN_MAP_SCALE_PRODUCTION.md`；按对应美术 Skill 补充类别特定检查；不要将建议像素尺寸或 FPS 强制标为 frozen。
4. **原生导入**：角色由 WuxiaActorAnimationProfile/WuxiaCharacterDefinition.animation_profile 引用，场景由 WuxiaSceneArtProfile 和 WuxiaMapDefinition/WuxiaGridMapDefinition.scene_art 引用；素材放置在正式 assets 目录后仍由 .tres 显式挂载。Content Manifest 登记对应正式内容，不给 BattleModel 添加特殊分支。
5. **验证**：可运行时执行 godot --headless --path demos/changfeng-battle --editor --import --quit，并运行相关项目检查；随后必须在 Godot Editor 实测动画、场景、遮挡、点击与导出，留存 1600×1000 和 1440×900 GUI 截图。headless 成功不等于美术验收。
6. **切换使用版本**：通过原生 Resource 引用把唯一选中的候选改为 `in_use`；未使用的版本继续保留候选。导入前保存旧绑定以便撤销，切换后运行原有验证，不重绘合格素材。

## 输出与停止条件

- 输出当前使用中 Resource 引用、合同不合格项与实际执行的验证结果；缺少人工试玩时只说明尚未执行，不增加管理状态。
- 素材生成与使用合同仍遵循对应专业 Skill；版权事宜作为发行前事项独立处理。
- 对现有运行图的替换、删除或移动必须明确目标、可回退路径和审核授权；不要擅自清除历史素材。
