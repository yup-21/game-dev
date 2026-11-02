# 游戏素材生产管线：基线与技术校验（P2）

**统一制作总纲：** [《长风浮生录》美术与动画制作规范](../../../../docs/ART_PRODUCTION_STANDARD.md)。本页保留 P2 历史素材与审核流程，新增角色动作/场景分层均按总纲执行。

当前项目保留**原创高精细国风手绘**的人物和场景方向；HD-2D 主要描述镜头、纵深与遮挡表达，不强制低像素风格。

## 原生资产登记与离线审核

正式游戏通过 `WuxiaAssetDefinition` 的原生 `.tres` 注册资源，并加入 `data/content_manifest.tres.assets`；`AssetRegistry` 直接读取 Godot 导入的 `Texture2D`、`PackedScene`、`AudioStream`。

`assets/production_manifest.json` **仅用于历史美术来源和 QA 的离线审计**，不是运行时内容入口。审计文件为已有素材记录：

- 稳定 `id`、`kind`、`path`、用途阶段 `status`；
- 来源 `source` 与商业发布前需要核实的 `rights`；
- 可用时声明 `dimensions` 和图集 `grid`；
- `notes` 保存具体美术质量的已知问题。

状态解释：

| 状态 | 含义 |
| --- | --- |
| `concept` | 风格与造型设计，不可直接进战斗 |
| `preview` | 可临时播放的参考图，包括需运行时白底清理的 JPG |
| `candidate` | 技术规格可能符合，但 alpha、脚点、动作连续性仍待人工审查 |
| `runtime` | 当前运行路径实际引用的资源，不代表美术已最终定稿 |
| `approved` | 经实际 GUI、美术一致性、技术规格与授权确认的正式资产 |

**目前没有把任何角色动作候选图直接标为 approved。** 这保持了“已存储资源”和“真正可量产资源”的边界。

## 自动校验

`checks/test_asset_contracts.gd` 在 Godot 资源导入后检查：

1. 离线审核清单的版本、独立 ID 和安全 `res://assets/` 路径；
2. 已导入 `Texture2D`、原始图像可解码；
3. 声明的尺寸和图集切分比例；
4. 每张正式登记资源有来源和使用权状态。

候选素材的视觉 alpha、动作连贯性及版权审核不能自动断言合格，只生成 `ASSET_QA_PENDING`。新素材应优先登记 `WuxiaAssetDefinition`，必要时补充离线审核元数据；正式运行入口始终只读取原生 Resource。原始参考与用户上传素材不得自动删除。

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_asset_contracts.gd
```

## 新版角色动作与场景资源接口

- `WuxiaActorAnimationProfile` / `WuxiaActorAnimationClip`：角色卡的可选 `animation_profile`，支持各角色独立 Atlas 行列、真实动作帧、播放帧率、缩放、朝向与脚点；旧 6×4 图集继续兼容。
- `WuxiaSceneArtProfile`：地图卡的可选 `scene_art`，按同一画布提供背景、地面、前景遮挡和天气，校验尺寸与地图 viewport 一致；碰撞几何仍由原地图 Resource 管理。
- 未经过场景图层拆分及透明边缘人工校验的 `candidate` 不能直接接到上述正式接口。
- 新契约检查：`checks/test_actor_animation_profile.gd` 与 `checks/test_scene_art_profile.gd`。

## 2026-11-02 临时待机修复与脚点微调

六名当前候选角色的原生 `idle` 第 0 帧与第 1 帧是**不同观察角度的站姿**，并非同一朝向的连续呼吸动作；把二者以 9 FPS 循环，会产生反复转身。当前 `data/native/animations/*.tres` 的正式角色 `idle.frames` 临时设为 `PackedInt32Array(0)`。这仅消除错误播放，**不代表美术规范要求的正式待机循环已经制作完成**。后续替换为真正保持一致朝向、连续呼吸的完整动画后，再恢复多帧 idle。

**运行时脚点**：六名角色按待机第 0 帧的非透明轮廓统一显示高度（默认 200 个场景像素）。角色 Node2D 的原点对应脚下的地面落点，图集每格 256×256，`Sprite2D.offset.x` 不再根据武器/衣摆的左右伸展重心漂移。

**可编辑的最后修正**：在 Godot Inspector 打开 `data/native/animations/<角色>.tres`，调整 `feet_adjust`，单位是显示画面像素。例如 `Vector2(0, -8)` 把精灵整体提高 8 像素（脚伸到地面下方时使用）；`Vector2(0, 8)` 则降低 8 像素（脚悬空时使用）。修改后在第一幕和战斗中用脚下地面圆点观察，以角色鞋底为准，不要用剑尖、披风或衣摆最低点作为脚底。比例本身由统一的 `actor_visual_scale.gd` 管理，不依赖旧的 `actor_scale` 单独放大某个角色。

**注意**：`hframes=6`、`vframes=4` 已按 1536×1024 图集正确裁切。若某帧本身已被源图片单元格截断（例如断剑、缺少鞋底），改 offset 只能改变显示位置，无法重画丢失像素；需要重新生成或修订该帧，并在导入前做透明边缘和相邻帧串色检查。CI 的 `captures/art-pilot/native-idle-0-vs-1.png` 是六名角色的原始双帧对照。

## 角色图集未来的交付合同

在制作正式主角与一名敌人时，冻结角色像素密度、帧尺寸、左右朝向、脚底位置与以下动作：

- `idle`：至少完整一轮不同姿态，而不是单帧延长；
- `move`：连续步态，含纵深移动时的朝向策略；
- `attack`、`guard`、`hit`、`evade`、`combo`：有明确起手/有效/收招关键帧；
- 动画事件与 `BattleActionTimeline` 对接，**不得直接写入 HP、卡区和 CTB**；
- 每个动作保留关键帧、脚点、武器方向、透明边缘人工验收截图。

先通过一名完整主角 + 一名正式敌人的生产验证，再扩大到六人。现有白底姿势图可以继续作为 preview，不自动升级为正式逐帧动画。

## 未来尚未执行的步骤

- 生成并人工验收独立 `SpriteFrames` 或等价动画资源、音效/VFX 事件资源；
- 按数据索引自动生成可复用的角色 atlas 和 debug 预览；
- 继续维护已有导出包实际加载检查，避免动态 `res://` 字符串引用在 PCK 中遗漏；
- 拍摄 1600×1000 与 1440×900 的 GUI 对照截图并检查遮挡与脚点。

本阶段只建立**可重复、机器可校验的前半段管线**。导出验证已经由 Windows/Linux CI 执行，手工美术及授权验收仍由制作方负责。
