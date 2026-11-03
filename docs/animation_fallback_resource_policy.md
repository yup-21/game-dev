# 动画回退配置：仅 Resource 单级映射

- **不再存在任何写死的 Legacy Alias**：`WuxiaActorAnimationProfile.resolved_clip_for()` 优先匹配同名 Clip，仅在 `action_fallbacks` 明确声明时查找其直接目标。
- 单级回退，不支持链式搜索。映射目标必须直接存在于当前 Profile 的 `clips`；映射到不存在的动作、非法名称、自引用均导致 `valid_profile() == false`。
- 提供了 Profile 的角色，播放器只为 **实际 Clip + Resource 明确映射的动作 ID** 注册动画；不存在的动作不会再被程序化生成或替换成 `idle` / 其他动作。运行时请求缺失的动作会报告 `push_error` 并跳过该次视觉表现，规则层结算不变。
- 没有 `animation_profile` 的剧情／演示 NPC 原有简易程序化表现保持独立；它不参与带 Profile 的动作映射。
- 普攻事件使用语义 ID `attack`，连携事件使用语义 ID `combo`，不再在播放器里强行改成 `attack1/attack4`。完整十二动作模板显式指定 `{"attack":"attack1", "combo":"attack4"}`；六名使用旧九动作的角色本身已经具有 `attack` / `combo` Clip，因此只需显式配置 `walk/run/attack1–4` 到当前素材。
- 新 Resource 的合法示例：`action_fallbacks = {"attack4":"attack2", "run":"walk"}`，前提是 `attack2` 和 `walk` 已经是 **真实存在** 的 Clip。
- 角色 Resource 不会伪造动作帧。角色资源可以先使用旧贴图，之后补充同名动作 Clip 后自动优先播放真实 Clip；不需要修改技能的 `animation_action`。

回归：`checks/test_actor_animation_actions.gd` 包含无配置不回退、非法/链式映射拒绝、语义动作的显式 Resource 映射；`checks/test_resource_action_migration.gd` 校验六名正式角色 Profile。
