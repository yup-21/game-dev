# 平江府四区：Godot 原生地图编辑

## 入口

在 Godot 4.x 中导入 `demos/changfeng-battle/project.godot`，打开以下场景：

| 地图 | 原生场景 |
| --- | --- |
| PJ-01 南门 | `res://scenes/pingjiang_regions/pj01_south_gate.tscn` |
| PJ-02 十字路 | `res://scenes/pingjiang_regions/pj02_crossroads.tscn` |
| PJ-03 水市 | `res://scenes/pingjiang_regions/pj03_riverside_market.tscn` |
| PJ-04 沈家旧宅 | `res://scenes/pingjiang_regions/pj04_shen_house.tscn` |

直接打开任一场景即可在 **2D** 视图中看到同原点的 `Background`、`Ground`、`Foreground` 三层 `Sprite2D`。选中 `WalkableArea/Boundary` 用 Godot 自带的多边形工具调整可走边界；`Obstacles` 下的 `StaticBody2D/CollisionPolygon2D` 可移动和编辑顶点；`Markers` 下的 `Marker2D` 是出生点或交互标记；`Exits` 下的 `Area2D/Radius` 是换区点及圆形范围，目标地图/出生点在 Inspector 中设置。

- `F6`：从当前打开的原生地图直接进入可操作的探索 QA，初始区域就是该图。
- 打开 `res://scenes/pingjiang_exploration.tscn` 再 `F6`：从南门开始连续探索四区。
- `F5`：运行项目的正式主入口；主菜单的 `J` 入口仍保留。
- 运行中 `F3` 显示可走轮廓，`F4` 调整人物高度/镜头；F4 临时值不自动保存。

## 数据来源与保存

编辑模式下，**`.tscn` 原生节点是四区探索的几何编辑来源**：运行时直接读取场景多边形、标记和出口数据，不再从 `.tres` 创建四区贴图节点。现有 `WuxiaMapDefinition` `.tres` 仍是其余内容/战斗/QA 的正式 Resource 合同，不迁移或删除旧资源。

1. 在 2D 编辑器中调整原生节点，`Ctrl+S` 保存 `.tscn`，`F6` 立即试走。
2. 完成验收后选择场景根节点，点击 Inspector 中的 **“同步原生节点到地图 .tres”**；它会校验几何和标记后保存 Resource，供其它内容系统使用。
3. 提交 `.tscn` 与同步后的 `.tres`。`test_pingjiang_native_regions.gd` 检查两者一致，未同步会阻止验收。

编辑器没有在每次拖拽时自动写回正式 Resource，以免误操作污染正式内容。四区测试直接消费 `.tscn` 以满足所见即所得；完整的内容发布仍保留明确的 Resource 校验与提交步骤。所有图片沿用既有的 `in_use` 资源，不自动批准或替换候选美术。

新的地图如需从旧 `.tres` 初始化，可参考 `tools/generate_native_pingjiang_scenes.gd` 的节点结构；该迁移脚本**拒绝覆盖**已存在的 `.tscn`。
