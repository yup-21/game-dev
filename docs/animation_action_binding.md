# 角色逐帧动画与技能表现绑定

本说明面向 Godot 原生动画内容制作，遵循 [Godot 原生内容开发规范 V2](GODOT_NATIVE_AUTHORING_STANDARD.md)。战斗规则由 `BattleModel / CombatResolver` 决定；动画、局部根位移和 VFX 均不写入规则位置、判定盒、伤害或无敌窗口。

## 动作资源合同

新角色优先将动作库放入 `WuxiaActorAnimationProfile.native_frames` 引用的 `SpriteFrames.tres`，帧序、FPS、逐帧时长及循环只在 SpriteFrames 编辑；Profile 保存脚点、缩放和朝向。**仅当 `native_frames` 为空时**，旧 `WuxiaActorAnimationProfile.clips` 才是图集的帧序来源。新角色使用下面十二个动作 ID：

| ID | 含义 | 行为 |
| --- | --- | --- |
| `idle` | 待机 | 循环 |
| `walk` | 行走 | 循环 |
| `run` | 跑步 | 循环 |
| `attack1` | 该角色武器的第一攻击变体 | 单次 |
| `attack2` | 该角色武器的第二攻击变体 | 单次 |
| `attack3` | 该角色武器的第三攻击变体 | 单次 |
| `attack4` | 该角色武器的第四攻击变体 | 单次 |
| `skill` | 专属技能姿态 | 单次 |
| `evade` | 向后闪避 | 单次 |
| `guard` | 格挡 | 单次 |
| `hit` | 受击 | 单次 |
| `defeat` | 倒地 | 单次、终帧保持 |

动作名称不受固定枚举限制，可添加 `attack5`、`attack6` 或其他小写合法标识符；新增角色的**美术生产验收**仍需要上述十二项。逐动作 GIF 可先导入当前阶段用到的动作（至少 `idle`），缺失的动作不可伪称已完成。旧版九动作 `idle/move/attack/guard/hit/evade/skill/combo/defeat` 仍受支持；旧 Atlas 的 `walk/run` → `move`、`attack1–4` → `attack` **仅在 `action_fallbacks` 显式配置并有效时**兼容，不存在自动回退；`native_frames` 路径不使用旧 Clip 的隐式映射。旧资源不会被批量改写。

六位已迁移角色的 `data/native/sprite_frames/<id>.tres` 可直接在 Godot 编辑；Native GIF Dock 新导入的资源位于 `data/native/animations/<id>_frames.tres`。两种路径都由 `native_frames` 显式引用，不能为了统一目录重复生成或覆盖已经微调的动画。逐动作 GIF 细则见 [Native GIF 导入指南](../demos/changfeng-battle/docs/NATIVE_ANIMATION_IMPORT.md)。

未提供 `native_frames` 的历史 Atlas 使用以下 `WuxiaActorAnimationClip` 字段（**不适用于已使用 SpriteFrames 的角色**）：

- `action`：唯一动作 ID。
- `atlas`：可选独立透明图集。留空时使用 Profile 的共享 `atlas`。
- `columns/rows`：独立图集的等格布局；空图集时沿用 Profile 布局。
- `frames`：从零开始的绝对帧号，最多 256 帧。
- `loop_fps` 与 `loop`：循环播放的默认帧速。
- `frame_durations`：可选，与帧数等长的正数秒数组。循环动作按原始时间循环；非循环动作按这些时长的相对比例铺满语义时间轴。
- `root_offsets`：可选，与帧数等长的视觉相对坐标。通过 Sprite2D 局部 `position` 播放；非倒地、非循环动作终帧必须复位到零。

同一 Profile 下每个动作的 **单格像素尺寸必须一致**，以保证不同图集切换时角色比例不跳动；允许每组图集具有不同的总宽高、行数和列数。全体动作仍需脚底地线、落脚点、角色形体和武器数量一致。

历史 Atlas 模板：`res://data/templates/actor_animation_profile_12_actions.tres`。模板为 **接口验证占位图**，复用旧 SVG 帧，不是十二套正式美术，也未覆盖任何正在使用的素材。新动画应在 Godot SpriteFrames 面板预览并保存真实帧序。

## 技能与招式绑定

`WuxiaSkillUsageDefinition`、`WuxiaTechniqueNodeDefinition` 和兼容规则目录的 `WuxiaRuleUsageDefinition` 都增加三个可选字段：

| 字段 | 示例 | 含义 |
| --- | --- | --- |
| `animation_action` | `attack3` | 本次释放仅选择 **一组** 动作 |
| `vfx_slot` | `sword_wave` | 指向导入 Asset 的 VFX ID；也可使用其 `event_kind` |
| `vfx_trigger` | `strike_active` | 指定该语义时间轴上的 cue 名称 |

同一动作可被不同技能复用，并各自设置不同 VFX 槽。未配置动作的普通攻击选择 `attack1`，非攻击技能未配置动作时不额外播放专用技能姿态。效果贴图仍由既有 Asset Manifest 管理，不能通过动画引用绕过素材审核。

触发 cue 默认跟随语义事件：

| 语义时间轴 | 默认特效 cue |
| --- | --- |
| `attack` | `strike_active` |
| `combo` | `combo_visual_active` |
| `skill` | `skill_visual_active` |
| `guard` | `guard_active` |
| `evade` | `evade_visual_start` |

技能动画 ID 与语义时间轴分离。例如释放 `attack4` 仍然由 `attack` 语义窗口同步有效帧，不得修改真实命中时刻。VFX 在选定动画播放到对应 cue 时生成；其它伤害、护体反馈仍按已有战斗事件表现。

`MOVE/MOVE_FREE` 根据路线距离选择 `walk` 或 `run`（当前阈值为约 180 世界像素），不修改世界移动速度。当前角色贴图仍使用水平翻转；四方向独立图集尚需后续素材制作和方向资源协议。

## 回归

`checks/test_actor_animation_actions.gd` 覆盖十二动作、独立图集、逐帧时长、扩展动作、技能与武学绑定、同动作不同特效槽、有效帧延迟触发、走跑选择、倒地终帧以及九动作兼容。原有 `test_actor_animation_profile.gd` 等回归继续保留。
