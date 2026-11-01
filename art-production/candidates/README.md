# AI 美术候选素材

今后按 `YYYY-MM-DD/<asset-id>/` 新建批次目录。

每个候选包至少包含：

- `WORK_ORDER.md`：复制 `../templates/asset-work-order.md` 填写的提示词、参考图、模型、版本、seed、权属与审核结果；
- 源生成图（不覆盖旧版本）、可编辑母版或分层工程（如有）；
- 用于人工检查的裁切预览与 Godot 截图（如有）；
- 版本演进说明。

候选图片不能仅凭文件扩展名、AI 生成成功或 CI 通过就标为 `approved`。

历史批次仍保留在 [现有 concepts 目录](../../demos/changfeng-battle/assets/concepts/)，不批量搬运，防止打断现有资产引用。后续批准的运行时素材由对应 `.tres` 资源显式引用，而非通过扫描本目录自动加载。
