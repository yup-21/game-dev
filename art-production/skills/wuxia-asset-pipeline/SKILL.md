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
2. **创建候选包**：在 art-production/candidates/YYYY-MM-DD/<asset-id>/ 保存候选图及提示词，标明要绑定的 Resource；角色动画按 `action_id` 分组保存各自分镜和连续编号的独立源帧，便于单组返工和复用。按需要保留多个版本，不重复记录模型/seed/审批字段。
3. **两级技术校验**：先按 `standards/SPRITE_ANIMATION_QA.md` **逐动作**核对 12 组分镜、每个角色自身的 `weapon_contract`（允许徒手、单持、双持或双手握持）、各自真实帧数和连续编号、同一待机基准模型与 O、实际帧完整性/Alpha、循环首尾及非循环复位（defeat 终止态除外）；用该动作的源帧顺序预览运动连续性，异常帧先返工，未通过的动作不进入打包。再由确定性程序装配通过预检的帧，核对 Atlas 统一格子/根锚点、各动作有序绝对帧索引、列行整除、空格全透明；**自动拒绝重叠、越界、透明边距不足、错序或索引错误**。AI 视觉仅初筛，不能自动识别真实支撑脚/动作阶段/根位移，视频提帧尚未真实验收；疑难与最终少量样片再人工复核。Godot 目前仍仅支持旧九动作 ID，walk/run 与四攻击变体需完成运行时映射后才能作为 in_use；没有实际 Godot 播放证据不得报告动画视觉完成。其他素材仍检查解码、真实 Alpha、纹理与文件名、场景 ground/同画布分层及依赖；地图验证 `pixels_per_unit=80`、贴图 1:1、角色 200px 比例，参考 `standards/TOWN_MAP_SCALE_PRODUCTION.md`；不要把建议尺寸或 FPS 宣称已冻结。
4. **原生导入**：角色由 WuxiaActorAnimationProfile/WuxiaCharacterDefinition.animation_profile 引用，场景由 WuxiaSceneArtProfile 和 WuxiaMapDefinition/WuxiaGridMapDefinition.scene_art 引用；素材放置在正式 assets 目录后仍由 .tres 显式挂载。Content Manifest 登记对应正式内容，不给 BattleModel 添加特殊分支。
5. **验证**：可运行时执行 godot --headless --path demos/changfeng-battle --editor --import --quit，并运行相关项目检查；随后必须在 Godot Editor 实测动画、场景、遮挡、点击与导出，留存 1600×1000 和 1440×900 GUI 截图。headless 成功不等于美术验收。
6. **切换使用版本**：通过原生 Resource 引用把唯一选中的候选改为 `in_use`；未使用的版本继续保留候选。导入前保存旧绑定以便撤销，切换后运行原有验证，不重绘合格素材。

## 输出与停止条件

- 输出当前使用中 Resource 引用、合同不合格项与实际执行的验证结果；缺少人工试玩时只说明尚未执行，不增加管理状态。
- 素材生成与使用合同仍遵循对应专业 Skill；版权事宜作为发行前事项独立处理。
- 对现有运行图的替换、删除或移动必须明确目标、可回退路径和审核授权；不要擅自清除历史素材。
