# 当前运行素材归档（P0）

此目录存放来自 Godot 工程的**只读生产副本**。原始运行文件仍位于
`demos/changfeng-battle/assets/`，其 `.tres` 及运行时入口完全不变。

- 素材使用索引：`inventory/asset-index.json`（包含 SHA-256、Git blob SHA1、原路径、引用与权属记录）。
- 可读报告：`inventory/usage-report.md`。
- 可重复执行的离线工具：`tools/inventory_assets.py`。
- 实际在用副本：`in-use/characters/`、`in-use/scenes/`、`in-use/ui/`、`in-use/fallback/`。
- 目前的 Kenney VFX tile 仅通过资产注册表引用，归入 `registered_only`，未复制到 `in-use/vfx/`。

```bash
python3 art-production/tools/inventory_assets.py --check
python3 art-production/tools/inventory_assets.py --write --source-commit <source-commit>
```

`--check` 只读验证索引、报告与副本字节一致性；`--write` 从工程复制并更新清单，
**不会覆盖**制作区里内容已经变化的文件。请先另行审核，再处理差异。
`in_use` 只表示静态依赖，**绝不等于 `approved`**。

下一阶段的 Godot `EditorPlugin` 可消费这份离线清单来选材，但必须
输出 Godot 原生 `.tres`，不允许使本 JSON 成为游戏的运行时配置。
