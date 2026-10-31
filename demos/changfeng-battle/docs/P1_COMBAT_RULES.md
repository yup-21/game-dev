# P1 战斗规则原型：架势与破势（首个闭环）

本阶段把武侠战斗的「架势积累、破势、露隙、化劲恢复」纳入权威规则层。
已存在的 CTB、卡牌、衍生连击和交锋 LIFO 不换协议；R10 startup/active/cancel/
invulnerable 时间窗继续只驱动动画，**不得用玩家本地帧时间更改伤害、合法行动或无敌**。

## 规则与内容合同

- 每名 CombatantState 保存 `posture`（已积累的架势压力）；`stats.max_posture`
  为上限，初始值 10，可经独立来源的 `StatModifierSystem` 修正。
- 事件仅在 `BattleModel.submit` 验证成功后由 `CombatResolver` 执行。
  `deal_posture` 和 `recover_posture` 是严格校验的声明式 Effect，
  均使用 1–100 的整数 `amount`；来源、命中判定由原有规则控制。
- 每次达到上限，架势立即归零、施加已有的 `opening`（露隙）状态，
  并记录 `POSTURE_BROKEN`。露隙按已有 CTB 全局 tick 过期；
  破势**不额外伤血、不跳过 CTB、不强制取消本次攻击**。
- `tf_sunder/heavy` 命中后追加 4 点架势压力；未命中、闪避或被
  `interrupt_root_attack` 打断时不会执行 `on_hit`。
- `tf_guard/guard` 执行后恢复自身 3 点架势压力，原来的护体盾规则不变。
- `BattleModel.snapshot` 为角色、AI、HUD 输出 `posture/max_posture`；
  左侧队伍状态新增一条只读金色进度条，视图完全不修改权威状态。

本设计是最小、可测、可演示的战斗规则原型，不预设未来完整姿态体系。
架势未加入随机暴击、硬直或真实时间无敌；未来应将这些规则作为独立的
`CombatRules` 判定条件与可配置 Effect，保留确定性和回放友好性。

## 自动化验收

新增 `checks/test_posture_authority.gd`，验证：

1. 合法重斩的三次真实命中分别累计 4、8、触发破势归零和露隙；
2. 交锋 Pass 和动画 ACK 不会自行产生或修改架势；
3. 失手（防守方换位）不触发 `on_hit` 架势压力；
4. 防守恢复与原有护盾兼容；
5. 无效数量拒绝、上下限不越界，属性 Modifier 可扩展架势上限；
6. 敌方架势经只读 Snapshot 可见，不依赖 GUI 取值。

运行：`godot --headless --path demos/changfeng-battle --script res://checks/test_posture_authority.gd`。
完整回归依然由 `.github/workflows/wuxia-hud.yml` 执行。

## P1 取消与连招权威规则闭环

- 取消不是 real-time 动画中断：只允许经过 `BattleModel.submit` 的
  `ATTACK_REACTION` / `DEFENSE_REACTION` 取消响应；行动时机由
  `ReactionController` 的 priority actor 和 LIFO 栈决定。
- `cancel_chain_link` 仅可选**对手未结算的 response link**。
  根攻击不在栈中，同阵营自身 response / 已取消 / 已结算 link 不能取消。
  `ReactionController.cancel_link` 只在权威结算阶段生效。
- `tf_change_stage` 的反制动作消耗原有独立 Qi quote；即使自己的应变
  被下一层反制，已支付费用也不回滚。非法 link 在预验证阶段拒绝，且不
  修改 Qi、卡区、CTB 或 revision。
- Combo 配置新增 `target_posture_at_least` 条件，与原
  `target_has_status` 可组合。配置在加载时验证引用、阈值和 Effect。
  新的 `heavy_pressure` 连携在目标已有至少 8 点架势压力时，使
  `断岳·重斩` 伤害 +1，然后命中带来破势与 `opening`；
  之后的 `断岳·照胆` 会走已有 `opening_to_expose` 的露隙追击。
- `checks/test_p1_combat_closure.gd` 在真实 3v3 roster 上覆盖连携
  与三层取消优先权，同时执行六角色 FREE AI 决策回归和实际 HUD 节点
  架势进度检查。原有测试仍负责倒序应变、卡牌衍生和场景加载。

**这套规则没有“帧级无敌/取消判定”**：即使播放动画快速跳过，伤害、
应变权和 Qi 也不会变化。这是回合策略 + 动作演出架构的一项设计边界，
不是临时功能缺失。

## 尚未完成的 P1 工作

- 让闪避、格挡、架势反制与击退在 3v3 复杂地形中完成
  **目标 PC 实机 GUI 和 60 秒性能采样**；Headless CI 不能替代。
- 实际逐帧动画、架势破碎 VFX 和音效；本提交仅提供事件与简洁 HUD。
- 长期平衡：架势恢复节奏、连击加成、不同角色的 max_posture，
  暂不视作已完成正式玩法数值。
