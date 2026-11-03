# 使用中美术素材

这里按素材类型与稳定 ID 组织，只保存 Godot 正式脚本、场景或 Resource 当前引用的图片原字节；真正的绑定仍以 `.tres` 为准。

- `characters/<actor-id>/portraits|sprites|story-poses|concepts/`
- `scenes/<scene-id>/`（同一场景各图层相邻）
- `vfx/<actor-id>/<skill-id-or-shared-atlas>/`（一张图集可供多个技能引用，无需复制）
- `ui/cards|card-art|ornaments|overlays|common/`
- `placeholders/<asset-type>/`（明确使用中的旧测试占位；并非正式素材的隐式回退）

游戏运行图片存放在 `demos/changfeng-battle/assets/imported/in-use/` 同一分类层级，导出工具按相对路径镜像。只有不被游戏引用的预览图才放在 `assets/imported/candidates/`。不按生成日期建立目录。

`art-production/candidates/` 可以有多个版本，`in-use` 同一原生 Resource 槽位只有当前绑定。旧归档保留于 `art-production/archive/`，不自动参与游戏加载。
