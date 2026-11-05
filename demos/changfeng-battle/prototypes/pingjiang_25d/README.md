# 平江府 2.5D 地图透视验证（独立原型）

使用简单 `PlaneMesh` 地面和相交的南北／东西两条石板路，配合带建筑正立面贴图的竖直 `QuadMesh` 与现有沈长风 Atlas 的 `Sprite3D`，比较透视与正交摄像机。**地图实际占地仍是 1600×2000 世界像素（20u×25u）**，十字街两条路宽各 5u。建筑没有体积模型或房顶，只有视觉贴片及隐藏的薄 `StaticBody3D` 碰撞板；四向道路在交叉处可通行。

此前地图看起来短是因为相机高度 14u、透视 FOV 50°、相机与角色纵向距离较大，导致单屏包含了大部分道路。现在相机高度 10u、FOV 38°、跟随偏移 8u，缩小取景区域；仅测试场景的角色 Sprite 可见高度乘以 `ACTOR_DISPLAY_SCALE = 0.30`，并保留角色世界脚点与 0.3u 碰撞半径。正式 2D 角色仍按 200 世界像素显示。这些参数用于对比不同视觉密度，不是新地图世界比例尺。

## 直接运行

在 Godot 中打开 `demos/changfeng-battle/project.godot`，启动游戏后点击主菜单的 **T · 2.5D 透视地图测试**（也可直接按 `T`）。仍可直接运行 `res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn`，或执行：

```bash
godot --path demos/changfeng-battle res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn
```

- WASD / 方向键：沿 3D 地面行走，穿过十字路口转向东／西／北／南；镜头在地图边界内平滑跟随；建筑平面有薄碰撞，路口中央没有遮挡。
- `P`：透视与正交投影切换；同一世界高度在不同纵深仍有不同投影尺寸。正交对照视野也已同步收紧。因为镜头会跟随主角，主角自身的屏幕高度相对稳定。
- `R`：同时复位角色和镜头。远、近两处半透明人影是同一个 `.tres` Atlas 的对照。
- `Esc`：返回游戏主菜单，不修改章节或战斗存档状态。
- 屏幕左上角显示实时玩家/镜头 Z 坐标、投影高度和同世界身高两处参照的像素高度。

## 技术范围

- 使用 `CombatScale` 的 80 世界像素 / 单位、2.5u 人物参考高度、0.3u 地面占位，仅转换为 3D 展示单位。测试场景在测得原生待机 Alpha 轮廓后额外乘以 0.30 来降低视觉身高，**不改变**碰撞、原生 Resource 或正式角色显示规范。
- `stone_road.svg` 和 `house_facade.svg` 是仓库内确定性绘制的**技术示意贴图**，不是正式或经美术审核的平江府场景。所有房屋都只显示直立正面，没有屋顶或 3D 房屋箱体，无新下载素材。
- 原有 2D 地图、角色 Resource、Content Manifest、战斗规则、主菜单和地图分层工作完全不变。
- 这是 3D 投影及碰撞可行性验证，未实现地图 `WuxiaMapDefinition` 的 3D 适配、跨区传送、完整动作朝向、NPC 或正式贴图转换。不能将原本已烘焙透视的完整 2D 母版直接铺到地面，否则会出现二次透视。
- 正式规范仍要求当前 2D 地图上普通人物显示 200px 且不随 Y 缩放；本原型特意验证**未来可选**的透视行为，不改变该合同。

## 自动检查

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_pingjiang_25d_prototype.gd
```

自动验证贴图与平面几何、四向道路连续通行、薄立面碰撞、没有屋顶网格、Atlas 绑定、1600×2000 世界尺寸、窄视野相机跟随/限位和透视/正交尺寸差异。GUI 下的建筑纸片朝向、遮挡、人物脚点、两种窗口比例及正式贴图仍须人工验收。
