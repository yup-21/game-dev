# R23 — Godot 多边形地图画笔与无网格障碍资源

`WuxiaMapDefinition` 保存背景 `Texture2D`、逻辑视口、自由绘制的有效场景区域和若干 `WuxiaMapPolygonDefinition` 障碍。它是普通可版本化的 `.tres`，不包含 `rows`、`terrain_legend`、CSV、JSON 或手绘固定网格。

## 编辑器操作

1. 用 Godot 4.7.2 打开项目（插件位于 `addons/wuxia_map_editor/`，已在项目中启用）。
2. 在 Inspector 新建或选中 `WuxiaMapDefinition`，设置背景和 `area_bounds`（地图空间像素）。
3. 右侧出现「武侠 · 多边形地图画笔」。选择 blocked / water / rock / bamboo，点击「新障碍」。
4. 在背景预览中左键逐点绘制、右键撤回点；双击或点击「封闭」完成多边形。
5. 「撤回末项」移除上一多边形；「保存 .tres」将资源与嵌入的多边形保存到项目。地图文件应保存在 `res://data/maps/`，然后加入 Content Manifest 的 `maps`。
6. 通过 `WuxiaEncounterDefinition.map_resource` 引用地图 Resource；ScenarioDirector 会将这个路径传给已有 BattleModel/MapBake，FREE/GRID 两种空间模式共享场景定义。

测试样例 `data/maps/r23_free_brush_map.tres` 含一条自由画出的水域矩形；起点到终点的直线被遮挡，但 FREE 应能从上/下边绕行。测试 `checks/test_native_maps.gd` 覆盖 Resource、精确多边形检测、端点、连续线段防穿墙、寻路绕行与旧地图兼容。

## 空间语义

- FREE 路径端点与障碍碰撞由**连续多边形顶点**决定，支持任意倾斜或非矩形障碍，障碍线段不会因小于一格而消失。
- 为了保留既有战斗命令、GRID 测试与地图脚点映射，运行时会从同一多边形地图临时采样 15×10 兼容索引；它不是作者需要绘制或维护的地图定义。
- 原有雨桥 JSON 地图和 GRID/FREE 行为仍使用原先的 MapBake 分支；新资源不会修改旧资源或美术。
- 本工具解决技术上的地图内容生产，并不代替复杂场景美术绘制、NPC 寻路手工测试或关卡可玩性评审。正式 GUI 绘制与 1v1/3v3 人工验收仍需在 Godot 编辑器中执行。
