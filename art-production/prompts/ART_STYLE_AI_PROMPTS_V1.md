# 《长风浮生录》统一美术风格与 AI 生成提示词模板 V1

> 状态：**制作模板 / candidate baseline**，供整个项目使用，不局限 Demo。继承 [ART_PRODUCTION_STANDARD.md](../standards/ART_PRODUCTION_STANDARD.md)；若有冲突，以运行时 Resource 合同及已批准素材为准。本文的建议尺寸、配色和帧数必须通过首个角色与场景试点后才能标记为 frozen。AI 生成图一律先作为 `candidate`；concept/preview 只是制作用途，不能自动替换 `in_use`。

## 1. 全项目共同视觉语言（Style DNA）

- 类型：原创中国武侠、精细 2D 手绘、轻厚涂与克制水墨；清晰造型轮廓、真实衣料/石木/金属材质，避免塑料感、全局霓虹和过度装饰。
- 画面关系：角色与场景都使用自然反射的冷暖光；主体可读性优先于细节堆砌。HD-2D **只指构图、固定镜头、地面纵深、前后景与遮挡**，不强制像素化，不使用 3D 棋盘叠背景。
- 推荐色彩锚点（待确认色板）：墨青 `#243A41`、雨夜蓝 `#3A5666`、竹青 `#63847A`、宣纸米 `#D8CCB3`、灯笼金 `#C99350`、朱砂 `#9A4A42`。这些不是所有素材都必须包含的六色，而是统一冷暖、饱和度与材质关系的参考。
- 角色身份一致性优先：脸型、发冠、服装层次、主辅色、武器、标志物跨立绘/动作/UI 头像均不变。仅镜头与细节密度不同。
- 视觉层级：场景低对比、角色中高对比、当前交互高对比、VFX 短时最高对比；不可用 VFX 遮蔽脚点、目标、CTB。
- 不得直接复制现有商业游戏的人物、UI、商标、图案；风格描述不能使用“与某作品完全一样”作为终稿验收要求。

### 全局母提示词（所有类别都附加）

```text
Original Chinese wuxia fantasy RPG art, premium hand-painted 2D illustration,
cohesive painterly ink-wash accents, elegant restrained brushwork, readable
silhouettes, natural silk/cotton/leather/steel/stone/wood material response,
subtle atmospheric depth, cinematic but functional game art, balanced muted
blue-gray and jade-green palette with restrained warm amber or cinnabar accents,
consistent art direction across character portraits, sprites, environments,
icons, cards and user interface. Original design, no copyrighted character,
no logo, no text, no watermark.
```

### 共用反向约束

```text
photorealistic, 3D render, glossy plastic, anime cel shading, chibi,
exaggerated pixelation, hyper-saturated neon, excessive gold ornament,
random asymmetrical costume details, inconsistent facial features,
modern sci-fi props, illegible silhouette, text, logo, watermark,
UI screenshot, crowded composition, blurry edges, compression artifacts
```

提示词只是视觉约束；透明 Alpha、分层、脚点、帧序、可走地面与真实尺寸需要单独技术验收。模型不可靠地遵循负面提示或精确像素规格时，必须后处理并程序化校验。

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

**生产步骤**：设定板 → 人工选定 identity/color/camera 锚点 → 立绘/场景母版 → 动作关键帧/分层 → 帧间补全及图集装配 → Godot .tres 引用 → 机器检测 → 实机截图与人工批准。一次只改变一个变量，保留原提示词、参考图、seed（如平台支持）、模型版本及修订记录。

## 3. 角色设定图：Character Design Sheet

目标：**先固定身份，再生成其他资产**。建议设计板为 2048×1536 PNG（候选基线；构图可以变化），应展示正面、背面、左右轮廓、武器、配饰特写与色板；各视图使用一致比例。

```text
[GLOBAL STYLE DNA]
Create an ORIGINAL wuxia character design sheet for {asset_id}.
Identity: {identity_lock}. Age and temperament: {age_personality}.
Distinctive silhouette: {silhouette}. Hair/headwear: {hair}.
Layered costume and fabric: {costume_materials}. Weapon: {weapon}.
Palette: {palette}. Include front, back, left and right orthographic
character views at matching scale, weapon close-up when equipped, one fabric detail,
and a small clean color swatch area. Neutral studio lighting; plain warm
neutral background; no environment and no decorative frame.
Keep face, garments, weapon dimensions and accessories identical in every view.
No written labels; leave empty slots for labels to be typeset later.
[GLOBAL NEGATIVE]
```

验收：人物身份 4 视图完全一致；武器和左右手无漂移；人工确认后把设定板作为所有后续生成任务的首要图像参考。

## 4. 人物立绘与头像：Portrait

建议输出透明 RGBA PNG/WebP（立绘母版建议长边 2048px 以上，非硬性运行时合同）；构图保留剑、衣摆和头发安全边距，背景可单独生成，**不要以纯色背景冒充 Alpha**。

```text
[GLOBAL STYLE DNA]
Full-body game character illustration, {asset_id}, use the attached approved
design sheet as immutable identity reference. {identity_lock}.
Natural balanced wuxia stance, expressive but controlled gesture, full weapon
visible, head and feet within canvas, consistent body proportions, refined
face and fabric details. Soft directional lighting from {light_direction},
matching {palette}. Isolated single character, transparent RGBA background,
clean hair/weapon edges, no ground plane, no shadow baked into alpha.
Allow 10% safety margin around the silhouette.
[GLOBAL NEGATIVE]
```

头像从同一批准立绘/设定图裁切或基于参考重绘；面部辨识、发冠和服装配色必须一致，避免单独再生成另一个“同名角色”。

## 5. 游戏内 2D 角色：Sprite / Animation Atlas

**资源接口已定，最终帧尺寸与方向仍待试点冻结**：`WuxiaActorAnimationProfile.tres` 支持自定义 atlas `columns/rows`、`feet_offset`、`actor_scale`、动作帧索引。历史 6×4 是可读的存量格式，不作为缺失配置的隐式回退。

制作建议（未批准）：先完成单个动作的逐帧分镜，再让 AI **每次输出一张包含连续多帧的 RGBA Sprite Sheet**，按分镜选择适当 C×R 等尺寸格和宽透明间距；程序机械拆格、逐格拒绝越界后，再按统一根点坐标系无损装配正式 Atlas。画布必须给完整人体/武器留白，不能把 4×2/6×4 的“关键姿势稿”伪称真实高帧率动画，也不能靠固定网格反推帧数。**一个 Atlas 可包含一个或多个动作**，只要每动作的有序绝对帧索引可追溯，所有格子等大、透明留白充分且零越界。方向目标为前/后/左右；当前水平镜像只能作为过渡。

**生图入口**：角色逐帧描述只作为分镜数据，不再单独使用单帧生图模板。实际调用下文 §5.1 的多帧 Sheet 简版提示词。

**完整美术生产清单为 12 组**：`idle` 待机、`walk` 行走、`run` 跑步、**四套按当前角色武器契约定义的攻击变体**、`skill` 技能、`evade` 闪避、`guard` 格挡、`hit` 受击、`defeat` 倒地。单剑角色可用 `attack_thrust/attack_overhead/attack_sweep/attack_heavy` 作为示例，其他武器应选择适合其形制、握法和打击方式的攻击。每组分别分镜与验收；合图由程序自动完成。

**当前原生动作合同**：`idle/walk/run/attack1/attack2/attack3/attack4/skill/evade/guard/hit/defeat` 共 12 组。每名角色按其武器／徒手设计四种不同攻击，单剑直刺、下劈、横斩、蓄力重击仅作分镜范例；正式 Clip 的 `action` 字段使用 `attack1-4`，不是这四个范例名称。连携是对已配置攻击的时序编排，不单独绘制固定 `combo`；旧 `move/attack/combo` 只在明确配置的存量 Profile 中可用，不能静默代替缺失动作。每组有自己的循环／复位合同，技能可绑定指定动作和有效帧 VFX Cue；逐帧时长与表现根位移需要写入原生 Clip 才会生效。

### 5.1 AI 默认生成：一张多帧动作 Sprite Sheet

按 [精灵动画生产与验收合同](../standards/SPRITE_ANIMATION_QA.md) 执行。**每次 AI 生图应输出一张包含多个连续动作姿势的透明 Sprite Sheet，不是每次只输出一个帧。** 先由 §5.2 的动作分镜决定有效帧数 N，再决定适合当前画布/动作幅度的列数 C、行数 R 和统一格子；不能为填满 2×4 或 6×4 网格反过来固定 N。单张容不下完整动作时，可拆成多个连续时间段，**每次仍输出包含多帧的 Sheet**。视频提帧尚未真实验收，脚点编辑器也不能自动识别动作帧语义或真实承重脚。

**统一坐标约定**：以批准的战斗待机帧作为所有动作的身份、`pose_local`、比例和朝向基准；逻辑 O 是待机骨盆地面投影（+x 右、+y 下），地线及镜头固定。一个 Sheet 内各格的 O 位于**相同格内相对坐标**，不能按每格不透明轮廓单独居中/缩放。保留分镜 `root_offset`，攻击/闪避等动作的局部姿态复位不代表世界位置回到起点；`defeat` 停留在倒地终止态，`idle/walk/run` 检查首尾循环。

**默认生成与验收顺序**：

1. 附角色获准设定和 `weapon_contract`（武器/徒手、数量、尺寸与握持方式），固定侧视基准与统一 O。不要从其他角色套用武器或镜头。
2. 从 §5.2 的分镜得到真实 N、连续全局帧号、阶段与各帧姿势。选择让人物/武器有足够空间的 `grid_columns=C`、`grid_rows=R`、共同格宽/高与透明留白；`C×R` 仅承载所选帧，不决定帧数。每次一个 `action_id` 的一组连续帧，按行优先从左到右、从上到下排列；不足格全透明。
3. 使用下方多帧母提示词一次生成整张 RGBA Sheet。要求各格同一角色/武器、固定 O/地线/比例，姿势随分镜连续变化，武器、头发、衣摆和四肢均不触格线；不要文字、边框、残影或跨格内容。
4. **先机械拆格再判定是否可用**：按已声明 C/R 等尺寸切片，检查整张尺寸可整除、实际非空格数量与预期帧数匹配、空格完全透明、每个非空格四边 Alpha 边距 m>0（24px 仅试点建议），任何人体/武器越格、裁切或轮廓混格一律拒绝。AI 不能保证精确网格，也不能可靠识别动作阶段；不合格时重新生成该动作或有问题的**连续多帧片段**，而不是靠猜帧、紧裁切或补黑边放行。
5. 几何通过后按行优先帧序预览连续性、循环/复位、承重与根位移；AI 视觉仅初筛明显异常。最后由程序按统一 O 对通过验收的格子无损打包为运行时 Atlas，并再次自动检查零重叠和索引；疑难与最终少量样片才人工复核。

**简版多帧 Sheet 母提示词**（仅传下面模板、角色基准图和选中分镜；完整检测合同不拼入生图请求）：

```text
Create ONE transparent hand-painted 2D wuxia SPRITE SHEET for {action_id};
include {sheet_frame_count} consecutive poses (global frames {first_frame_index}–{last_frame_index}), NOT one frame.
Character reference: {character_reference}. Equipment/unarmed: {weapon_contract}.
Ordered frame poses: {frame_pose_list}.
Layout: {grid_columns} × {grid_rows} equal cells, left-to-right then top-to-bottom; unused cells transparent.
Keep the same character, scale, strict side view, ground line and root O in every cell.
Follow natural motion, planted-foot changes and valid root movement; close loops or recover to idle (defeat stays down).
Each entire character, limb and weapon MUST fit inside its own cell with wide transparent margins.
NO touching, clipping, overlap or spill into other cells.
Transparent background; no borders, labels or extra equipment.
```

**注意**：图像模型可能画错格子、重复姿势或忽略精确像素尺寸；这些文本是**生成约束**，不是验收通过的证明。既有工具如无法可靠按预设网格切片和检测 Alpha 边距，必须保留 candidate，不得宣称已自动验收。

**动作描述检查示例**：

| 动作 | 提示词必须说明的力学变化 |
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

**提示词精简原则**：只传角色基准、武器契约、动作分镜、N、网格、统一 O、透明留白和零跨格；重复说明、机器可检查的像素阈值与验收清单留在规范，不逐条发给图像模型。失败重试仅增加针对性纠错描述。提示词中不要强制源图恰为 200px 人高或 24px 边距；这些是后续原生尺度归一和程序排布约束，AI 很难严格遵守像素数字。可以请求大留白与一致画布，但不能把生成模型承诺当成测量结果。

### 5.2 AI 动作分镜：先规划帧数，再逐帧绘图

**默认先运行下列简版分镜提示词（仅输出文本，不生图）**。`evade` 的 `{action_description}` 必须写明“向后闪避”，并附 `evade_style`（默认 `backstep`；可选 `slide`、`roll`、`leap`，均向后）；其他动作不用添加该参数。依据 [分镜合同 §2.1](../standards/SPRITE_ANIMATION_QA.md)，每种动作单独规划；分镜确定 `total_frames` 和逐帧姿势后，再按 §5.1 为每次多帧 Sheet 填入 `{frame_pose_list}`、`{sheet_frame_count}`、`{grid_columns}` 与 `{grid_rows}`。不要预设 8 帧、2×4 或 6×4 网格，也不要为填满格子添加静止重复帧。

```text
请为2D横版武侠角色设计动作分镜，只输出文本。
角色基准：{approved_character_reference}；武器/徒手契约：{weapon_contract}。
动作：{action_id}，{action_description}；时长：{known_duration_ms_or_unknown}。
固定侧视，统一待机根点 O：{canonical_idle_pose_and_ground_root}；
运动方式：{locomotion_or_root_motion_policy}。

先按起势、发力、有效动作、收势等实际变化确定关键姿势，再补必要间帧。
自主选择总帧数 N，不默认 8 帧，不为填满网格重复姿势。
逐帧按顺序列出：序号、时间、阶段、关键/间帧、全身姿势、真实支撑/重心、
武器或徒手轨迹、相对 O 的姿态与 root_offset、相邻帧变化。
检查身份与装备一致、发力连贯、位移不瞬移：
idle/walk/run 首尾循环；defeat 停在倒地；其他动作收尾兼容待机姿势。
发现跳帧则补帧并更新 N，最后输出分镜及 N。
```

**攻击动画组：每名角色基于 `weapon_contract` 设计四套独立攻击，连携不另画固定动作。** 下表只是沈长风等**单剑角色的动作示例**，不作为所有武器的强制招式；其他角色可保留四个攻击槽位并使用适合该武器的语义 ID 和运动方式。

| 制作 ID | 独立动作描述（填入 `{action_description}`） | 分镜重点 |
| --- | --- | --- |
| `attack_thrust`（攻击1：直刺） | 侧身戒备→屈膝后脚蓄力→后脚蹬地、前脚踏出→右手单剑沿前方连续直线突刺→前脚承重→自然收剑 | 突刺的前向根位移、剑尖直线轨迹、无无故后弹 |
| `attack_overhead`（攻击2：下劈） | 侧身戒备→重心调整、右手单剑上举→身体略上提蓄力→沉肩屈膝使剑自上向前下方劈落→缓冲并归位 | 上下重心变化、剑尖纵向弧线、不得只甩手臂 |
| `attack_sweep`（攻击3：横斩） | 侧身戒备→向侧后方收剑、腰胯预旋→支撑脚发力、骨盆带动躯干转动→右手单剑水平横斩→惯性跟随并收势 | 横向剑路连续、腰胯带动、保持侧视不可突变正面 |
| `attack_heavy`（攻击4：蓄力重击） | 屈膝沉重心、右手单剑后上方大幅蓄力→短暂蓄势→后脚强力蹬地、骨盆肩臂依次爆发→重击终点→自然惯性和踏步恢复 | 蓄力与爆发节奏对比、较大根位移、**仍是一柄右手单剑** |

- 每名角色依据自己的武器/空手设定分别规划四种攻击的 `total_frames`、阶段时间、握持与结束站姿；**禁止让 AI 在源图中混画多动作姿势**，程序按各自的动作帧索引无损装配。`combo` 仅记录诸如“直刺→横斩→重击”的**编排顺序和动作衔接需求**；先验证每套攻击可独立播放，之后再验证相邻攻击收势/起手的连接。
- **补全其余动作**：`idle` 呼吸戒备循环、`walk` 蹬地换脚循环、`run` 快速跨步循环、`skill` 专属招式与复位、`evade` 蹬地落脚与合理位移、`guard` 架剑承压与撤架、`hit` 受力缓冲与恢复、`defeat` 倒地接触直至静止。每种均按 §2.2 的独立阶段和首尾合同生成，不能把 walk/run 混成 move 的一套动作，也不能让 defeat 自动站起。
- **图集布局选择**：一张 Sheet 可包含多个动作，按程序实际格子从左到右、从上到下编号；必须输出 `action_id -> ordered absolute frame_indices` 映射、各自帧数、循环/复位标志、统一 O 锚点，严禁在相邻格中延伸武器/身体。图集容量不得反过来限制动作帧数。
- **运行时边界**：`attack_thrust/attack_overhead/attack_sweep/attack_heavy` 等是示例分镜标签，正式 `clip.action` 统一写 `attack1-4`；Skill 或武学 Resource 仅绑定一个已存在的动作 ID，VFX 通过 Cue 或事件绑定。没有实际 Godot 播放与时序验证的素材仍只算未验收候选，不宣称完整接入。
- **审查分工**：机器核查分镜帧号/数量/时间/字段完整、PNG Alpha、格子边距和零重叠；AI 视觉只初筛身份、与角色武器契约不符的武器增减/握持、侧视及明显姿态跳变；真实支撑脚识别与动作合理性不能自动保证，疑难帧与最终少量样片再人工复核。分镜 `time_ms` 仅是离线节奏建议；必须映射到 `WuxiaActorAnimationClip.frame_durations` 才会影响 Godot 逐帧停留时间。

## 6. 场景设定与可运行地图贴图

**城镇、街区、大地图补充**：横向主街、竖向街巷与十字街口使用同一尺度。生成前先阅读 [城镇与大地图统一比例尺规范](../standards/TOWN_MAP_SCALE_PRODUCTION.md)，使用 `art-production/tools/scene_scale_guide.py` 生成的透明标尺图作为参考。普通角色始终 200 世界像素高，街区以 1600×1000 单屏为单位生成；场景各层同坐标、同画布、无运行时二次拉伸。城市通过街区连接表现，不靠一张超大画布缩小角色。纵向单屏仍是 1600×1000 的横屏画布；连续南北长街可以使用 1600×2400 等完整世界画布，并由固定 1600×1000 游戏视口跟随人物滚动，不旋转背景、不把角色向远处缩小。通过 `--orientation vertical`（南北）、`--orientation mixed`（十字街口）输出对应的参考层。

**重要：此比例尺是构图和后期校准合同，不是仅凭 AI 提示词就能保证的像素精度。**

技术合同：**1600×1000 / 16:10** 逻辑画面，另验 1440×900。正式交付同尺寸、同原点的 `background`、`ground`、`foreground`、可选 `weather`，用 `WuxiaSceneArtProfile` 引用；碰撞、出生点、可走地面仍来自 Map Resource。**生成一张漂亮的整图不等于完成可玩地图。**

### 场景设定图

```text
[GLOBAL STYLE DNA]
Wuxia environment concept for {location}, {season_time_weather}.
Fixed {camera} composition, 16:10 game frame, blue-gray/jade natural colors
and small warm practical light sources. Natural depth through foreground,
walkable midground, distant background. Architecture and terrain:
{landmarks}. Keep the playable center {playable_polygon_description}
visually clear for six combatants; place high-detail clutter outside
navigation lanes. Match the approved character scale and foot contact plane.
No characters, no UI, no text, no chess grid, no fake 3D terrain.
[GLOBAL NEGATIVE]
```

### 分层输出（逐层使用同一构图参考）

```text
Use the ATTACHED APPROVED environment master as strict layout reference.
Produce ONLY the {layer_name} layer for {location}, canvas 1600x1000.
Preserve every landmark's screen coordinates; do not shift camera or perspective.
Layer requirements: {layer_description}. All excluded regions fully transparent
RGBA, no opaque placeholder color, no extra objects, no text or UI.
```

- background：远山、天空、远岸，不承载角色地面。
- ground：可走道路/桥面/地面纹理，保留清晰接触面。
- foreground：近景竹枝、栏杆、屋檐等可遮挡对象，真实透明。
- weather：雨线、雾层等可关闭的独立效果，不把雨永久画死在人物前面。

### 竖向街道与十字街口补充提示词

使用 `--orientation vertical` 的透明比例尺引导层控制南北街，使用 `--orientation mixed` 控制十字街口。两种场景都使用横向 1600×1000 **游戏视口**，可以制作 1600×2400 等真实完整世界画布，并须在不同 Y 位置验证人物始终为 200px 高；分层贴图、原生场景 `world_size` / `viewport_size` 必须与世界画布完全一致。

```text
原创中国武侠城镇，固定横屏 1600x1000、2.5D 轻俯视地面，
主要街道从画面上方 north 沿 Y 轴贯通至下方 south，
可行走的南北廊道宽 240–400 世界像素（3–5 战斗单位）。
保留清晰的北/南出入口，左右用中式屋宇、门头、铺面、遮挡物
呈现紧凑街区与清晰交互点，允许东西向支巷，但不堵住主街。
人物在南端和北端都保持 200 世界像素高，地面占位半径 24px，
不得使用消失点透视让远处人物缩小；1 战斗单位=80 世界像素。
统一参考所附透明 vertical 比例尺图，严格同一画布原点、
建筑/门洞与角色脚点、贴图图层和地面行走区域匹配。
无人物假人、比例尺格线、UI、地图文字，非旋转后的横向贴图。
```

十字街口改用 `mixed`，令上/下/左/右道路在中心真实连通，并分别设立 north/south/east/west 出口标记。`WuxiaMapDefinition.primary_axis` 标明画面主轴，`zone_exit` 标记目标街区与入口 ID；这两项是 Godot 制作数据，不意味着现已实现跨区自动加载。

## 7. 装备与物品图标

建议候选规格：母版 **512×512 RGBA**，导出 128×128、64×64 等尺寸做可读性验收；尺寸不是当前已冻结的引擎强制值。以**单一斜侧视角、统一光源、统一材质笔触与留白**为准，物品辨识度高于背景装饰。

```text
[GLOBAL STYLE DNA]
Single collectible RPG {item_category} icon: {item_name}.
Design and material: {item_description}. Wuxia-era believable craftsmanship,
three-quarter object view, consistent top-left soft light, same painterly
brushwork as approved character art. Centered object with 12% clear margin,
readable at 64x64, one object only, transparent RGBA, no border, no background,
no text, no number, no rarity halo baked in. Palette: {palette}.
[GLOBAL NEGATIVE]
```

稀有度边框、数量、装备槽标识全部由 UI 分层绘制，避免同一图标为不同稀有度重新生成。

## 8. 武学卡面素材

将 **卡牌框架**、**武学插画**、**规则文字**分离。已有卡面保持兼容；本模板主要用于后续新增武学。母版建议竖幅 **768×1024** 作为候选，最终按现有 UI 组件的实际裁切尺寸验收。

```text
[GLOBAL STYLE DNA]
Vertical martial arts card illustration ONLY, technique: {technique_name},
school: {school_identity}, actor identity reference: {identity_lock}.
One clear frozen action at its decisive moment: {action_pose}.
Distinct weapon motion, controlled ink-brush energy accents: {vfx_palette}.
Dramatic directional composition, strong foreground silhouette, quiet lower
and upper safe areas for later card UI cropping. Painterly Chinese wuxia,
consistent with approved character and environment sheets.
No text, no number, no card border, no rarity icon, no logo.
[GLOBAL NEGATIVE]
```

一张武学卡不同 Usage 使用同一主体卡画；派生招式可使用局部特效叠层，除非确有独立动画与身份需求。

## 9. 游戏 UI：HUD / CTB / 按钮 / 装饰

UI 使用统一的“宣纸、漆木、青铜、少量温金”材质体系，**低装饰密度、信息优先**。目标：战斗区不被 UI 压缩；右侧 CTB 跑轴保留头像动态运动，底部扇形手牌有明确可点区域，敌方状态与 CLASH 响应可读。

```text
[GLOBAL STYLE DNA]
Create a reusable 2D game UI ASSET ONLY: {component_name}.
Materials: dark lacquered wood, muted ink-blue textile, aged bronze edge,
subtle parchment fill; restrained linework with minimal Chinese ornamental
motifs. Functional shape: {interaction_area}, padding: {safe_margin},
states to provide separately: idle, hover, pressed, disabled, selected.
Flat front-facing orthographic layout, clean corners and scalable borders.
Transparent RGBA, no labels, no numbers, no sample cards, no full screenshot,
no character painting, no dense patterns. Match {palette}.
[GLOBAL NEGATIVE]
```

推荐分件：卡槽底板、卡框、角色头像框、CTB 轴底纹、轴上标记、状态徽记、按钮底板、面板九宫格切片。文本、图标、进度条和跑轴头像由 Godot 控件绘制；不要让 AI 将文字直接烧进背景。

## 10. 战斗 VFX：剑气 / 格挡 / 命中 / 闪避 / 连携

建议先做透明逐帧序列、再组图集或动画 Resource；原生 `AssetRegistry.texture_for_event()` 可继续复用。特效不影响 `BattleModel` 结算。不要在本轮把精确帧数/分辨率宣称为已锁定；按实际镜头比例验证。

```text
[GLOBAL STYLE DNA]
Isolated 2D wuxia combat effect animation keyframe: {effect_type},
phase {phase}, energy shape {trajectory}, palette {effect_palette}.
Elegant ink-brush edge with a controlled luminous core, clear direction
of force, strong first impact and rapidly dissipating trailing particles.
Designed to overlay a small 2D game character without hiding target or feet.
Transparent RGBA, no character, no weapon model, no environment, no black
background, no UI, no text. Maintain stable framing for neighboring frames.
[GLOBAL NEGATIVE]
```

需分别验收 Slash（清晰方向）、Guard（短促金属碰撞）、Impact（不遮血条）、Evade（残影速度）、Combo（与普通斩击区分）。

## 11. 不可只靠生成模型保证的技术门槛

| 项目 | 自动检查 | 人工审查 |
| --- | --- | --- |
| 文件与引用 | 路径、存在、解码、Atlas 能整除、`.tres` 加载 | 命名、角色对应 |
| Alpha | 是否有透明通道、可见边缘像素范围 | 发丝、剑尖、残影色边 |
| 角色动画 | 索引合法、帧区域尺寸、动作集合齐备 | 脚点不漂、姿势不跳、无肢体漂移 |
| 场景 | 1600×1000、层尺寸一致、Profile 有效 | 可行走面、遮挡、视角与路径一致 |
| UI/图标 | 尺寸、边距、纹理引用 | 64px 可读、对比度、操作焦点 |
| VFX | 帧尺寸与事件绑定 | 特效时机、方向、遮挡、重复战斗性能 |
| 权属 | source / rights 字段齐备 | 商用授权、与既有作品近似性 |

验收必须包含 Godot Editor 中实际播放，以及 1600×1000 和 1440×900 的 GUI 截图。必须保留候选图和原始制作提示，不以一次成功生图宣称“可量产”。

## 12. 命名与可复制的工作单

建议文件规则：`{asset_type}_{asset_id}_{view_or_action}_{variant}_vNN.png`；同一资产的母版、图层、导出、Resource 分开管理。正式运行资源只通过 Godot 原生 `.tres` 和 Content Manifest 关联，不把本模板或提示词作为运行时 JSON 加载入口。

每次生产复制此工作单：

```yaml
asset_id: shen_changfeng
asset_type: sprite
status: concept
source_reference: [approved_design_sheet_path, approved_palette_path]
identity_lock: "..."
camera_and_light: "..."
target_canvas: "256x256 candidate; final pending pilot"
alpha_required: true
action_or_layer: attack
direction: right
prompt_version: art_prompt_v1
model_and_version: "..."
seed_if_supported: "..."
source_and_rights: "..."
review:
  identity: pending
  alpha_edges: pending
  anchor_and_timing: pending
  godot_import: pending
  gui_capture: pending
  owner_approval: pending
```

工作单是**离线制作记录示例**，不能作为第二套运行时 JSON/YAML 内容数据。正式发布的角色、武学、地图、物品仍使用 `.tres`。

## 13. 第一轮冻结试点（P0）

1. 批准沈长风设定板与冷暖色板，确定敌方追兵首领的独立身份。
2. 用同一设定生成两人立绘、12 组动作关键帧与实际可播放中间帧，锁定脚点、方向和帧尺寸。
3. 从雨夜断桥完整概念图制作 1600×1000 四层场景，校验地图几何与角色站位。
4. 做一套剑气/格挡/命中 VFX、3–5 个物品图标、一张武学插画、一套 CTB/卡槽/状态框，全部应用共同色板。
5. 实机并排审查角色、场景、卡牌、图标与 UI 的一致性；人工批准后再冻结 V2 参数及开始批量生产。

**完成定义**：不是提示词“写好”，而是多类别素材基于同一 identity/style reference 稳定复现、透明/脚点/分层通过、Godot 实机一致并批准。

## 2026-11-02 战斗角色贴图比例尺补充

所有新战斗角色的生成提示词统一添加：

> 固定游戏世界比例尺，普通人物站立姿态在游戏内对应 **2.5 战斗单位（200 世界像素）**，角色地面占位半径 **0.3 单位（24 世界像素）**；1 战斗单位 = 80 世界像素。独立透明动作帧，统一角色头身比、脚底基线、完整轮廓、侧身朝向，图集内每格四周保留至少 8 源像素透明边距，不出现跨格的武器／衣摆／脚趾。尽量简化纹理，保留剪影、发型、武器和主配色。角色站立、行走与攻击不随帧切换改变世界尺度。

生成时 **不要**要求所有输出固定 256×256；该尺寸是旧图集兼容范例，正式列行与格尺寸由每个原生 `WuxiaActorAnimationProfile` 确定。AI 提示词控制风格，不保证数值精确；必须通过图集工具、脚点预览和原生 Resource 校验后使用。
