# 武学 V3 接入约定

默认仍为听风五式，在同一个 BattleState / BattleModel 中增加十门武学。数据来自 changfeng_wuxue_v3；不接入其单体 TingfengEngine，不更换15×10棋盘。兼容性分析与实际验收见 [V3移植结果](docs/wuxue-v3-integration.md)。

## 调用接口

- `model.reset(seed, first_actor, "tingfeng", {"schools":{0:"wind_sword",1:"saber"},"attributes":{...},"passives":{...}})`。schools独立选择；缺省为tingfeng。其余接口和整数actor_id、Vector2i不变。
- `snapshot.school_catalog`：11项只读条目 `{id,name,identity}`，tingfeng排首位；`actors[].school_id/school_name` 公开。`model.school_options()` 返回同样列表。
- `cards.catalog` 为SchoolCatalog对象；`catalog.schools` 为10项源流派详情，`catalog.forms` 为20项规范化定义字典，`catalog.statuses` 为3项新增状态字典，`catalog.combos` 为7项连携。`catalog.options()`、`catalog.get_school(id)`、`catalog.deck_for(id,default_deck)` 返回拷贝，`load_error`为空表示完整数据通过引用校验。
- CardSystem构造 `new(state, base_path="res://data/tingfeng_cards.json", school_selection={})`；只把双方选择流派的核心式和连携装入实际definitions（默认五式仍5定义/2状态/2连携），每人按所选流派构建12个实例。全体目录仅用于选择和非战斗旧引用映射。
- ActorState增加school_id/school_name及hand_generation。既有card_uses按 `definition_id+":"+usage_id` 记录once_per_action使用（同定义不同副本不能绕过），在本人ACTION_START重置。
- 旧ID适配 `LegacySkillAdapter.resolve_legacy(id, old_usage="main")` 只返回新definition_id/card_id/usage_id引用，不修改在战UID。

## 规范化与状态

- 原包 `damage_if_status/shield/low_hp` 规范化到根 `deal_damage.conditional_bonus`；force_move 的distance、away/toward转成max_distance、away_from_attacker/towards_attacker；opponent转enemy；远程target.max_distance填入attack_profile.range，LOS限定正交直线且阻挡角色。
- 保持原版用法数值和7条Combo，不为41种用法新建41个Hook。焦点逻辑在统一StatusSystem/Resolver/Timeline中。
- 凝势focus最多2层，250tick；下次根攻击（普通攻击或主动攻击牌）宣告消耗，+层数伤害，MISS/中断不返还；DOT/反应修正不消耗。
- 封气qi_seal 150tick，自然回气减半（主动gain_qi不变）；按时间区间处理，起势不另扣资源。
- 灼痕scorch最多2层，350tick；每100tick绕过护体扣当前层数HP并减1层，重新施加刷新expiry、保留最近next_tick。周期与到期同刻先周期后到期。大步推进内部切分，不漏周期。
- 同一tick先结算双方自然恢复/周期伤害，再检查胜负，可同时死亡（outcome="draw",winner_id=-1）。SCORCH_TICK表现事件含actor_id/stacks/damage，另发HP_DAMAGED{damage_kind:"status"}，不伪造ATTACK_HIT。
- 修复已知一级观势首次起势二次揭牌：以hand_generation去重，不以turns_started去重；有新抽牌才产生新手牌批次。

## 验证范围

保留当前五式默认行为和原定向检查；新增每流派牌区、全部usage、7combo、三种状态时钟、直线范围、血费、抽牌、跨副本限次、旧ID引用，以及同门/异门AI对局和UI流派选择。配卡仍为测试牌组，不宣称完成数值平衡或旧存档热迁移。
