# 使用中素材

**唯一当前选择来自 Godot 原生 Resource 绑定**，不是这里的文件数量。

- `data/native/`、`data/maps/` 等原生 `.tres` 指向的每个素材槽位只有一个使用中版本；候选文件可以有多个。
- `art-production/inventory/asset-index.json` 和 `usage-report.md` 仅列当前被游戏资源、场景或运行脚本引用的素材。SHA-256 自动校验字节，不单独维护审批/来源状态。
- `in-use/` 保留此前导出的原字节副本，**旧副本暂不删除**，但存在于本目录不等于仍在使用。
- Godot Editor 中的 **Art Production** Dock 已支持导入、导出和事务回退；素材来源仅要求提示词和对应 Resource。

```bash
python3 art-production/tools/inventory_assets.py --check  # 只读校验
python3 art-production/tools/inventory_assets.py --write  # 更新使用中清单与缺失副本
```

更换当前素材时先保留旧文件与可回退绑定，后续按槽位分批清理。游戏仍只读取原生 `.tres`，不读取本目录的清单。
