# Godot 导入素材目录

游戏内已导入的原始图片统一按**资产类型 → 角色/场景/技能 ID**归档，不按候选和使用中状态建立目录，也不按制作日期或批次建目录。

```text
assets/imported/
├── characters/<actor-id>/
│   ├── portraits/
│   ├── sprites/
│   ├── story-poses/
│   └── concepts/
├── scenes/<scene-id>/
├── vfx/<actor-id>/<skill-id-or-shared-atlas>/
├── ui/<component-id>/
└── placeholders/<asset-type>/
```

- `art-production/candidates/` 仍保存多版本制作候选，`art-production/in-use/` 仅镜像正式 Resource 当前引用的图片，**两种生产状态不映射成 Godot 文件夹**。
- 现在的 73 张导入图片中，70 张由正式脚本或 Resource 引用；另 3 张旧动画预览图由 `data/art_previews/` 使用，保留原稿在制作候选区。它们不会因为文件位置而自动成为正式角色动作。
- 导入器按照素材类型和所属 ID 直接写入本目录；新版本采用不同文件名或显式哈希版本后缀，修改 .tres 绑定后才生效。
- 不要手工移动已被引用的图；修改后运行 `python3 art-production/tools/inventory_assets.py --check` 核对图片、正式镜像和编辑器预览来源。

`.godot/imported/` 是 Godot 自动重建的缓存，**不是**需要整理或提交的素材目录。
