# PJ-01 瓮城正南门：运行时分层、碰撞及跨区

## 运行入口与坐标

- 标题菜单 **G · 瓮城正南门 · 正式地图**，对应 `res://scenes/pingjiang_south_gate.tscn`；从 `(800,1700)` 出生。
- 世界画布 `1600×2000`，正交/平行投影约束，固定比例 `80px/米`。角色基础身高约 `200px`，脚点碰撞半径 `24px`；南北卷屏只移动摄像机，不缩放地图。
- 画面中桥面/路面是原生可走多边形；路旁护城河、城墙、建筑为不可通行区域。城门立柱和桥两侧栏杆另外定义四个 `blocked` 多边形（并非根据图片色块自动碰撞）。按 `F3` 可显示可走边界。
- WASD/方向键走动，左键指定可通行目标；到出口金色标记附近按 `E` 切换整个地图，旧区域释放、目标独立加载，随后以命名入口脚点定位。

| 出口 | PJ-01 出口坐标 | 目标场景 / 入口 | 返回出口 / PJ-01 入口 |
| --- | --- | --- | --- |
| 北 | `to_north (800,105)` | PJ-02 十字街 `from_south (800,730)` | PJ-02 `to_south (800,925)` → PJ-01 `from_north (800,320)` |
| 南 | `to_south (800,1905)` | 城外官道 `from_north (800,275)` | 官道 `to_north (800,95)` → PJ-01 `from_south (800,1710)` |

出生点与对向出口之间保留至少 `140px` 的距离，避免跨区后立即触发返回；交互不是触边自动换图，须按 `E`。

## 原始像素无损拆层

`art-production/tools/export_pingjiang_runtime_layers.py` 从每个完整母版重建三张等大、同原点、透明 WebP：

1. `background.webp`：世界不可通行区域、建筑和水体。
2. `ground.webp`：路面、城门洞与桥面（PJ-02 十字交叉主路亦属地面）。
3. `foreground.webp`：瓮城门洞檐梁、桥面护栏以及 PJ-02 上方牌坊，站位前景遮挡。城外官道没有实际跨道前景物件，合法省略第三张图。

每个母版像素只归属一层；以 `background → ground → foreground` 叠合后必须与母版**逐像素一致**，脚点和碰撞数据同坐标。原生 `WuxiaSceneArtProfile` 指向运行图层，`WuxiaMapDefinition` 声明地图尺寸和碰撞；双方均由 `Content Manifest` 注册。游戏运行时不读取美术工具、掩码或候选目录。

> 当前是可运行的、无错位的**技术分层**：对于单张已合成手绘母版，可确定层级与遮挡范围，但还不是逐物件手绘补全的源文件。城门檐梁和桥栏前景裁切边缘仍需在美术终审中检查；调整遮挡范围应改导出预设重新执行，不应直接移动其中一层。

PJ-02 使用既有 v02 候选图（十字街自身纵向透视仍待单独美术验收），城外官道使用新绘 v01 并统一校准到 `1600×1000`。这两张是本次为两端往返完整验收所引入的邻区场景；今后换图不需改跨区代码，只需维护一致坐标和 Resource。

## 验证

```bash
python3 art-production/tools/export_pingjiang_runtime_layers.py
godot --headless --editor --import --path demos/changfeng-battle --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_pingjiang_south_gate.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_pingjiang_long_street.gd
```

`test_pingjiang_south_gate.gd` 覆盖原生 Resource 完整性、三层尺寸、80px/米、可走路面和实体阻挡、纵向摄像机边界、北南双向四次转区、离开地图释放及无隐式角色占位。已有长街 QA 单测独立保留。
