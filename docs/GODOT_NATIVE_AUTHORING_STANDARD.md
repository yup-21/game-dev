# 《长风浮生录》Godot 原生内容开发规范 V2

> **规范性文件，适用整个游戏。** [内容制作操作指南](changfeng-native-authoring.md)与 [Godot 原生编辑入口](../demos/changfeng-battle/docs/NATIVE_AUTHORING.md)是本规范的操作说明；[美术制作规范](../art-production/standards/ART_PRODUCTION_STANDARD.md)和专项 QA 仍负责画面、像素、分镜及审批，不由本文重复定义。历史 R 系列文档只记录迁移经过。

## 1. 核心原则与边界

1. **一个字段只有一个编辑真源。** Godot 编辑器是正式内容的编辑、预览和验收工作台；自研导入器负责候选素材的校验、转换、绑定和可回滚替换，不能成为平行的最终场景编辑器。
2. **规则与表现分离。** `BattleModel`／`CombatResolver` 唯一决定战斗状态和合法结算。动画、VFX、HUD、剧情演出只消费状态及语义事件，不能通过改动演出时长、Sprite 位置或 UI 改写 HP、Qi、CTB、命中和世界移动。
3. **运行时内容只使用 Godot 原生结构。** 强类型 `.tres`、`PackedScene`／`.tscn`、纹理及脚本是正式入口；`data/content_manifest.tres` 显式注册需要发现的正式定义。候选工作单、图集来源映射、GIF 和离线 CSV／JSON 均不是第二套运行时配置。
4. **生产格式与运行格式分离。** 5×5 混合动作 AI Sheet、逐动作 GIF、独立 PNG 帧均可作为满足专项合同的**候选来源**；Godot 中的新角色动作优先交付 `SpriteFrames.tres`，既有 Atlas／Clip 保留兼容，不能以“原生化”为由重绘或覆写合格美术。
5. **已批准的美术合同不变。** 两档源图单格 328×256、384×288，5×5 AI 原图布局、角色自然身高 100 源像素／米、每格至少 8px 真透明边距、12 组新角色标准动作、80 世界像素／单位、默认 200 世界像素可见高度、24px 地面占位半径及地图分层尺寸，均按现行美术与比例尺规范执行。源像素不能直接冒充世界像素。
6. **审核独立于技术导入。** 资产状态仅 `candidate`／`in_use`；人工视觉／权属批准写入工作单，`approved` 不是第三种状态。未获得替换目标的明确批准，不得覆盖已有正式美术或偷换引用；技术可加载不代表画面合格。

## 2. 编辑真源矩阵

| 内容或属性 | 唯一编辑真源 | 消费者或同步结果 | 禁止的第二写入来源 |
| --- | --- | --- | --- |
| 角色身份、属性、装备、门派、技能、剧情与遭遇 | `Wuxia*Definition` 等强类型 `.tres` | `ContentRegistry`、`CharacterFactory`、章节／战斗规则 | 在 HUD、动画或按角色 ID 的脚本分支重复定义 |
| 正式内容发现与依赖 | `data/content_manifest.tres` 的对应数组、已登记 `.tres` 的跨资源引用 | 游戏启动加载、检查与导出 | 目录扫描、候选 Manifest、离线 JSON |
| **新角色**逐动作帧序、FPS、单帧时长与循环 | `WuxiaActorAnimationProfile.native_frames` 指向的 `SpriteFrames.tres` | `AnimatedSprite2D`／表现时间轴 | 同时另写一套可编辑 Clip 绝对帧序 |
| 角色统一脚点、比例、朝向约定与兼容映射 | `WuxiaActorAnimationProfile` `.tres` | 战斗及剧情角色实例 | 在共享角色 `.tscn` 写死某个角色的贴图或比例 |
| **旧角色**图集布局及动作索引（未提供 `native_frames`） | `WuxiaActorAnimationProfile`／`WuxiaActorAnimationClip` | 兼容播放器 | 未声明的九动作／十二动作隐式回退 |
| **原生探索区域**的可走多边形、障碍、标记、出生点及出口 | 带 `source_map` 的原生地图 `.tscn` 下 `WalkableArea/Boundary`、`Obstacles`、`Markers`、`Exits` | 显式验证并同步到 `WuxiaMapDefinition.tres`，供既有 MapBake／探索消费者使用 | 再用旧画笔直接修改同一地图 `.tres` 的几何 |
| **战斗地图**的合法地形、站位、战斗长度及碰撞 | `WuxiaMapDefinition`／`WuxiaGridMapDefinition` 与统一 `combat_scale.gd` | BattleModel、GRID／FREE／LOS | 在战斗背景 `.tscn` 拖动装饰以变更合法玩法区域 |
| 战斗地图、剧情地图的图像图层、视觉校准、遮挡和镜头 | 对应可编辑 `.tscn`；纹理源引用由 `WuxiaSceneArtProfile` 或场景节点声明 | 原生 Node2D／Control 场景 | 导入器重新生成整棵场景树或覆盖人工变换 |
| HUD、CTB、卡面、对话框的布局与视觉状态 | `Control`／`Theme`／原生 UI `.tscn` | 脚本仅注入动态数据与信号 | 运行时代码重建静态位置、固定人物／卡牌节点 |
| VFX 形状、层级、视觉动画 | 可复用 `PackedScene`（如 `combat_burst.tscn`）及 `AnimationPlayer` | `WuxiaVFXDefinition`、技能 Cue／ActionTimeline 选择与触发 | 通过 VFX 脚本执行战斗规则或重建已可编辑的形状 |
| 攻击有效期、连携、反应与视觉 Cue 时间点 | `BattleActionTimeline` 与对应技能／VFX `.tres` | 动画和 VFX 按事件播放 | 将贴图帧数／VFX 结束回调作为规则结算条件 |

**区分地图类型：**原生探索地图的**几何**以 `.tscn` 为编辑来源，`.tres` 是同步快照；战斗地图的**玩法几何**仍以 `.tres` 为准，`.tscn` 是表现来源。未迁移的旧地图或章节在完成显式原生场景绑定以前，继续以其已有 `.tres` 为来源。不得自动推断任何 `.tscn` 与 `.tres` 的双向同步。

## 3. 新角色与动画的制作／绑定

1. 在 `art-production/candidates/` 建工作单、身份设定和候选图；先按 [角色美术规范](../art-production/standards/ART_PRODUCTION_STANDARD.md)与 [动画 QA](../art-production/standards/SPRITE_ANIMATION_QA.md)规划**每个动作真实帧数**、人物比例、武器契约与脚点，再选择来源形式。
2. **5×5 AI Sheet 路径**：先验证完整 25 格映射、统一标准化与拆格、跨批动作续帧；按明确的 `batch_id/cell_index -> action_id/action_frame_index` 输出合格帧。5×5 是**AI 制作批次**，不要求最终 `SpriteFrames` 或运行时 Atlas 保持 5×5。Godot Art Production Dock 的自由装配支持每帧独立矩形、可选手绘套索/多边形 Alpha 蒙版及统一的等比标准化；默认直接导出 `SpriteFrames.tres`，或显式选旧 Clip 兼容输出。不会自动判断角色轮廓、补出被遮挡像素或改变单帧人物比例。
3. **逐动作 GIF 路径**：每组动作一张实际存在的完整透明 GIF，登记独立候选 `.tres`，声明实际源像素和 `action_id`；GIF 不强制填写 C×R 网格。使用 `Native GIF` Dock 校验、按原时长预览、确认映射并生成原生 `SpriteFrames.tres`。独立透明 PNG 序列须先按对应导入器要求装配为可审查的动画输入，不假称 GIF Dock 能直接导入任意 PNG 文件夹。
4. **最终 Godot 编辑**：新 GIF 动画在原生 SpriteFrames 面板调整动作帧序、播放速度、逐帧时长与循环；`WuxiaActorAnimationProfile.native_frames` 引用这一资源。Profile 继续维护统一脚点、缩放、朝向参数；`AnimatedSprite2D` 承担帧显示，`AnimationPlayer`／ActionTimeline 管理表现时序和 Cue。已有 Clip 是兼容内容，不能与 `native_frames` 再分别成为同一动作的新帧序真源。
5. 统一动作名 `idle/walk/run/attack1/attack2/attack3/attack4/skill/evade/guard/hit/defeat`。四套攻击按**该角色自己的武器契约**分镜，不强制全员单剑刺劈斩。既有 `move/attack/combo` 及迁移产生的额外动作只用于显式兼容；新 GIF 可分批导入当前剧情实际需要的动作，但正式完整新角色的十二组制作验收不能因此减免。**缺失动作报错，禁止静默回退。**
6. `WuxiaCharacterDefinition` 引用 Profile 并按内容身份登记 Manifest；不往共享 `battle_actor.tscn` 写死人物资产，也不为新角色加特殊规则分支。对已保存、已微调的 `SpriteFrames` 做重复导入须显示目标及哈希保护，不能无声覆写。

当前仓库的原生 `SpriteFrames.tres` 路径均合法：已迁移角色位于 `data/native/sprite_frames/<id>.tres`；`Native GIF` 导入器生成 `data/native/animations/<id>_frames.tres`；新自由装配输出 `data/native/animations/<id>_frames__<hash>.tres`，以保护已经手工修改的版本。三者都可以作为 `WuxiaActorAnimationProfile.native_frames` 的引用目标，**不要为了整理目录擅自移动或双写**。操作见 [GIF 导入指南](../demos/changfeng-battle/docs/NATIVE_ANIMATION_IMPORT.md)和 [Art Production 导入指南](../art-production/tools/GODOT_IMPORTER.md)。

**工具落地边界：**Native GIF Dock 可将逐动作 GIF 导入 SpriteFrames；Art Production 的“自由装配”可将已人工映射、校准、通过 Alpha 检查的 Sheet 自动转换为 SpriteFrames（FPS、时长、循环均写入原生资源），旧 Atlas/Clip 仍可显式选择兼容输出。复杂绘画边缘需人工复核；本功能的自动回归与 Godot GUI 实机验收分别记录，不得把代码接通等同于视觉审批。

**V3 逐帧修复导入（候选后处理）**：`角色动画 V3` Dock 直接接受任意实际尺寸的 GIF／PNG／WebP／JPG，自动登记候选，允许框选、多边形蒙版、擦除／恢复、每帧等比缩放与偏移，在**最终** 328×256 或 384×288 透明画布上执行硬性边距／越界检查。源图的 5×5 和 8px 原始验收仍是**新制 AI 美术的制作目标**，不作为 V3 修复候选加载门槛；逐帧编辑记录不等于对缺帧、人体比例漂移或错误武器的美术批准。只有显式人工批准才可版本化更新单个 `SpriteFrames` 动作，保留其他动作、旧资源和事务撤销；旧 Atlas/Clip 角色未迁移时拒绝隐式清除旧动作。操作见 [V3 工作台指南](../art-production/tools/FRAME_WORKBENCH_V3.md)。

## 4. 地图、HUD 与 VFX 的编辑交接

### 4.1 地图

- 先使用同原点、同尺寸的 `Background/Ground/Foreground/Weather` 图层资产，关联 `WuxiaSceneArtProfile`；缺少必需层立即预检失败。探索地图的原生场景结构以已实现的 `WuxiaNativeMapRegion` 和场景实际节点名为准。
- **探索区域几何微调**：Godot 2D 视图编辑 `WalkableArea/Boundary`、障碍的 `CollisionPolygon2D`、`Markers` 和 `Exits`，保存 `.tscn` 后点根节点 Inspector 的“同步原生节点到地图 .tres”；校验快照与源场景一致，再运行双向换区、出生点防反跳、镜头和比例 QA。
- PJ-01～PJ-04 原生区域场景属于独立集成分支；**是否已在正式分支可见，以实际合并状态及 Godot 文件系统为准**。不为未合并内容伪造默认入口，不能用单张导入贴图代替完整区域联通测试。
- **战斗场景表现微调**：打开 `scenes/maps/illustrated_battle_map.tscn` 修改图像层、校准和遮挡；战斗合法区域仍在地图 `.tres` 中编辑验证。不可从一张背景图片的色彩或透明度自动推导可走地形。
- 对还未接入原生区域场景的旧地图，暂用原 `WuxiaMapDefinition` 画笔；迁移完成后停止把该地图的 `.tres` 几何作为人工编辑入口。跨区连接还需要当前探索入口显式登记区域场景，新增 `.tscn` 不等于自动加入世界图。

### 4.2 HUD/UI

- 在 `scenes/ui/battle_hud.tscn`、`ctb_rail.tscn`、`ctb_marker.tscn` 等原生 UI 场景编辑 Control 锚点、容器布局、主题、九宫格分件、视觉状态和动态动画；游戏数据只通过脚本注入，文字、HP、CTB、卡牌效果不烘焙进贴图。
- 编辑完在 Godot 以 1600×1000 和 1440×900 检查实际鼠标点击、跑轴、遮挡与字号；不能用全屏 UI 概念图替代可复用的 Control。

### 4.3 VFX

- 使用透明帧或纹理分件，在 `scenes/vfx/combat_burst.tscn` 等原生场景内编辑 Node2D、Sprite、`AnimationPlayer` 的持续时间、轨迹、淡出及层级；技能通过 `WuxiaVFXDefinition` 和语义 Cue 选择效果。原有 Atlas VFX 继续兼容。
- VFX 只能播放视觉反馈，不能结算伤害／格挡或改动世界位置；低性能档关闭特效应不影响规则。`WuxiaVFXDefinition` 只能引用真实存在的资源，非法路径在导入／加载阶段失败。

## 5. 自研工具职责及防覆盖约束

| 工具 | 应当负责 | 不应负责 |
| --- | --- | --- |
| Art Production Importer | 验证来源身份、Alpha／尺寸／帧映射、纹理复制、Resource 绑定、预览、事务备份与撤销 | 改写已微调的原生场景坐标、重新决定动作帧语义、自动批准候选 |
| Native GIF Dock | 逐动作 GIF 拆帧、按原始时长预览、生成与绑定 `SpriteFrames.tres` | 推测一个混合图集里动作范围、隐式补动作、覆盖后来人工编辑的帧序 |
| Wuxia Map Editor | 旧 Resource 画笔；原生地图只读检查、显式同步入口 | 在原生地图上直接双向修改 `.tres` 几何造成双真源 |
| Art Exporter／CI | 遍历实际引用、校验原生场景与 Resource 依赖、报告缺失及运行错误 | 将候选目录作为运行时入口、把 headless 通过当成视觉验收 |

导入前必须显示将更新的角色、动作或场景、准确路径和替换范围。修改正在 Godot 中打开的 `.tscn` 前，先 **Ctrl+S 保存并关闭场景**；保留文件哈希校验、原始引用、备份和可撤销事务。已经手工调整的图层位置／脚点／碰撞／Marker／出口不得被重新导入贴图所覆盖；遇到冲突应停止并提示人工选择。路径和资产不可加载、候选 C×R 与真实像素不一致、非空引用失效时直接报错，正式内容不隐式换占位。

## 6. 单个内容的完成定义（DoD）

1. **制作**：原始素材、候选 `.tres`／工作单与实际提示词完整；几何／脚点、帧语义和尺寸符合 [正式美术规范](../art-production/standards/ART_PRODUCTION_STANDARD.md)。
2. **绑定**：对应 `.tres`、`.tscn` 与必要 Manifest 数组引用闭合，只有一个正式动作／场景编辑真源；未批准旧素材不被替换。
3. **编辑器**：Godot 直接打开资源可预览并保存微调，再打开后不回退；原生场景 F6、游戏 F5 可以走到对应角色／地图／UI／VFX。
4. **自动验证**：项目导入无缺失，相关原生内容与工具回归通过；MapBake／GRID／FREE、语义时间轴及旧资源兼容不回退。
5. **人工验收**：1600×1000 与 1440×900 实际 GUI 截图／试玩、动作实速与 VFX 时机、地图双向出口及遮挡；明确登记视觉／权属审核结论。无人执行的 GUI 测试不得标成“通过”。
6. **打包**：通过 Godot 原生 Export Preset 或 CI 构建；验证包内 `.tscn`、`.tres`、纹理与依赖完整，至少启动一次正式入口。

参考命令（使用 Godot 4 与项目现行 CI 版本，先完成资源导入）：

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_native_content_resources.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_native_tool_adapters.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_native_gif_animation.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_native_scene_authoring.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_native_visual_closure.gd
```

## 7. 规范层级与维护

1. **运行时事实**：已实现并经过测试的 Godot 类型、`BattleModel`、`combat_scale.gd`、Manifest 和实际场景结构；冲突时不能仅修改文档假装实现。
2. **本规范**：跨领域资源编辑权、交付接口、导入／验收流程的唯一正式来源。
3. **专业合同**：`art-production/standards/` 仅定义美术制作、像素、构图、动画 QA 与比例尺；不复制本规范的运行时绑定规则。
4. **仓库级 Skills**：只位于 `art-production/skills/`，按相应专业合同执行并引用本文，不在 `.agents/skills` 维护副本。
5. **操作指南与提示词**：`docs/changfeng-native-authoring.md`、`demos/changfeng-battle/docs/`、工作单模板和 AI 短提示词是步骤／模板，不得改变上面已确认的合同。

规则变更先检查运行时代码与关联测试，再更新**对应真源**和引用的 Skill／指南；旧文档保留历史标记与链接，不再复制一套相互竞争的规范正文。
