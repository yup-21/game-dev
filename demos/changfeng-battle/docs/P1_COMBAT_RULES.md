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

## 尚未完成的 P1 工作

- 将反击、招式取消、派生衔接进一步数据化，定义**行动优先权/消耗规则**，
  而不是从演出 cancel window 直接授权新指令。
- 让闪避、格挡、架势反制与击退在 3v3 的复杂地形和高并发中完成
  实机 GUI 与性能回归。
- 实际逐帧动画、架势破碎 VFX 和音效；本提交仅提供事件与简洁 HUD。
- 长期平衡：架势恢复节奏、连击加成、不同角色的 max_posture，
  暂不视作已完成正式玩法数值。
