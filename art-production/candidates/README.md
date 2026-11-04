# AI 美术候选素材

候选按类别和稳定 ID 管理，不按日期分目录：`characters/<actor-id>/`、`scenes/<scene-id>/`、`vfx/<actor-id>/<skill-id>/`、`ui/<component-id>/`。同角色或同技能的多个版本保留在同一资产目录，以文件名版本号或明确用途子目录区分。

每个候选包至少包含：

- `WORK_ORDER.md`：复制 `../templates/asset-work-order.md` 填写的提示词、参考图、模型、版本、seed、权属与审核结果；
- 源生成图（不覆盖旧版本）、可编辑母版或分层工程（如有）；
- 用于人工检查的裁切预览与 Godot 截图（如有）；
- 版本演进说明。

候选不因技术检查或导入成功而自动替换使用中资源；当前采用 `candidate` 与 `in_use` 两种管理状态。

历史归档保留在 `../archive/`；运行时只依据 `.tres` 明确引用，不扫描候选目录。跨资产的旧生产记录集中保存在 `records/`，保留原始提示词与来源记录。
