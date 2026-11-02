# 使用中素材原字节镜像

只存储当前游戏原生 Resource 绑定的图片副本，源路径按 `demos/changfeng-battle/assets/imported/` 镜像到 `in-use/imported/`。每个 Resource 槽位仅有一个使用中版本；未绑定的候选保留在 `art-production/candidates/`。

历史旧目录已经归档到 `art-production/archive/legacy-2026-11-02/`，不再维护 `in-use/characters/`、`in-use/fallback/`、`in-use/scenes/` 或 `in-use/ui/` 第二套路径。

导出当前绑定通过 Godot **Art Production** Dock；重新导入时保持与原先相同的 `res://assets/imported/` 路径。素材生成与正式使用合同不变。
