# 平江府地图 QA：横向滚屏、连接点跨地图与纵向 Y=4000

**测试入口仍在 Demo 标题菜单，不改变序幕或战斗。** 当前是三张互相独立的 Godot 原生地图资源，不再把第一、第二张横向贴图挂在一个 8000px 世界内。

## 如何试玩

1. Godot 4.7.x 导入 `demos/changfeng-battle/project.godot`，运行主场景 `opening.tscn`。
2. 点击 **「P · 平江跨地图跳转」**（也可按 `P`），出生于主干道西端。WASD/方向键或鼠标左键移动。
3. 走到主干道东侧**绿色连接点（本地图 X≈4690，Y≈790）**，自动进入**东市**；角色在东市指定入口 `from_west`（X=400，Y=790）出生。不会继续沿旧地图的 8000px 拼接坐标走。
4. 在东市沿道路向西至连接点 X≈140，可返回主干道的 `from_east`（X=4380，Y=790）。在东市北侧门坊 X≈1305、Y≈700，接触绿色连接点可进入**北街南北长巷**（X=800，Y=3500）。
5. 在南北长巷上下移动，观察镜头沿 **Y 轴**滚动。到南端 X≈800、Y≈3860 的连接点，可返回东市的 `from_north`（X=1320，Y=835）。
6. 可在主菜单直接点击 **「V · 南北长街滚屏测试」**（或 `V`）从纵向长巷南端开始。按 `F3` 查看当前地图可走边界，`Esc` 返回主菜单。

绿色圆圈是**真实 `zone_exit` 连接点**，接触即可自动切图；HUD 会显示**当前地图的本地脚点、镜头偏移和成功转场次数**。

## 三张真实地图（分别加载）

| 地图资源 | 主轴 | 原生画布 | 摄像机与角色 |
| --- | --- | --- | --- |
| `pingjiang_long_street_qa.tres` | horizontal | 4800×1000 | X=2400，镜头 X=-1600；最右偏移钳制 -3200 |
| `pingjiang_east_market_qa.tres` | horizontal | 3200×1000 | X=400，镜头 X=0；最右偏移钳制 -1600 |
| `pingjiang_north_lane_qa.tres` | vertical | **1600×4000** | Y=3500，镜头 Y=-3000；Y=2100 时 -1600；Y≈200 时 0 |

每张地图有独立的 `WuxiaMapDefinition`、`WuxiaSceneArtProfile` 和同画布三层原创 SVG。跨图时**卸载上一地图可视节点，载入目标地图，按其命名 spawn 点重定位角色，再用目标地图尺寸计算相机**。坐标不再共享或做接缝偏移，转场后鼠标点击使用目标区域自身的屏幕→世界坐标逆变换。

普通角色高度仍为 **200 世界像素**，占位半径 **24 世界像素**，`CombatScale` 固定 **80px/u**；纵向地图不是旋转横向贴图，也不会随 Y 位置缩放人物。

### 原生连接点关系

| 出发地图及 `zone_exit` | 目标地图及 `spawn` | 入口脚点 |
| --- | --- | --- |
| 主干道 `to_east` | 东市 `from_west` | (400, 790) |
| 东市 `to_west` | 主干道 `from_east` | (4380, 790) |
| 东市 `to_north` | 北街 `from_south` | (800, 3500) |
| 北街 `to_south` | 东市 `from_north` | (1320, 835) |

`WuxiaMapMarkerDefinition` 自带 `zone_exit`、`target_zone_id` 和 `target_entry_id` 字段。新增 `scripts/map_zone_connection.gd` 可按这套资源解析并验证目标 spawn 是否处于合法可走区。QA 运行器选择性加载地图；**此功能目前仅接入测试场景，尚未集成进正式剧情区域管理或动态流送**。

## 自动验证

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_pingjiang_long_street.gd
```

用真实 Resource 检查三张图原生尺寸、纵向可走多边形、双向连接目标、旧图卸载、目标 spawn、各图镜头限位及点击坐标逆变换。GUI 仍需按 **1600×1000** 和 **1440×900** 两种窗口人工走查，确认门坊、遮挡与动作流畅度。

## 美术状态

这些为按照 [城镇与大地图比例尺生产规范](../../../art-production/standards/TOWN_MAP_SCALE_PRODUCTION.md) 制作的**原创 SVG 技术简图**，不是正式批准美术。横向工单：`art-production/candidates/2026-11-02/pingjiang_long_street/WORK_ORDER.md`；纵向工单：`art-production/candidates/2026-11-03/pingjiang_north_lane/WORK_ORDER.md`。不替换已有正式剧情/战斗美术。
