# 使用中美术素材

这里按素材类型与稳定 ID 组织，只保存 Godot 正式脚本、场景或 Resource 当前引用的图片原字节；真正的绑定仍以 `.tres` 为准。

- `characters/<actor-id>/portraits|sprites|story-poses|concepts/`
- `scenes/<scene-id>/`（同一场景各图层相邻）
- `vfx/<actor-id>/<skill-id-or-shared-atlas>/`（一张图集可供多个技能引用，无需复制）
- `ui/cards|card-art|ornaments|overlays|common/`
- `placeholders/<asset-type>/`（明确使用中的旧测试占位；并非正式素材的隐式回退）

游戏已导入的图片统一存放在 `demos/changfeng-battle/assets/imported/<type>/<owner>/`，不再附加候选/使用中状态目录。导出工具按相对路径镜像**正式 Resource 当前引用**的图片；仅用于编辑器预览的旧图虽然也在导入目录，其制作原稿仍属于 `art-production/candidates/`，不额外写入本镜像。不按生成日期建立目录。

`art-production/candidates/` 可以有多个版本，`in-use` 同一原生 Resource 槽位只有当前绑定。旧归档保留于 `art-production/archive/`，不自动参与游戏加载。
