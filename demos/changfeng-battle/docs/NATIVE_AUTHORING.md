# Godot 原生编辑入口与资产分工

从 Godot 项目管理器导入 `demos/changfeng-battle/project.godot`。此处所列 `.tscn` 均为普通可保存的 Godot 场景。修改后按 **Ctrl+S** 保存；按 **F6** 运行当前场景，按 **F5** 从正式入口运行游戏。

## 可直接微调的场景

| 用途 | 编辑器打开 | 可编辑的内容 | 运行绑定 |
| --- | --- | --- | --- |
| 战斗整体 | `battle_hd2d.tscn` | 摄像机、HUD 实例、音轨节点 | `BattleWorld2D` 复用摄像机，`BattleHUDView` 复用 HUD |
| HUD | `scenes/ui/battle_hud.tscn` | 章节横幅、按钮、队列、手牌容器、角色卡入口 | 运行时只向容器填充当前角色/卡牌/指令 |
| 角色详情 | `scenes/ui/character_card.tscn` | 半透明遮罩、面板、头像/属性/门派布局 | `CharacterCardUI` 只绑定数据及事件 |
| 手牌卡面 | `scenes/ui/battle_card.tscn` | 卡画区域、边框、角标、费用/标题文字位置 | `CardUI.make_card()` 只填图、价格和按钮状态 |
| CTB 跑轴 | `scenes/ui/ctb_rail.tscn`、`scenes/ui/ctb_marker.tscn` | 轨道装饰、固定标题、头像和边框 | Godot Control 依据 BattleModel 集气数据更新标记位置 |
| 战斗角色 | `scenes/actors/battle_actor.tscn` | 脚点投影、Sprite2D、AnimationPlayer、名字和交互圈 | 战斗中按角色实例化，`WuxiaActorAnimationProfile` 仍决定帧顺序 |
| 剧情角色 | `scenes/actors/story_role.tscn` | 脚点、Sprite2D 和 AnimationPlayer | 序章实际复用 |
| NPC | `scenes/actors/story_npc.tscn` | 角色实例、交谈碰撞圈、提示 | 序章按注册角色、NPC 数据实例化 |
| 可交互物 | `scenes/story/interaction_point.tscn` | Sprite、交互 Area2D、音效槽、提示；Inspector 可设 `interaction_id` | 使用 `interaction_requested` 信号；不修改任务规则 |
| 战斗特效 | `scenes/vfx/combat_burst.tscn` | 描边、发光、连段残影、素材 Sprite、音效槽 | `BattleVFX2D` 根据 Cue 实例化并控制播放 |
| 标题菜单 | `opening.tscn` → `NativeMenuUI` | 标题、文字、九个交互按钮、hover/pressed 样式与位置 | 按钮直接连接原有 `_action`；地图和剧情入口不变 |
| 序章探索 HUD | `opening.tscn` → `ExploreUI/ExploreHUD` | 场景名称、任务提示、消息、E 交谈按钮 | 文字来自剧情 Resource；NPC 探测与按键行为不变 |
| 序章对白 | `opening.tscn` → `DialogueUI` | 肖像、角色名、打字机文本、继续与分支选项按钮 | `opening_flow.gd` 只填内容、控制显示；选项条件仍由剧情数据计算 |
| 序章结算 | `opening.tscn` → `CompleteUI` | 结语、奖励文案、迎战追兵/返回菜单按钮 | 仍进入唯一正式战斗；不改变奖励发放逻辑 |
| 序章过场操作 | `opening.tscn` → `CinematicOverlay` | 跳过过场按钮、操作提示、过场字幕与淡入动画 | `skip` 信号与过场状态同步 |
| 剧情与分层 | `opening.tscn` | 背景/地面/前景/天气层、角色容器、过场文字/淡入动画、音轨 | `opening_flow.gd` 引用现成节点，更新文本和所选素材 |
| 战斗结果 | `demo_result.tscn` | 文字、按钮位置及颜色 | `demo_result.gd` 根据 GameSession 更新 |
| 2.5D 技术验证 | `prototypes/pingjiang_25d/pingjiang_25d_validation.tscn` | 完整 3D 道路、立面、碰撞、角色、摄像机和 QA HUD | 仍为独立原型，未成为正式四区地图 |

**推荐先打开** `scenes/native_authoring_workbench.tscn`，在一个场景中检查角色、NPC、可交互物的脚点与间距。F6 后方向键走动、靠近道具按 E 检查交互信号。它不会执行正式战斗或修改剧情进度。

## 什么留在 Resource 里

- `data/native/animations/*.tres` 的 `WuxiaActorAnimationProfile` 是动作 ID、图集、帧索引、时长及缩放的唯一配置来源。编辑场景中的 `Sprite2D` 只能调整展示节点，不能替代帧序配置。
- Content Manifest、角色/技能/道具、BattleActionTimeline、VFX Cue、地图几何与剧情条件仍按 `.tres` 或既有专用脚本管理，不在展示场景中复制第二份规则。
- 当前已确认在用的角色素材仍是历史 6×4 图集；新增 5×5、12 动作的角色应先通过候选 `.tres` 审核后正式绑定。本次未替换任何原画/贴图。
- 音频播放器为原生槽位，目前没有新音频导入；空 `AudioStream` 不会隐式播放替代声音。

## 自研导入与地图编辑器

- **Art Production Importer**：角色 Atlas/立绘仍绑定到唯一的 `WuxiaCharacterDefinition` 与 `WuxiaActorAnimationProfile`；运行时的 `Sprite2D/AnimationPlayer` 从 Profile 读取帧序，导入器不会把某个角色的贴图硬写进所有角色共用的 `.tscn`。
- **分层场景导入**：默认只修改地图或章节的 `.tres` 和 `WuxiaSceneArtProfile`。如果已在 Godot 里建立原生地图场景，可在导入器的“原生地图 .tscn”栏显式填写路径，或打开该地图后点击“当前场景”自动填入路径；**随后先 Ctrl+S 保存并关闭该场景，再执行导入**，避免覆盖编辑器内尚未保存的微调。预检会核对根节点的 `source_map`、`Background/Ground` 原生 `Sprite2D` 以及可选层节点，仅替换指定层的 `texture`，**不会修改位置、比例、碰撞、出口、Marker**。缺少的可选图层需先在编辑器中创建。
- **防覆盖和回退**：导入前确认弹窗显示将修改的 `.tscn`；导入事务同时备份 `.tres`、所选 `.tscn`，保存前复查文件哈希，自动失败或手动撤销都要求文件没有被后续修改。新导入图片保留，避免误删其他资源。
- **Wuxia Map Editor**：在 Inspector 选旧 `WuxiaMapDefinition`，仍可使用多边形画笔编辑 Resource；选带 `source_map` 的原生地图根节点时切为只读检查模式。直接在 Godot 2D 视图修改 `WalkableArea/Boundary`、`Obstacles`、`Markers`、`Exits`；保存 `.tscn` 后，使用该根节点的“同步原生节点到地图 .tres”按钮更新旧消费者使用的 Resource。地图插件不会暗中用旧画笔覆盖原生几何。
- **Art Exporter**：指定地图 Resource 导出时会沿原生地图根节点的 `source_map` 反向找到对应 `.tscn`，一同导出该场景及其贴图、Resource 依赖；“全部图片”模式仍仅导出实际使用的美术图片，不会把整套场景当成另一份运行时入口。

相关无写入检查：`godot --headless --path demos/changfeng-battle --script res://checks/test_native_tool_adapters.gd`。

## 微调注意事项

1. 修改角色相对 Sprite2D 的脚点/尺寸，先确认 `actor_visual_scale.gd`、动画 Profile 中的 `feet_offset`/`actor_scale` 会在运行时覆盖部分值；不要在两个地方各维护一份尺寸真值。
2. `ActorList`、`CardActions`、`CommandActions` 和角色详情中的 `LearnedSchools` 是**运行时内容容器**；编辑它们的尺寸、主题和布局即可，不要把固定角色/卡牌作为运行节点保存在场景里。
3. `2.5D` 的道路与建筑几何已保存为原生 MeshInstance3D / StaticBody3D；调整立面时应同步检查其碰撞、镜头、地面尺度。该 QA 原型不影响正式平江府四区连接。
4. 过场 `CinematicText` 使用 Godot AnimationPlayer 的 `fade_in`；探索、对白、结算 Label 的文字来自当前剧情 Resource，直接修改初始文本只影响编辑器预览；**位置、字号、样式**可以直接在 Inspector 微调。
5. 请在 1600×1000、1440×900 下复查画面与交互。自动测试只能确认加载、结构和规则未回归，不能替代 GUI 视觉审核。

运行结构检查：`godot --headless --path demos/changfeng-battle --script res://checks/test_native_scene_authoring.gd`。
