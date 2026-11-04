# 平江府 2.5D 地图透视验证（独立原型）

使用简单 `PlaneMesh` 石板路、贴图建筑盒、3D 碰撞和现有沈长风 Atlas 的 `Sprite3D`，比较透视摄像机与正交摄像机在同一 25u 纵向街道上的人物显示尺寸。

## 直接运行

在 Godot 中打开 `demos/changfeng-battle/project.godot`，运行 `res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn`，或执行：

```bash
godot --path demos/changfeng-battle res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn
```

- WASD / 方向键：沿 3D 地面行走；两侧房屋和远端门柱有真实碰撞。
- `P`：透视与正交投影切换；在透视模式中，向远处走屏幕上的人物会缩小。
- `R`：复位位置。远、近两处半透明人影是同一个 `.tres` Atlas 的对照。
- 屏幕左上角显示实时 Z 坐标、投影高度和同世界身高两处参照的像素高度。

## 技术范围

- 使用 `CombatScale` 的 80 世界像素 / 单位、2.5u 人物参考高度、0.3u 地面占位，仅转换为 3D 展示单位。Sprite 的可见身高从原生 `WuxiaActorAnimationProfile` 的待机 Alpha 轮廓测量，不按透明帧格粗暴缩放。
- `stone_road.svg` 和 `house_facade.svg` 是仓库内确定性绘制的**技术示意贴图**，不是正式或经美术审核的平江府场景。无新下载、无来源不明的美术素材。
- 原有 2D 地图、角色 Resource、Content Manifest、战斗规则、主菜单和地图分层工作完全不变。
- 这是 3D 投影及碰撞可行性验证，未实现地图 `WuxiaMapDefinition` 的 3D 适配、跨区传送、完整动作朝向、NPC 或正式贴图转换。不能将原本已烘焙透视的完整 2D 母版直接铺到地面，否则会出现二次透视。
- 正式规范仍要求当前 2D 地图上普通人物显示 200px 且不随 Y 缩放；本原型特意验证**未来可选**的透视行为，不改变该合同。

## 自动检查

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_pingjiang_25d_prototype.gd
```

自动验证纹理加载、3D 静态与角色碰撞、Atlas 绑定和透视/正交尺寸差异。GUI 视觉、角色脚点与房门几何、两种窗口比例及正式场景贴图仍须后续人工验收。
