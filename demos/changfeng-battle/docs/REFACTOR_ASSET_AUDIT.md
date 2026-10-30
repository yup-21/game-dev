# R7：资源引用与来源审计

> 核查日期：2026-10-31；重构分支 `refactor/battle-architecture-consolidation`。
> 本文记录 GitHub 当前代码树的静态引用核查，不把动态路径、手动美术验收推定为完成。

## 静态路径一致性

仓库树约 307 个条目，本轮抽取 `demos/changfeng-battle` 下 125 份 `.gd / .tscn / .tres / .gdshader` 文本，扫描 316 个静态 `res://` 字面引用并与 Git tree 对照。初始报告的 12 处“未找到”包括：

- `res://captures/...`：测试生成的截图与日志输出，故意被 Git 忽略。
- `res://checks/*results.json`：测试执行时生成的回放或证据数据。
- `res://battle_hd2d.tscn.`：文档字符串的句末标点，不是实际资源路径。

上述不是源代码所引用的缺失图像或 `preload`。此次没有发现 **确定的静态、已提交代码资源路径悬空**；动态拼接路径仍依赖 Godot 导入和运行回归验证。

## 美术来源与运行时边界

| 资源 | 位置 | 来源/授权现状 | 角色 |
| --- | --- | --- | --- |
| Kenney CC0 贴图（18张） | `assets/kenney/` | 有 CC0 和上游 Git revision，见 `asset-licenses.md` | 旧视图/兼容 UI 资产 |
| 用户上传/生成的角色设计与动作参考 | `assets/characters/concepts/`、`assets/concepts/2026-10-30/` | 原用户提供及生成稿；仓库未记录可转授权的独立许可证 | 正式六角色图集映射及美术设计参考 |
| 完整雨夜断桥地图 | `assets/scenes/battle/rainy_bridge_battle.webp` | 用户提供的原画，详见画面集成记录 | 正式 GRID / FREE 共用战场 |
| 破庙剧情场景 | `assets/scenes/story/ruined_temple_story.webp` | 用户提供的原画 | 序章第一幕 |

原图、候选姿态、备用素材在本次架构整理中全部保留。候选 PNG 的 alpha、动作过渡与脚点一致性仍需单独的制作验收，不能将 6×4 姿势参考等同成 24 FPS 真实逐帧动画。

## 重构回归门槛

- `test_illustrated_maps.gd`：两张正式原画能导入且尺寸匹配。
- `test_actor_facing.gd`：新场景 Sprite2D 朝向与脚点。
- `test_battle_pure_2d.gd`：无 3D 场景依赖，CanvasLayer 坐标校正。
- `test_battle_spatial_facade.gd`：GRID/FREE 路径、距离、角色碰撞。
- 完整 GUI 截图/人工操作需另行验收，headless PASS 不等于动画流畅与美术完成。
