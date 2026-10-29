# 听风机制迁入接口约定

默认玩法为 tingfeng。保留 15×10 地形、角色和现有绘制风格；同一个 BattleState 保存唯一真值。旧机制存档留在原 Creator 工作区，不属于本仓库运行依赖。业务逻辑不等待动画。完整规则及当前限制见 [战斗机制与框架详细说明](docs/tingfeng-engine.md)。

V3已扩展双方流派选择、状态时钟、射程与限次，新增接口见 [V3接入约定](V3_CONTRACT.md) 与 [兼容性分析](docs/wuxue-v3-integration.md)。

## 当前已实现接口

- `BattleModel.reset(seed=2026, first_actor=-1, profile="tingfeng", options={})`。options 可含 `attributes:{0:{STR:10,AGI:10,CON:10,MND:10},1:{...}}` 与 `passives:{0:{insight:0,conceal:0},1:{...}}`。默认双方观势/藏锋0。first_actor 仅控制相同速度/集气开局的 tie-break，不绕过 CTB。
- 唯一入口 `request(kind, actor_id, params={})` → `submit(req)`；合法查询 `legal_actions(actor_id)` / `decision_context(actor_id)`；均使用整数角色 ID 和 Vector2i。
- kind：MOVE、BASIC_ATTACK、BASIC_GUARD、PITCH_CARD、PLAY_CARD、PASS_REACTION、END_ACTION。PLAY_CARD 指定 card_uid（card_id 是 UID 别名）、usage_id；其他参数 target_cell、target_id、link_id。请求带 battle_id、action_id、request_id、expected_revision、request_version；两个版本字段同时提供时都须为当前版本，两个 UID 别名须一致。action_id 与 request_id 可不同，但二者都必须未消费且都会登记防重。END_PHASE 仅作为 END_ACTION 兼容别名。
- result：success/error_code/message/events/revision/ticket。`acknowledge_animation(ticket)` 只解除表现输入屏障，永不推进逻辑时间、回气或生成额外行动。
- snapshot(observer_id)：保留 seed、battle_id、revision、request_version、animation_pending、ticket、outcome(playing/victory/defeat)、winner_id、terrain、logs、hand、actors、active_id、responder_id、phase、reaction、attack；新增 mode、global_tick、action_no、clash。phase=ACTION/CLASH/TIMELINE/FINISHED，reaction=ATTACK/DEFENSE/NONE。profile=tingfeng。
- actors[]：id/name/cell/hp/max_hp/qi/max_qi/shield、gauge/charge_speed、attributes、passives(仅己方)、statuses、turns_started、normal_moves_used/move_budget、hand_count/draw_count/discard_count/resolving_count、observed_hand(未知只含known:false；已知含uid/definition_id/name)、danger("危"/"?"/"")。数值 HP/QI/护体显示用浮点，权威使用10000整数单位。
- hand[]：card_id=UID、uid、definition_id、name、kind(attack/move/shield/reaction)、cost(默认用法显示QI)、description、usages[]（id/name/timing/cost:{qi,hp}/target/effects）。UI 按合法 actions 过滤 usage，不按 kind 推断可用时机。
- 每个 usage 的 `quoted_cost:{qi,hp}` 是经过属性和费用修正后的实际报价；UI 优先显示它。`cost` 保留配置基础值。
- attack：attacker_id/defender_id、origin_cell/target_cell/affected_cells、base_damage/attack_bonus/defense_reduction、card_uid/definition_id/usage_id/route/interrupted。clash：priority_actor_id、consecutive_passes、counts、stack[]（id/link_id、actor_id、definition_id、usage_id、name、canceled）。
- decision_context(observer) 为同一权限投影 + observer_id/legal_actions；AI 不读取 model/state，只返回合法动作副本。
- 表现事件：MOVE{actor_id,from,to,path}、DAMAGE{actor_id,defender_id,hp_damage,absorbed,damage}、SHIELD{actor_id,amount}、COMBO_TRIGGERED{actor_id,name}；其他语义事件 ATTACK_DECLARED/ATTACK_HIT/HP_DAMAGED/ATTACK_MISSED/ATTACK_INTERRUPTED、CHAIN_LINK_ADDED/RESOLVED/CANCELED、ACTION_STARTED/ENDED、TIME_ADVANCED 等以事件日志提供。当前观势刷新不产生独立 PASSIVE_INSIGHT 事件。

## 扩展约束

UI 和 AI 不改写状态，所有行动通过 request/submit；新机制优先使用通用效果、有限条件与注册 Hook，保持同一权威状态和双边对称结算。旧机制存档留在原 Creator 工作区，不属于本仓库的运行依赖。
