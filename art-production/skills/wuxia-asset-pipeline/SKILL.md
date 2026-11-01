---
name: wuxia-asset-pipeline
description: "为《长风浮生录》检查美术素材规格、盘点在用资源、审核候选、准备 Godot 原生 Resource 导入及批准替换时使用；管理 art-production 与游戏资产之间的可追溯关系。"
---

# 美术素材验收、归档与原生接入

## 单一事实来源

- 先读取 art-production/standards/ART_PRODUCTION_STANDARD.md、art-production/templates/asset-work-order.md；对 AI 候选再读 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md。
- art-production 是制作、审核、索引和交付区，不是运行时自动扫描目录。游戏的角色、地图、物品和武学由 Godot 原生 .tres Resource 及 data/content_manifest.tres 管理。
- 严格区分：concept/preview 是探索；candidate 是技术合格但待人工审核；approved 是视觉、动作/脚点、实机、授权等人工审核完成；runtime/in_use 表示当前可加载或实际被引用，不代表 approved。不得由 in_use 倒推出批准。
- 不重命名、搬移或清理正在被引用的旧路径；归档现有素材时复制并保留源路径、哈希和使用位置。不要把离线 JSON/YAML 工作单加载成第二套运行时数据。

## 可重复流程

1. **发现与归档**：根据项目真实 Resource/scene 引用而不是仅扫描图片目录，查明在用素材、当前路径和依赖。若已有 art-production/inventory/asset-index.json、usage-report.md 或 tools/inventory_assets.py，则优先检查并复用其格式/脚本，不凭空重建。in_use 快照与审核记录分开。
2. **创建候选包**：在 art-production/candidates/YYYY-MM-DD/<asset-id>/ 保存 WORK_ORDER.md、原图、提示词、模型/seed（如可得）、参考、可编辑母版和修订记录。保持明确版本号，禁止静默覆盖。
3. **技术校验**：检查解码、真实 Alpha、纹理尺寸、Atlas 整除和帧索引、脚点、场景四层同源点、透明边缘、文件名及资源依赖。按对应美术 Skill 补充类别特定检查；不要将建议像素尺寸或 FPS 强制标为 frozen。
4. **原生导入**：角色由 WuxiaActorAnimationProfile/WuxiaCharacterDefinition.animation_profile 引用，场景由 WuxiaSceneArtProfile 和 WuxiaMapDefinition/WuxiaGridMapDefinition.scene_art 引用；素材放置在正式 assets 目录后仍由 .tres 显式挂载。Content Manifest 登记对应正式内容，不给 BattleModel 添加特殊分支。
5. **验证**：可运行时执行 godot --headless --path demos/changfeng-battle --editor --import --quit，并运行相关项目检查；随后必须在 Godot Editor 实测动画、场景、遮挡、点击与导出，留存 1600×1000 和 1440×900 GUI 截图。headless 成功不等于美术验收。
6. **人工批准**：记录审查者、版本 SHA、技术/美术/授权结论与日期。未明确批准前只提交候选，不覆盖正式贴图或改动运行时引用；获批准后以可审阅的变更单独接入并标记实际 in_use。

## 输出与停止条件

- 输出资产索引/实际引用、校验失败清单、Godot 检验结果、审核截图和审批状态；注明未执行的验证步骤，不能声称全部通过。
- 缺少必要版权凭据、身份批准或图层/动画母版时停止晋升为 approved，列明待补资料。
- 对现有运行图的替换、删除或移动必须明确目标、可回退路径和审核授权；不要擅自清除历史素材。
