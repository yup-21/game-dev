# 《长风浮生录》统一美术风格与 AI 生成提示词模板 V1

> 状态：**制作模板 / candidate baseline**，供整个项目使用，不局限 Demo。继承 [ART_PRODUCTION_STANDARD.md](../standards/ART_PRODUCTION_STANDARD.md)；若有冲突，以运行时 Resource 合同及已批准素材为准。**新角色 Sprite 已确定普通档 328×256／高个档 384×288（宽×高）、身高 100 源像素/米**；其他待定尺寸、色板和帧数不因此冻结。AI 生成图一律先作为 `candidate`，不能自动替换 `in_use`。

## 1. 全项目共同视觉语言（Style DNA）

- 类型：原创中国武侠、精细 2D 手绘、轻厚涂与克制水墨；清晰造型轮廓、真实衣料/石木/金属材质，避免塑料感、全局霓虹和过度装饰。
- 画面关系：角色与场景都使用自然反射的冷暖光；主体可读性优先于细节堆砌。HD-2D **只指构图、固定镜头、地面纵深、前后景与遮挡**，不强制像素化，不使用 3D 棋盘叠背景。
- 推荐色彩锚点（待确认色板）：墨青 `#243A41`、雨夜蓝 `#3A5666`、竹青 `#63847A`、宣纸米 `#D8CCB3`、灯笼金 `#C99350`、朱砂 `#9A4A42`。这些不是所有素材都必须包含的六色，而是统一冷暖、饱和度与材质关系的参考。
- 角色身份一致性优先：脸型、发冠、服装层次、主辅色、武器、标志物跨立绘/动作/UI 头像均不变。仅镜头与细节密度不同。
- 视觉层级：场景低对比、角色中高对比、当前交互高对比、VFX 短时最高对比；不可用 VFX 遮蔽脚点、目标、CTB。
- 不得直接复制现有商业游戏的人物、UI、商标、图案；风格描述不能使用“与某作品完全一样”作为终稿验收要求。

### 全局短风格（按需附加一次）

```text
Original hand-painted 2D wuxia game art, restrained ink-wash texture,
clear silhouettes, natural materials, muted cool palette with warm accents.
```

### 反向词（仅遇到相关问题时补充）

```text
photorealistic, 3D render, neon, plastic, text, logo, watermark
```

**发送原则：** Agent 先完成角色、规格、构图、帧数等选择，再将类别短模板中的**全部占位符替换为唯一确定值**，附必要参考图后发送。禁止把 `{变量}`、`A/B` 备选项、尺寸档位选择、`自行判断/任选/视情况` 等决策交给生图模型；不拼接规范、Skill、检查清单或长篇反向词。重试由 Agent 先改定参数，再发送完整确定版提示词。透明 Alpha、分层、脚点、帧序与精确尺寸单独技术验收。

## 2. 可复用变量与生成顺序

| 变量 | 含义 | 示例 |
| --- | --- | --- |
| `{asset_id}` | 稳定标识 | `shen_changfeng` |
| `{asset_type}` | portrait / sprite / environment / icon / card / ui / vfx | `sprite` |
| `{identity_lock}` | 身份锁定描述 | 蓝灰短行衣、墨发束冠、直剑 |
| `{reference_images}` | 已批准设定板、立绘及调色参考 | 明确上传的源图 |
| `{palette}` | 此资产的主辅色 | 墨青/冷蓝/温金 |
| `{camera}` | 视角、地平线、光源 | 轻俯视、固定镜头 |
| `{dimensions}` | 目标像素尺寸 | `1600x1000` |
| `{alpha}` | 是否真透明、哪些区域透明 | RGBA |
| `{do_not_change}` | 严禁漂移的身份和结构 | 武器握法、鞋底基点 |

**生产步骤**：确认参考图和身份/镜头 → 生成候选 → 机器验收 → Godot 预览 → 明确替换绑定。保留实际提示词及对应 Resource，不要求为简化提示词再增加审批或历史字段。

## 3. 角色设定图：Character Design Sheet

目标：**先固定身份，再生成其他资产**。建议设计板为 2048×1536 PNG（候选基线；构图可以变化），应展示正面、背面、左右轮廓、武器、配饰特写与色板；各视图使用一致比例。

```text
Hand-painted wuxia character design sheet, {dimensions}px: {asset_id}, {identity_lock}.
Personality: {age_personality}; silhouette: {silhouette}; hair: {hair}.
Costume: {costume_materials}; equipment: {weapon}; colors: {palette}.
Front/back/left/right views at equal scale, one weapon detail and color swatches.
Same face and outfit in every view; neutral background, no labels.
```

验收：人物身份 4 视图完全一致；武器和左右手无漂移；人工确认后把设定板作为所有后续生成任务的首要图像参考。

## 4. 人物立绘与头像：Portrait

建议输出透明 RGBA PNG/WebP（立绘母版建议长边 2048px 以上，非硬性运行时合同）；构图保留剑、衣摆和头发安全边距，背景可单独生成，**不要以纯色背景冒充 Alpha**。

```text
Full-body hand-painted wuxia portrait, {dimensions}px, of {asset_id}, matching the attached
approved character sheet. Identity: {identity_lock}; palette: {palette}.
Natural pose, complete weapon and feet, soft light from {light_direction}.
Single figure, transparent RGBA, clean edges and safe margins; no scene or text.
```

头像从同一批准立绘/设定图裁切或基于参考重绘；面部辨识、发冠和服装配色必须一致，避免单独再生成另一个“同名角色”。

## 5. 游戏内 2D 角色：Sprite / Animation Atlas

**新战斗角色精灵图已定稿**：普通档单格 **328×256px**，高个档例外 **384×288px**；源人物自然站姿高度 `round(height_m×100)`，100–220px。**AI 每张生成固定 5×5、25 格**；标准化后普通档整图 **1640×1280**，高个档 **1920×1440**。这些是后处理成品规格，生图模型并不能可靠强制输出精确宽高。运行时 `.tres` 支持独立 Clip Atlas、任意合法列行、脚点/帧序/时长；旧图保留。

制作方法：Agent 对 12 组动作分别分镜、按角色身高/武器选择整角色唯一 W×H 格档，再把动作的实际帧序持续填入每张 5×5 AI Sheet。**一张图可以跨多个动作，也可在第 25 格结束后让当前动作从下一张第 1 格继续**；普通档后处理为 1640×1280。提示词只提供角色参考、5×5 布局、格位动作/帧号、已选身份武器和局部姿势，不把精确像素当作生图设置。先核对 AI 输出的等格布局，再统一等比变换与透明补边，逐格机械切分、验收；失败不靠强制拉伸/裁切掩盖。

**生图入口**：角色逐帧描述只作为分镜数据，不再单独使用单帧生图模板。实际调用下文 §5.1 的多帧 Sheet 简版提示词。

**完整美术生产清单为 12 组**：`idle` 待机、`walk` 行走、`run` 跑步、**四套按当前角色武器契约定义的攻击变体**、`skill` 技能、`evade` 闪避、`guard` 格挡、`hit` 受击、`defeat` 倒地。单剑角色可用 `attack_thrust/attack_overhead/attack_sweep/attack_heavy` 作为示例，其他武器应选择适合其形制、握法和打击方式的攻击。每组分别分镜与验收；合图由程序自动完成。

**当前原生动作合同**：`idle/walk/run/attack1/attack2/attack3/attack4/skill/evade/guard/hit/defeat` 共 12 组。每名角色按其武器／徒手设计四种不同攻击，单剑直刺、下劈、横斩、蓄力重击仅作分镜范例；正式 Clip 的 `action` 字段使用 `attack1-4`，不是这四个范例名称。连携是对已配置攻击的时序编排，不单独绘制固定 `combo`；旧 `move/attack/combo` 只在明确配置的存量 Profile 中可用，不能静默代替缺失动作。每组有自己的循环／复位合同，技能可绑定指定动作和有效帧 VFX Cue；逐帧时长与表现根位移需要写入原生 Clip 才会生效。

### 5.1 AI 默认生成：一张多帧动作 Sprite Sheet

按 [精灵动画生产与验收合同](../standards/SPRITE_ANIMATION_QA.md) 执行。AI **每次生成一张固定 5 列×5 行的多动作 Sprite Sheet**，25 个行优先格位分别对应一个确定的 `action_id + action_frame_index`；各动作 N 由 §5.2 分镜决定，不能用 25 反推动作长度。原图允许模型自身分辨率，普通档经程序标准化后单格 328×256、整图 1640×1280（高个档保留 384×288 / 1920×1440）。末批不足 25 时尾部保持透明，不为凑格重复帧。

**统一坐标约定**：以批准的战斗待机帧作为所有动作的身份、`pose_local`、比例和朝向基准；逻辑 O 是待机骨盆地面投影（+x 右、+y 下），地线及镜头固定。一个 Sheet 内各格的 O 位于**相同格内相对坐标**，不能按每格不透明轮廓单独居中/缩放。分镜单独保存世界移动计划；**生图只画相对于 O 的局部姿态，不把整个人的世界前冲/后退位移烘焙进帧图**。当前 `WuxiaActorAnimationClip.root_offsets` 仅移动 Sprite2D 的局部显示位置，不能作为战斗角色的世界位移；普通非循环 Clip 的末帧视觉偏移必须归零。`defeat` 停留在倒地终止态，`idle/walk/run` 检查首尾循环。

**默认生成与验收顺序**：

1. 附角色获准设定和 `weapon_contract`（武器/徒手、数量、尺寸与握持方式），固定侧视基准与统一 O。不要从其他角色套用武器或镜头。
2. 从 §5.2 取得各动作独立真实 N、逐帧姿势。Agent 固定整角色 W×H、`character_height_px=round(height_m×100)` 与共同 O，按动作既定顺序持续填入每张 5×5 的 25 个格位；生成 `batch_id/cell_index(0..24)/action_id/action_frame_index/pose`，跨批接续同一动作的下一帧。示例：`walk` 1–8、`run` 1–8、`attack1` 1–9；若 `attack1` 只有 8 帧，第 25 格应填下一动作 1 帧。最后一批尾格可透明。
3. Agent 将下方模板中的角色、装备、五行格位映射与局部姿势全部填成确定值，附已批准参考图；不让生图模型再判断动作数或格位，亦不要求强制生成 1640×1280。禁止文字、边框、残影和跨格。
4. **先按原始 5×5 验证布局，再标准化**：模型返回尺寸并不可靠，必须检查 25 格是否可按五列五行分离，不能用自动图像理解“猜”帧顺序。只对全批做共同的等比变换和透明补边，保持 O、人物比例及武器完整，普通档输出 1640×1280、高个档输出 1920×1440，禁止非等比拉伸、逐格单独缩放、紧裁切。若无法保持人物源身高或边距、无法可靠定位格子/出现截断，拒绝重生成。标准化后按 W×H 机械拆 25 格，校验真 Alpha、每格至少 8px 透明边距、有效帧映射、最后批次空格透明。
5. 按 `batch_id/cell_index -> action_id/action_frame_index` 聚合跨批片段，检查每动作第 1..N 帧全部且无重复/错序，逐动作预览连续性、循环/复位、承重与根位移；最后程序按统一 O 装配为运行时 Atlas 与原生有序绝对帧索引。Godot 不直接按原始混合动作源图自动分组。

**简版多帧 Sheet 母提示词**（仅传下面模板、角色基准图和选中分镜；完整检测合同不拼入生图请求）：

```text
Transparent hand-painted 2D wuxia sprite sheet: exactly 5 columns × 5 rows, row-major.
Match approved character reference; equipment: {weapon_contract}; fixed right-facing side view.
Cell assignments and local poses: {batch_25_cell_action_frame_pose_list}.
One complete same-sized figure per cell, same foot baseline/root, no baked world translation.
Only final unused cells transparent; no clipping, neighboring-cell spill, borders or text.
```

**格数如何生效**：新 AI Sheet 的 **5×5 是绘图布局指令，不是接口参数**；提示词中不靠 `1640×1280` 保证分辨率。工具先识别并核对布局，再按统一等比缩放/透明补边实现最终 W×H/5×5，填入候选 Resource 的真实尺寸与 `columns=5/rows=5`，生成混合动作帧映射后才能拆格装配。模型画错 5×5 或内容溢出即保留 candidate 返工。

**动作分镜检查示例**（下表的位移只记录在分镜，不发送为生图像素偏移）：

| 动作 | 分镜需要说明的力学变化 |
| --- | --- |
| idle | 后脚承重，躯干轻微呼吸，支撑鞋底稳定，首尾近似闭环 |
| walk | 蹬地、摆腿、落脚、换脚承重完整循环，步幅、重心、腿摆对应，不做脚滑 |
| run | 快速蹬地、跨步、腾空/落脚、换脚及手臂摆动，循环速度与步幅明显不同于 walk |
| attack variants | 每名角色按 `weapon_contract` 制作四套适用攻击；单剑角色可采用 §5.2 的直刺/下劈/横斩/蓄力重击示例，明确承重、打击轨迹、根位移与收势 |
| skill | 依具体武学设计蓄势、释放、接触与恢复，不用通用攻击动作冒充专属技能 |
| evade | 相对面朝方向向后闪避；`evade_style` 可选后撤步、后滑步、后翻滚、后跃；蹬地、落地、复位，不抹掉向后位移 |
| guard | 按角色武器或徒手防御方式架挡/卸力→承重缓冲→短暂稳定→撤架归位，接触和支撑不乱跳 |
| hit | 受力反应、退让或缓冲、恢复待机，禁止突然无原因反弹 |
| defeat | 失衡→膝/躯干接地→最终静止倒地；这是不恢复站姿的终止例外 |

**提示词精简原则**：Agent 先锁角色尺寸档、逐动作真实 N、逐格序列、统一 O；实际绘图文本只写已定 5×5 行优先五行格位、参考角色/装备和姿势，**不向生图模型要求精确像素或发送世界位移/运行时 `root_offsets`**。导出程序承担 328×256/1640×1280 标准化和客观 QA；源图 100px/米不是现行运行时 200 世界像素。

### 5.2 AI 动作分镜：先规划帧数，再逐帧绘图

**默认先运行下列简版分镜提示词（仅输出文本，不生图）**。每个动作分镜单独确定真实 N，再按动作顺序跨动作/跨批组装成固定 5×5 的 25 格；不为了填满格子修改动作帧数。`evade` 的动作描述必须为“向后闪避”，并按角色确定方式。

```text
为2D侧视武侠角色规划动作分镜，仅输出文本。
参考：{approved_character_reference}；装备：{weapon_contract}。
动作：{action_id}，{action_description}；时长：{known_duration_ms_or_unknown}。
根点 O：{canonical_idle_pose_and_ground_root}；位移：{locomotion_or_root_motion_policy}。
按动作变化自主决定 N 帧；逐帧简表列序号、时间、阶段、关键/间帧、
姿势、支撑与重心、武器轨迹、root_offset、相邻变化。
循环动作首尾衔接；defeat 倒地保持，其他动作归待机。
禁止无变化的凑帧；输出 N 和帧序。
```

**攻击动画组：每名角色基于 `weapon_contract` 设计四套独立攻击，连携不另画固定动作。** 下表只是沈长风等**单剑角色的动作示例**，不作为所有武器的强制招式；其他角色可保留四个攻击槽位并使用适合该武器的语义 ID 和运动方式。

| 制作 ID | 独立动作描述（填入 `{action_description}`） | 分镜重点 |
| --- | --- | --- |
| `attack_thrust`（攻击1：直刺） | 侧身戒备→屈膝后脚蓄力→后脚蹬地、前脚踏出→右手单剑沿前方连续直线突刺→前脚承重→自然收剑 | 突刺的前向根位移、剑尖直线轨迹、无无故后弹 |
| `attack_overhead`（攻击2：下劈） | 侧身戒备→重心调整、右手单剑上举→身体略上提蓄力→沉肩屈膝使剑自上向前下方劈落→缓冲并归位 | 上下重心变化、剑尖纵向弧线、不得只甩手臂 |
| `attack_sweep`（攻击3：横斩） | 侧身戒备→向侧后方收剑、腰胯预旋→支撑脚发力、骨盆带动躯干转动→右手单剑水平横斩→惯性跟随并收势 | 横向剑路连续、腰胯带动、保持侧视不可突变正面 |
| `attack_heavy`（攻击4：蓄力重击） | 屈膝沉重心、右手单剑后上方大幅蓄力→短暂蓄势→后脚强力蹬地、骨盆肩臂依次爆发→重击终点→自然惯性和踏步恢复 | 蓄力与爆发节奏对比、较大根位移、**仍是一柄右手单剑** |

- 每名角色依据自己的武器/徒手契约规划四套攻击的真实帧数、阶段与复位；制作 ID 和运行时 `attack1-4` 对应。相邻动作允许同一张 5×5 源 Sheet 混排，但每格必须保存动作内帧号；`combo` 仅编排现有攻击，不额外生成固定动作。
- **补全其余动作**：`idle` 呼吸戒备循环、`walk` 蹬地换脚循环、`run` 快速跨步循环、`skill` 专属招式与复位、`evade` 蹬地落脚与合理位移、`guard` 架剑承压与撤架、`hit` 受力缓冲与恢复、`defeat` 倒地接触直至静止。每种均按 §2.2 的独立阶段和首尾合同生成，不能把 walk/run 混成 move 的一套动作，也不能让 defeat 自动站起。
- **图集布局选择**：每张新 AI Sheet 固定 5×5，按从左到右、自上而下编号 0..24，格位连续排入多种动作，动作可以跨批次。记录 `batch_id+cell_index -> action_id+action_frame_index`，装配时还原为各动作真实 N 与有序绝对帧索引、循环/复位标记。运行时 Atlas 可重打包，不强制 5×5。
- **运行时边界**：`attack_thrust/attack_overhead/attack_sweep/attack_heavy` 等是示例分镜标签，正式 `clip.action` 统一写 `attack1-4`；Skill 或武学 Resource 仅绑定一个已存在的动作 ID，VFX 通过 Cue 或事件绑定。没有实际 Godot 播放与时序验证的素材仍只算未验收候选，不宣称完整接入。
- **审查分工**：机器核查分镜帧号/数量/时间/字段完整、PNG Alpha、格子边距和零重叠；AI 视觉只初筛身份、与角色武器契约不符的武器增减/握持、侧视及明显姿态跳变；真实支撑脚识别与动作合理性不能自动保证，疑难帧与最终少量样片再人工复核。分镜 `time_ms` 仅是离线节奏建议；必须映射到 `WuxiaActorAnimationClip.frame_durations` 才会影响 Godot 逐帧停留时间。

## 6. 场景设定与可运行地图贴图

**城镇、街区、大地图补充**：横向主街、竖向街巷与十字街口使用同一尺度。生成前先阅读 [城镇与大地图统一比例尺规范](../standards/TOWN_MAP_SCALE_PRODUCTION.md)，使用 `art-production/tools/scene_scale_guide.py` 生成的透明标尺图作为参考。普通角色始终 200 世界像素高，街区以 1600×1000 单屏为单位生成；场景各层同坐标、同画布、无运行时二次拉伸。城市通过街区连接表现，不靠一张超大画布缩小角色。纵向单屏仍是 1600×1000 的横屏画布；连续南北长街可以使用 1600×2400 等完整世界画布，并由固定 1600×1000 游戏视口跟随人物滚动，不旋转背景、不把角色向远处缩小。通过 `--orientation vertical`（南北）、`--orientation mixed`（十字街口）输出对应的参考层。

**重要：此比例尺是构图和后期校准合同，不是仅凭 AI 提示词就能保证的像素精度。**

**正式 2D 城镇统一镜头（平江府首轮视角比选）**：固定轻俯视、近似正交的弱透视，保留中式建筑立面；可走路面不得向远处消失点快速收缩。横向可走带连通左右图边，纵向可走廊道连通上下图边；桥、水、屋檐不能阻塞已配置出口。远景城楼、河岸、山体可有更强纵深感，但不是可进入的真实地面。同城区域统一人物高度、门洞比例、石板尺度和视角；详见 `TOWN_MAP_SCALE_PRODUCTION.md` 的“全游戏统一视角”。独立的无屋顶 3D 平面贴图 2.5D 原型用于验证另一种表现方式，不改变正式 2D 分层地图的镜头合同。

技术合同：游戏单屏视口基准为 **1600×1000 / 16:10**，另验 1440×900；真实场景图层尺寸由当前 `WuxiaSceneArtProfile.reference_size` 和 Map/Chapter 世界画布决定，连续纵向长图可为 1600×2000／2400。正式交付同尺寸、同原点的 `background`、`ground` 与按需 `foreground`、`weather`；碰撞、出生点、可走地面仍来自 Map Resource。**生成一张漂亮的整图不等于完成可玩地图。**

### 场景设定图

```text
Hand-painted wuxia scene, {dimensions}px: {location}, {season_time_weather}.
Fixed {camera} view; landmarks: {landmarks}; palette: {palette}.
Clear walkable area: {playable_polygon_description}, matching attached scale guide.
Foreground/midground/background depth; no characters, text, UI or grid.
```

### 分层输出（逐层使用同一构图参考）

```text
Use the ATTACHED APPROVED environment master as strict layout reference.
Draw only {layer_name}: {layer_description}, canvas {dimensions}.
Keep the same camera and landmark coordinates; all other areas transparent RGBA.
```

- background：远山、天空、远岸，不承载角色地面。
- ground：可走道路/桥面/地面纹理，保留清晰接触面。
- foreground：近景竹枝、栏杆、屋檐等可遮挡对象，真实透明。
- weather：雨线、雾层等可关闭的独立效果，不把雨永久画死在人物前面。

### 竖向街道与十字街口补充提示词

使用 `--orientation vertical`／`mixed` 的透明比例尺参考图控制南北街与十字街口。实际世界画布可为 1600×1000 或 1600×2400 等；提示词只给出参考图、布局和实际尺寸，**80px/单位、200px 运行时人物、24px 占位**由场景验收检查，不必反复写进生图提示词。

```text
手绘武侠城镇：{street_layout_description}；画布 {dimensions}。
固定2.5D斜俯视，严格参考附图的透视和比例。
道路与出入口：{street_exits}；建筑地标：{landmarks}。
店铺紧凑、可行走；建筑门洞尺度一致，无强消失点透视。
不画人物、标尺线、文字或UI。
```

Agent 根据地图定义预先选 `vertical` 或 `mixed`，把街道走向、相交关系、出口位置和目标画布写成**唯一确定**的 `{street_layout_description}`、`{street_exits}` 与 `{dimensions}`，不把“纵向／十字”交给生图模型选。十字街口需上/下/左/右道路在中心真实连通，并分别设立 north/south/east/west 出口标记。`WuxiaMapDefinition.primary_axis` 标明画面主轴，`zone_exit` 标记目标街区与入口 ID；这两项是 Godot 制作数据，不意味着现已实现跨区自动加载。

## 7. 装备与物品图标

建议候选规格：母版 **512×512 RGBA**，导出 128×128、64×64 等尺寸做可读性验收；尺寸不是当前已冻结的引擎强制值。以**单一斜侧视角、统一光源、统一材质笔触与留白**为准，物品辨识度高于背景装饰。

```text
Hand-painted wuxia {item_category} icon, {dimensions}px: {item_name}, {item_description}.
Three-quarter view, soft top-left light, palette {palette}.
Single centered object, transparent RGBA, generous margin, readable at 64px.
No text, border or rarity effect.
```

稀有度边框、数量、装备槽标识全部由 UI 分层绘制，避免同一图标为不同稀有度重新生成。

## 8. 武学卡面素材

将 **卡牌框架**、**武学插画**、**规则文字**分离。已有卡面保持兼容；本模板主要用于后续新增武学。母版建议竖幅 **768×1024** 作为候选，最终按现有 UI 组件的实际裁切尺寸验收。

```text
Vertical hand-painted wuxia card illustration, {dimensions}px: {technique_name}, {school_identity}.
Match character reference {identity_lock}; decisive pose: {action_pose}.
Ink-brush energy: {vfx_palette}; clear silhouette and safe crop margins.
Illustration only, no words, numbers or card frame.
```

一张武学卡不同 Usage 使用同一主体卡画；派生招式可使用局部特效叠层，除非确有独立动画与身份需求。

## 9. 游戏 UI：HUD / CTB / 按钮 / 装饰

UI 使用统一的“宣纸、漆木、青铜、少量温金”材质体系，**低装饰密度、信息优先**。目标：战斗区不被 UI 压缩；右侧 CTB 跑轴保留头像动态运动，底部扇形手牌有明确可点区域，敌方状态与 CLASH 响应可读。

```text
Wuxia UI component {component_name}, state {interaction_state}, {dimensions}px; shape: {interaction_area}.
Lacquer, aged bronze and parchment, palette {palette}; simple ornament.
Flat front view, transparent RGBA, scalable border, margin {safe_margin}.
No text or screenshot; draw only the specified state.
```

推荐分件：卡槽底板、卡框、角色头像框、CTB 轴底纹、轴上标记、状态徽记、按钮底板、面板九宫格切片。文本、图标、进度条和跑轴头像由 Godot 控件绘制；不要让 AI 将文字直接烧进背景。

## 10. 战斗 VFX：剑气 / 格挡 / 命中 / 闪避 / 连携

建议先做透明逐帧序列、再组图集或动画 Resource；原生 `AssetRegistry.texture_for_event()` 可继续复用。特效不影响 `BattleModel` 结算。不要在本轮把精确帧数/分辨率宣称为已锁定；按实际镜头比例验证。

```text
Transparent 2D wuxia VFX frame, {dimensions}px: {effect_type}, phase {phase}.
Trajectory: {trajectory}; colors: {effect_palette}; restrained ink-brush glow.
Clear force direction, stable framing, fade naturally; no character, scene or text.
```

需分别验收 Slash（清晰方向）、Guard（短促金属碰撞）、Impact（不遮血条）、Evade（残影速度）、Combo（与普通斩击区分）。

## 11. 不可只靠生成模型保证的技术门槛

| 项目 | 自动检查 | 人工审查 |
| --- | --- | --- |
| 文件与引用 | 路径、存在、解码、Atlas 能整除、`.tres` 加载 | 命名、角色对应 |
| Alpha | 是否有透明通道、可见边缘像素范围 | 发丝、剑尖、残影色边 |
| 角色动画 | 索引合法、帧区域尺寸、动作集合齐备 | 脚点不漂、姿势不跳、无肢体漂移 |
| 场景 | 视口基准 1600×1000；图层全部匹配当前 SceneArtProfile / Map / Chapter 的实际画布尺寸、同原点、引用合法 | 可行走面、遮挡、视角与路径一致 |
| UI/图标 | 尺寸、边距、纹理引用 | 64px 可读、对比度、操作焦点 |
| VFX | 帧尺寸与事件绑定 | 特效时机、方向、遮挡、重复战斗性能 |
| 权属 | source / rights 字段齐备 | 商用授权、与既有作品近似性 |

验收必须包含 Godot Editor 中实际播放，以及 1600×1000 和 1440×900 的 GUI 截图。必须保留候选图和原始制作提示，不以一次成功生图宣称“可量产”。

## 12. 命名与可复制的工作单

候选原稿可按 `{asset_type}_{asset_id}_{action_or_view}_vNN.png` 命名；正式导入文件以 `assets/imported/README.md` 的语义名为准。

每次制作只复制 [`asset-work-order.md`](../templates/asset-work-order.md)，记录**实际发送的短提示词**、参考图、对应候选／目标 Godot Resource 与必要网格测量；不在本文件维护另一套工作单。正式运行只读取 `.tres` 与 Content Manifest。

## 13. 第一轮冻结试点（P0）

1. 批准沈长风设定板与冷暖色板，确定敌方追兵首领的独立身份。
2. 用同一设定生成两人立绘、12 组动作关键帧与实际可播放中间帧，锁定脚点、方向和帧尺寸。
3. 从雨夜断桥完整概念图制作 1600×1000 四层场景，校验地图几何与角色站位。
4. 做一套剑气/格挡/命中 VFX、3–5 个物品图标、一张武学插画、一套 CTB/卡槽/状态框，全部应用共同色板。
5. 实机并排审查角色、场景、卡牌、图标与 UI 的一致性；人工批准后再冻结 V2 参数及开始批量生产。

**完成定义**：不是提示词“写好”，而是多类别素材基于同一 identity/style reference 稳定复现、透明/脚点/分层通过、Godot 实机一致并批准。

## 战斗角色贴图比例尺补充

**此处是制作验收说明，不再附加给图像模型。** 新角色动作实际生图仅使用 §5.1 的简短 5×5 混合动作模板，传已批准参考图、武器契约、批次格位／动作帧号和确定的局部姿势；**不在生图提示词强制填写单格像素尺寸或站姿高度**。328×256／384×288 单格、100 源像素/米和整图标准化由 Agent 预先规划并在后处理与 QA 中验证。

> 新角色精灵图每格 **328×256 普通档或 384×288 高个档**（宽×高）；人物自然站姿高度按角色设计 **1 米 = 100 源像素** 换算（1.0–2.2 米，人物 100–220px）。每个动作保持同一头身比、脚底基线、统一 O、完整侧面轮廓，格子四边至少 8px 真透明留白，不出现跨格的武器、衣摆或脚趾。只改变动作姿势，不改变人物源像素比例。生成结果必须经过机械拆格和视觉预览确认。

现有 Demo **仍默认将普通角色缩放到 200 世界像素高**，`1 战斗单位 = 80 世界像素`、碰撞半径 24px；源图 100px/米是新制作标准，运行时按角色真实身高显示尚待 Resource/导入器迁移。历史 256×256 图集照旧引用，不按新标准无损迁移前不得声称合规；AI 提示词不保证精确尺寸，必须通过图集工具、脚点预览和原生 Resource 校验。
