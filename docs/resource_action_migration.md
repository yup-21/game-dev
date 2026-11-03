# Native Resource 动作合同迁移（PR #117）

## 原则

此次只迁移 Godot 原生 `.tres` 资源，战斗结算、伤害、体积与角色逻辑坐标均保持不变。正式贴图未包含完整十二动作时，**不创建虚假的新动作图集或姿势**。

## 六份正式角色动画 Profile

`data/native/animations/` 下沈长风、顾清霜、绿衣游侠、黑刃客、夜袭刺客、追兵首领六份 Profile 新增 `action_fallbacks`，将现代动作 `walk/run/attack1/attack2/attack3/attack4` **显式**映射到已有 `move/attack` 资源。引擎查找优先选择同名真实 Clip；不存在时仅检查该角色配置的单级映射，映射目标必须是直接存在的 Clip。不存在的映射、无效 ID 或无目标的动作会报错，不再使用任何硬编码别名或自动回退至待机。

原先的九个 Clip、图集引用、统一比例、脚点、帧列表都保留。既有 `attack`、`defeat` Clip 填写原有等节奏的 `frame_durations`，只是让资源拥有可编辑的逐帧节奏入口，不会凭空改变动作；无测量数据时 `root_offsets` 保持空数组。未来导入一套正式 `attack2` 时，在 `clips` 增加同名 Clip 即可覆盖该动作的回退，不改技能绑定。

仍使用无动作 Profile 的剧情 NPC／试验角色按旧行为运行，**不向这些角色伪造战斗动作**。已有六份正式 Profile 通过独立的十二动作可解析性验证。

## 武学与技能 Resource

| 类型 | 已迁移 | 行为 |
| --- | ---: | --- |
| `r36_school_forms` | 41 个用法 | 先保留 8 个主角专用已授权特效槽，剩余 33 个用法添加动作与 cue |
| `r37_tingfeng_cards` | 12 个用法 | 保持主角既有动作与特效选择 |
| `data/native/skills` | 5 个用法 | 原有 2 个 + 烟岚剑 3 个均设动作和 cue |
| `data/native/techniques` | 6 个可用节点 | 原有变锋 3 个 + 护势 1 个 + 烟岚 2 个 |
 
> 变锋 `sealed` 是不可执行的阶段状态，保持无动作；避免把状态节点误当成主动技能。

普攻根据 `attack_profile.route` 选 `attack1`（刺击）、`attack3`（横扫）或 `attack4`（重击）；移动/闪避用 `evade`；守势用 `guard`；其余状态和运气动作用 `skill`。所有绑定都只有一个动作，不复合播放。具体时间点由 `ActionTimeline` 的语义 cue 决定，未改规则生效时机。

**特效槽并未假装全部已有素材。** 沈长风的 5 种原创剑术 VFX 沿用 PR #117 的 `shen_*` 槽，烟岚的状态类动作使用当前 `r24_status_vfx`。没有合适素材的其余用法保持空 `vfx_slot` 并保留现有程序化攻击特效或旧事件反馈；后续添加 Asset Resource 即可补槽，无需更改动画接口。

## 验证

`checks/test_resource_action_migration.gd` 遍历六份实际 Profile、53 个原生武学用法、5 个 SkillUsage 和 6 个可执行 TechniqueNode：确认现代动作通过直接 Clip 或显式单级映射解析、未配置的动作不能播放、逐帧节奏数组合法、已声明 VFX 槽可加载、cue 名与动作语义一致。接入 `.github/workflows/wuxia-modular-content.yml`。旧九动作测试和主角特效回归保留。

此迁移不构成新的正式十二组美术资产制作或人工视觉验收。
