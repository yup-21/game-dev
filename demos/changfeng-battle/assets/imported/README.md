# Godot 导入素材目录

这里保存实际纳入游戏项目的**原始图片**，由 Godot `Resource` 显式引用；不是引擎自动生成的 `.godot/imported/` 缓存。

- `in-use/`：当前游戏使用的图片，按 `characters/<actor-id>/portraits|sprites|story-poses|concepts`、`scenes/<scene-id>`、`vfx/<actor-id>/<skill-id>`、`ui/<component-id>`、`placeholders/<kind>` 分类。原字节副本存于仓库的 `art-production/in-use/`。
- `candidates/`：已导入供预览、对比或继续制作的候选图片，同样按角色和素材类型、场景、技能、UI 组件归类；原稿仍保存在 `art-production/candidates/`。
- 候选原稿的 `baseline/`、`sprite-vNN/`、`qa-layout/` 等生产批次目录只属于制作区，**不复制到导入目录**；不同版本靠文件名或显式 SHA 版本化区分。

新素材使用编辑器的 **Art Production** Dock 导入，不要手工修改 `Resource` 引用或移动已绑定图片。导入器负责按类型生成路径并等待 Godot 完成纹理导入。更改绑定后运行 `python3 art-production/tools/inventory_assets.py --check` 验证结构和镜像。

`.godot/imported/` 是 Godot 自动重建的导入缓存，不能作为资产来源，也无需纳入 Git。
