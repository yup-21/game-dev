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
character views at matching scale, one weapon close-up, one fabric detail,
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

**资源接口已定，最终帧尺寸与方向仍待试点冻结**：`WuxiaActorAnimationProfile.tres` 支持自定义 atlas `columns/rows`、`feet_offset`、`actor_scale`、动作帧索引。历史 6×4 是 fallback，不是新制作的强制标准。

制作建议（未批准）：先生成单角色逐帧 RGBA，再由工具裁切组装 Atlas；画布可按完整人物动作所需尺寸选择，人物与武器不可触边；完整动作应有不同中间帧，不把 4×2/6×4 的“关键姿势稿”伪称逐帧动画。方向目标为前/后/左右；当前水平镜像只能作为过渡。

```text
[GLOBAL STYLE DNA]
2D game sprite animation frame for {asset_id}, reference the SAME approved
character sheet and portrait. Exact same face, hair, costume, weapon, palette,
body-to-head ratio and shoes. Action: {action}; phase: {startup_active_recovery};
frame number: {frame_index} of {frame_count}; view direction: {direction}.
Fixed strictly side-on orthographic camera for horizontal combat, full
character and entire weapon visible with blank margins. Use a plausible
planted support foot for this motion phase, same ground and character scale;
do not add a drawn anchor marker or pin both feet during movement. Keep
root translation separate from local pose; do not erase a legitimate lunge. Crisp readable silhouette at small in-game
display size, simplified micro-detail without changing identity,
transparent RGBA, no floor shadow, no background or UI.
Keep the torso and weapon trajectory continuous with the adjacent supplied frames.
[GLOBAL NEGATIVE]
```

**当前运行时动作合同**：`idle`, `move`, `attack`, `guard`, `hit`, `evade`, `skill`, `combo`, `defeat`（仍须完整九动作）。**新美术生产合同**：将普通攻击与固定连携的制作需求合并为可扩展的攻击动画组，首批四套为直刺、下劈、横斩、蓄力重击；连携是对这些攻击的排序与衔接，不另生成固定 `combo` 图集。当前 Godot 尚未实现四变体选择；新 ID 只能作为离线候选，不可擅自改 `.tres` 枚举或把 `combo` 槽当作第二攻击。循环动作要首尾衔接；非循环动作要有起手/发力/收势。实际播放时长仍由 `BattleActionTimeline` 控制。

### 5.1 AI 优先生成：单帧、身份锁定、动作语义

按 [精灵动画生产与验收合同](../standards/SPRITE_ANIMATION_QA.md) 执行。**默认一次生成一个完整角色动作帧，不让 AI 直接绘制多格大图集**。不同帧的格子尺寸、排列与透明间距由后续程序计算，从源头避免角色/武器越格或互相重叠。视频转帧尚未完成真实验收，仅在用户要求试验时作为 candidate 路线；脚点编辑器不能识别真实支撑脚或动作阶段。

**生成顺序（尽量自动，无须每帧手工标点）**：

1. 上传同一批准设定/立绘，让 AI 先生成一张固定 90° 侧视、全身、一柄正确武器的战斗基准帧；基准图需有充足四边空白。
2. 逐动作描述起手→承重/蓄力→有效→收势，以相邻已生成帧和基准图作为参考，逐张生成关键姿势，再生成真实过渡帧。不按固定 6/8 帧生成，也不要求 AI 同时画多动作。
3. 先自动检查格式/Alpha/原始图像边界，并以视觉模型初筛双剑、正面、变形及明显姿势跳变；视觉模型不是可靠的真实支撑脚检测器。失败帧优先重新生成，仅异常和最终样片要求人工复核。
4. 将独立 RGBA 帧交给确定性打包程序，以非透明轮廓自动确定统一格子，逐格断言四边透明边距 m>0（24px 试点推荐）、没有任何帧侵占邻格、空格透明。**零重叠是硬门槛**，不通过就增大格子重排或重新生成源帧。

**可复制的单帧生成母提示词**（每帧填入本帧的真实姿势描述，不将方括号说明绘制进图片）：

```text
Use the attached approved character design and accepted side-view base frame
as strict identity and scale references. Generate ONE complete isolated
original hand-painted 2D wuxia combat character frame, not a sprite sheet.
Fixed 90-degree side view facing {direction}; stationary camera, unchanged
ground line, head-to-body ratio, outfit, colors, weapon and holding hand.
Exactly {weapon_count} complete weapon(s) in {weapon_hand}; the free hand
remains empty. Action: {action}, phase: {phase}. Precise pose: {pose_description}.
Weight and planted foot: {support_description}. Sword path: {weapon_trajectory}.
Motion relative to previous accepted frame: {adjacent_frame_delta}.
Preserve correct anatomy, complete head/hair/sleeves/boots/weapon tip and
generous empty margins on EVERY side. Readable simplified painterly silhouette.
One character only. No second pose, no panels, no frame borders, no overlap,
no camera movement, no perspective change, no fake extra limbs or swords,
no motion blur, no VFX, no background or text. Transparent RGBA if supported.
```

**动作描述检查示例**：

| 动作 | 提示词必须说明的力学变化 |
| --- | --- |
| idle | 后脚承重，躯干轻微呼吸，支撑鞋底稳定，首尾近似闭环 |
| move | 左右脚交替承重和离地，步幅、重心、腿摆对应，不做单脚滑行 |
| attack variants | 按 §5.2 的直刺/下劈/横斩/蓄力重击分别分镜，明确承重、剑路、根位移及可衔接的收势；不混画成一组无序姿势 |
| guard | 屈膝架剑→承重缓冲→短暂稳定→归位，持剑手和支撑脚不乱跳 |

提示词中不要强制源图恰为 200px 人高或 24px 边距；这些是后续原生尺度归一和程序排布约束，AI 很难严格遵守像素数字。可以请求大留白与一致画布，但不能把生成模型承诺当成测量结果。

### 5.2 AI 动作分镜：先规划帧数，再逐帧绘图

**默认先运行下列分镜提示词（仅输出文本，不生图）**。依据 [分镜合同 §2.1](../standards/SPRITE_ANIMATION_QA.md)，每种动作单独规划；分镜确定 `total_frames` 后才填入 §5.1 的 `{frame_index}`/`{frame_count}` 单帧绘图提示词。不要预设 8 帧、2×4 或 6×4 网格，也不要为填满格子添加静止重复帧。

```text
你是2D横版动作游戏动画导演和武术动作设计师。仅设计分镜，不要绘制图片。

角色设定与固定侧视参考：{approved_character_reference}
身份、服装、体型、配色：{identity_lock}
武器数量、形状与持手：{weapon_count_shape_hand}
动作 ID：{action_id}
动作意图和发力方式：{action_description}
已知动作时长：{known_duration_ms_or_unknown}
镜头：严格90度侧视，角色朝{direction}，镜头和人物比例不变。
游戏风格：简洁易读的2D手绘武侠动作，头发衣摆保留真实惯性。

第一步：分析起势、蓄力/承重、发力、有效姿势、惯性、收势和恢复。
不要求所有动作必须有七阶段；依据实际动作选择合适阶段。
说明支撑脚如何换承重，身体重心如何变化，武器和剑尖如何运动，
角色是否有整体根位移，动作是否循环及如何与下一动作衔接。

第二步：先给少量关键姿势，再分析高速变化、剑路弯曲、落脚、
转身和重心切换是否需要真实间帧；只在必要处补帧。
自主选择合理总帧数，不默认 6 或 8，也不按图集网格倒推；
不能复制无变化的静态姿势凑数；说明为什么选择此帧数。

第三步：输出：
A. action_id、动作目的、是否循环、建议时长、阶段与每阶段帧数、
   total_frames 和帧数依据、根位移总体方向、首末衔接关系。
B. 逐帧分镜表（每个实际帧必须独占一行）：
   frame_index（从0连续递增）、time_ms（0起单调递增）、
   phase、role（key/inbetween）、pose（头/躯干/骨盆/双臂/双腿）、
   support_contact（真正承重脚/腾空/倒地接触部位）、
   center_of_mass、weapon_trajectory（持手/剑尖/轨迹）、
   root_offset（相对首帧位置）、transition（相对上帧的真实变化）。
C. 动作连续性审查：检查相邻帧的人体、脚步接触、武器数量及握持手、
   速度、根位移和收势；必要时修改分镜及 total_frames 后重新输出。
不要谎称图片已生成或脚点已被自动检测。
```

**首批攻击动画组：一套攻击一个独立分镜，连携不另画固定动作。**

| 制作 ID | 独立动作描述（填入 `{action_description}`） | 分镜重点 |
| --- | --- | --- |
| `attack_thrust`（攻击1：直刺） | 侧身戒备→屈膝后脚蓄力→后脚蹬地、前脚踏出→右手单剑沿前方连续直线突刺→前脚承重→自然收剑 | 突刺的前向根位移、剑尖直线轨迹、无无故后弹 |
| `attack_overhead`（攻击2：下劈） | 侧身戒备→重心调整、右手单剑上举→身体略上提蓄力→沉肩屈膝使剑自上向前下方劈落→缓冲并归位 | 上下重心变化、剑尖纵向弧线、不得只甩手臂 |
| `attack_sweep`（攻击3：横斩） | 侧身戒备→向侧后方收剑、腰胯预旋→支撑脚发力、骨盆带动躯干转动→右手单剑水平横斩→惯性跟随并收势 | 横向剑路连续、腰胯带动、保持侧视不可突变正面 |
| `attack_heavy`（攻击4：蓄力重击） | 屈膝沉重心、右手单剑后上方大幅蓄力→短暂蓄势→后脚强力蹬地、骨盆肩臂依次爆发→重击终点→自然惯性和踏步恢复 | 蓄力与爆发节奏对比、较大根位移、**仍是一柄右手单剑** |

- 每种攻击分别规划自己的 `total_frames`、阶段时间和结束站姿；不能把四种攻击画在同一张大图或让单独动作变成混合姿势。`combo` 仅记录诸如“直刺→横斩→重击”的**编排顺序和动作衔接需求**；先验证每套攻击可独立播放，之后再验证相邻攻击收势/起手的连接。
- **运行时边界**：制作 ID 不是现有 Godot `WuxiaActorAnimationClip.action` 可用的取值。运行时仍要求旧九动作、`combo` 槽依然存在；引擎没有攻击变体索引或连携重排机制前，四套分镜/图像保留 candidate，不把候选冒称已接入。
- **审查分工**：机器核查分镜帧号/数量/时间/字段完整、PNG Alpha、格子边距和零重叠；AI 视觉只初筛身份、单剑、侧视及明显姿态跳变；真实支撑脚识别与动作合理性不能自动保证，疑难帧与最终少量样片再人工复核。分镜 `time_ms` 是离线节奏建议，不会自动转换成 Godot 非循环逐帧停留时间。

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
2. 用同一设定生成两人立绘、九动作关键帧与实际可播放中间帧，锁定脚点、方向和帧尺寸。
3. 从雨夜断桥完整概念图制作 1600×1000 四层场景，校验地图几何与角色站位。
4. 做一套剑气/格挡/命中 VFX、3–5 个物品图标、一张武学插画、一套 CTB/卡槽/状态框，全部应用共同色板。
5. 实机并排审查角色、场景、卡牌、图标与 UI 的一致性；人工批准后再冻结 V2 参数及开始批量生产。

**完成定义**：不是提示词“写好”，而是多类别素材基于同一 identity/style reference 稳定复现、透明/脚点/分层通过、Godot 实机一致并批准。

## 2026-11-02 战斗角色贴图比例尺补充

所有新战斗角色的生成提示词统一添加：

> 固定游戏世界比例尺，普通人物站立姿态在游戏内对应 **2.5 战斗单位（200 世界像素）**，角色地面占位半径 **0.3 单位（24 世界像素）**；1 战斗单位 = 80 世界像素。独立透明动作帧，统一角色头身比、脚底基线、完整轮廓、侧身朝向，图集内每格四周保留至少 8 源像素透明边距，不出现跨格的武器／衣摆／脚趾。尽量简化纹理，保留剪影、发型、武器和主配色。角色站立、行走与攻击不随帧切换改变世界尺度。

生成时 **不要**要求所有输出固定 256×256；该尺寸是旧图集兼容范例，正式列行与格尺寸由每个原生 `WuxiaActorAnimationProfile` 确定。AI 提示词控制风格，不保证数值精确；必须通过图集工具、脚点预览和原生 Resource 校验后使用。
