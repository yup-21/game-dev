# AI 美术候选素材

候选按类别和稳定 ID 管理，不按日期分目录：`characters/<actor-id>/`、`scenes/<scene-id>/`、`vfx/<actor-id>/<skill-id>/`、`ui/<component-id>/`。同角色或同技能的多个版本保留在同一资产目录，以文件名版本号或明确用途子目录区分。

每个候选包至少包含：

- 对应原生候选 `.tres`：由 `python3 art-production/tools/sync_candidate_resources.py` 在 `demos/changfeng-battle/data/art_candidates/` 按相同类别、角色和源文件名生成；每张候选图片（包括同一动作的不同版本）各有一份。已存在的 `.tres` 不会被生成器覆盖；Godot 内可编辑网格、脚点、参考身高和显示比例参数；源图片仍保留在本目录。
- `WORK_ORDER.md`：复制 `../templates/asset-work-order.md` 填写的提示词、参考图、模型、版本、seed、权属与审核结果；
- 源生成图（不覆盖旧版本）、可编辑母版或分层工程（如有）；
- 用于人工检查的裁切预览与 Godot 截图（如有）；
- 版本演进说明。

候选不因技术检查或导入成功而自动替换使用中资源；当前采用 `candidate` 与 `in_use` 两种管理状态。

历史归档保留在 `../archive/`；运行时只依据 `.tres` 明确引用，不扫描候选目录。跨资产的旧生产记录集中保存在 `records/`，保留原始提示词与来源记录。

候选 `.tres` 不是正式 `WuxiaActorAnimationProfile` 或 `WuxiaAssetDefinition`，也不加入 `data/content_manifest.tres`。它的 `source_path` 是仓库相对路径，指向 Godot 项目之外的原图；不能把候选图片直接当作 `res://assets/imported/` 的运行时资源。导入时使用候选的测量值/配置预检并明确生成正式 Resource，不能自动替换在用版本。

统一尺寸分为两层：候选 `.tres` 记录**真实源尺寸、声明的 C×R 网格、参考站姿可见高度、脚点**；正式角色按 `combat_scale.gd` 的 **200 世界像素**高度显示。未测量参考身高的候选 `display_scale()` 为 0（未知），不猜测整格高度；同一角色不同动作的可见比例不一致必须在候选阶段重排/修图，不能靠切换时逐帧缩放掩盖。场景贴图按实际世界画布 1:1 对齐，Resource 不允许随意拉伸地图。
