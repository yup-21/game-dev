# 《长风浮生录》战斗引擎优化与《听风十二势》统一架构 V1.1

> **文档地位：当前阶段唯一的目标架构说明。** 本文把先前的《战斗规则引擎 v0.3》、四维属性/CTB、自由行动、连携、有限 LIFO 连锁、攻防交锋、观招情报以及《听风十二势》V1 合并成一个可执行的迁移规范。它是设计与验收约定，**尚未修改用户工程**。
>
> **卡牌数据的真值来源：** 随包的 `听风十二势_技能数据草案_v1.json`（12 种定义、每方 16 张镜像牌组、2 个 Combo、3 个 Status）。不得将旧 v0.6 的《听风折锋剑》8 卡/12 实例与本版本混用。不得直接导入此前十套武学。实际 Godot 工程类名和组织必须先核对后适配。

## 0. 规则变更清单：防止把新系统叠加在旧框架上

| 维度 | 历史 v0.3 | **当前 V1.1 目标规则** |
|---|---|---|
| 主流程 | DRAW→PREPARATION→COMBAT→RECOVERY→END，玩家手动切换 | `TIMELINE → ACTION_START(自动) → ACTION(自由操作) ↔ CLASH(挂起交锋) → ACTION_END(自动) → TIMELINE` |
| 行动轮次 | 双方严格交替 | CTB：集气准备完成者获得行动权，可连续获得行动 |
| 内息恢复 | 下一次自己的 DRAW +3 | **仅随全局逻辑时间恢复**；`ACTION_START` 不免费回气 |
| 卡牌时机 | `allowed_phases` | `usages[].timing=ACTION/ATTACK_REACTION/DEFENSE_REACTION` + `conditions` |
| 响应 | 攻击者先、各 1 张 | **防御方先获得响应权**；双方轮流，最多各 2 张/根攻击共 4 张，连续两次 Pass 后 LIFO |
| 连携 | 当前回合的出牌顺序 | 当前 `ACTION` 的已完成主动攻击历史 + 命中/状态条件，非攻击位移不打断规定连携 |
| 状态计时 | 多按回合/DRAW | 按全局 `tick`、次数、事件三类明确声明 |
| 情报 | AI/UI 可能直接读取完整状态 | `VisibilitySystem` 对每位观察者生成**权限过滤**的只读视图 |
| AI | 仅选择简单合法行动 | AI 和玩家同规则；决策输入只能来自自己有权获取的信息与动作 |

**实现原则：不要同时维持两套权威状态机。** 原 Demo 可以在独立 `legacy` 模式下运行，但新 `tingfeng_test` 模式共用同一套规则核心，经必要适配映射旧卡牌，不复制一套新的 HP/内息/伤害引擎。

## 1. 设计目标和底层不变量

1. **规则引擎先于技能内容**：所有技能由 `CardDefinition + CardInstance + usages + effects + combo + hook` 声明；不按牌名写 `if/else`。
2. **唯一权威状态**：`BattleState` 存 HP、QI、位置、集气、牌区、状态、当前行动与挂起交锋；AI/UI 不得直接改值。
3. **动作入口唯一**：普通移动、基础攻击、基础护体、弃牌回气、主动卡和应变卡都走 `BattleController.submit(ActionRequest)`。
4. **时机与权利分离**：一个人拥有完整的 `ACTION` 行动权；双方可在 `CLASH` 中通过优先权使用响应，但不会取得完整回合。
5. **攻防信息不等于攻击意图**：未宣告时不显示敌人“下一招打什么”；仅显示依法可知的敌方手牌、威胁提示和已公开状态；攻击正式宣告后公开其身份、目标和范围。
6. **可重复、可审计、无双扣**：请求版本 + action_id 去重、固定 RNG/排序、纯逻辑规则队列、动画只播放结算事件。

## 2. 三层状态机，不要让主阶段膨胀

```text
BattleMode
  TIMELINE       计算下一时间事件/集气、随时间回气、状态到期
  ACTION         当前就绪角色自由移动、运功、主动出牌、结束行动
  CLASH          挂起原 ACTION 的一场攻击；双方响应与结算
  FINISHED       停止一切后续行动与时间推进

ACTION lifecycle (automatic):
  ACTION_START   起息：状态事件/手牌刷新/额度重置（首次不重复抽牌）
  ACTION_END     收势：结束事件、清理连携历史、扣集气门槛

CLASH internal steps:
  DECLARE_ATTACK → COMBO_CHECK → RESPONSE_PRIORITY
  → RESOLVE_STACK_LIFO → RESOLVE_ROOT_ATTACK → CLASH_CLEANUP
```

- `ACTION` 中可任意合法顺序穿插普通移动、出招、护体、调息、情报和继续攻击；不再强制“先布势后交锋后收势”。
- 每张**主动攻击**建立一个独立 `ClashContext`，可多次攻击，但每次交锋完成才回到当前角色 ACTION。
- 起手/收招只是行动历史、状态和卡牌 `conditions`，不是要求玩家切换的主阶段；可定义 `before_first_attack`、`after_active_attack`、`has_status` 等有限条件谓词。
- `ACTION/CLASH` 暂停全局时间；输入等待、界面动画也不能导致被动回气。
- 回合结算后手牌**不清空**，直到下一次该角色的 `ACTION_START` 才弃旧手牌、抽至五张，确保非行动方始终有防御应变机会。

## 3. 四维属性、集气与资源双时钟

**四维基准**：STR 力道 10、AGI 身法 10、CON 体魄 10、MND 心神 10。分别侧重攻击/破招、集气/机动、气血/防御、内息/接招。基准角色 HP20、最大内息6、初始内息3、集气速度100、普通移动额度2格。

**CTB**：`CHARGE_THRESHOLD = 10000`；集气 `gauge += charge_speed * delta_tick`；到门槛者获得一次 ACTION，结束时减去阈值并保留溢出。没人 Ready 时事件驱动地跳到最近一次集气完成或定时状态事件，处理期间对所有角色统一结算时间流逝。

**回气**：基准 `qi_regen_per_100=3` 内息/100 tick，消耗比率由心神和武功修正；同一全局时间中身法快慢**不改变回气总量**。可以让高速角色多行动/多刷牌，这是身法的真实收益，必须单独统计而不是暗中额外回气。生命微量恢复同样按时间推进。内部建议 `1QI=10000 units`，费用按0.1QI单位向上量化，恢复可更细地积累，禁止浮点累计误差。

**开局**：两人各3QI、5初始牌、`global_tick=0`，双方 Ready；首次 ACTION_START 不重复抽牌/补气。相同时间 Ready 采用固定稳定 tie-break；如果公平性要求轮换，规则在引擎层显式编码并保持可重放。

**状态有效期**：持续伤害、护体到期、藏锋/明牌/露隙用绝对 tick；“下一次命中”“下一次接招”用事件计数。严禁用角色出手频率驱动所有持续伤害。当前 `听风十二势` JSON 中相关持续时间为150 tick，护元100 tick，按数据文件实际值实施。

## 4. 核心模块职责（逻辑角色，不是强制目录名）

| 模块 | 唯一责任 | 不能做什么 |
|---|---|---|
| `BattleState` | 所有权威状态和版本 | 直接包含 UI 节点 |
| `BattleController` | ActionRequest 入口、提交与迁移状态 | 逐个牌名分支 |
| `TimelineScheduler` | Ready 选择、推进全局 tick、时效/恢复 | 使用现实帧时间驱动规则 |
| `AttributeSystem` | 四维→衍生值，快照与缓存失效 | 从 UI 获取属性真值 |
| `ActionValidator` | 当前权限/时机、目标、牌区、次数、路径 | 校验过程中扣费/改状态 |
| `CostResolver` | QI/HP 成本折算与一次性支付 | 自行绕过合法性 |
| `ComboResolver` | 已完成主动攻击序列、连携奖励 | 直接改变伤害/场景 |
| `ClashController` | `PendingAttack`、优先权、Pass、LIFO 与挂起恢复 | 在栈结算中重入一次完整交锋 |
| `ContestResolver` | 破招/接招/迎击、招路条件对抗 | 用隐藏随机骰替代规则 |
| `EffectResolver` | 标准原子效果、命中/护体/HP、位置与状态变化 | 读取场景节点，调用 UI |
| `StatusSystem` | 三类到期方式、状态触发与叠层 | 按不一致的“回合数”暗中计时 |
| `VisibilitySystem` | 按观察者生成 hand/日志/状态投影与已知牌记录 | 把敌方完整手牌传给 AI |
| `HookRegistry` | 受限的 validator/modifier/trigger 扩展 | 持有可变 State、递归 submit |
| `BattleUI` / `EnemyAI` | 依据可见信息、合法动作选择/展示 | 写入权威 HP/QI/牌区 |

**推荐数据对象**：

```text
BattleState
  battle_id, global_tick, mode, active_actor_id, request_version, rng_state
  actor_states[id] -> hp_units, qi_units, charge_gauge, derived_stats,
    position, draw_pile, hand, discard_pile, resolving_zone, statuses,
    movement_used, basic_attack_used, basic_guard_used, discard_for_qi_used
  action_context -> actor_id, action_sequence, resolved_attack_history
  clash_context? -> root_attack, response_stack, priority_actor_id,
    consecutive_passes, response_used_by_actor, current_step
  knowledge[viewer_id][opponent_card_uid] -> observed definition and validity

CardDefinition (readonly) -> id, tags, threat_level, usages[], effect descriptors
CardInstance -> uid, definition_id, owner_id, runtime_modifiers
ActionRequest -> battle_id, version, action_id, actor_id,
  command_kind, card_uid?, usage_id?, target?, target_cell?, link_id?
```

- CardDefinition 必须只读且共享，牌区永远保存 CardInstance UID；发动牌移入 resolving_zone，结算后才入弃牌堆。
- 公共日志与开发者全知日志/快照分离；UI Signal 只通知渲染、不能重新触发规则变更。

## 5. 一次行动/攻击的事务协议

```text
(1) submit(request) 检查 battle_id、版本、action_id 去重
(2) 校验行动权/交锋响应权与时机、CardInstance 区域与 usage
(3) 查询属性、Hook 修正，完成目标/路线/费用合法性校验
(4) commit 扣资源、锁定 card UID、写 pending；此前失败=零副作用
(5) 若为非攻击，统一 Effects 结算并回 ACTION
(6) 若为主动攻击，创建 root_attack，ComboResolver 加入奖励
(7) 防御方先获得优先权，双方交替追加响应或 Pass
(8) 双方连续两次 Pass，或已到上限/无合法响应→关闭加入窗口
(9) 按响应栈 LIFO 结算，不允许结算中再插入新响应
(10) 检查根攻击是否中断、目标实际位置是否仍在合法覆盖中
(11) 命中时：原伤害 + 属性差有界修正 + 连携 + 有效增强 - 减伤
     → 护体吸收 → 扣 HP → on_hit/on_hp_damaged 各自触发
(12) 清理 resolving_zone、产生事件、检查终局、恢复原行动者 ACTION
```

### 5.1 连锁响应精确定义

- **根攻击本身不算响应层**；每方最多2个响应、总响应最多4；声明响应时支付成本，锁定 `link_id` 和明确目标。
- 一次合法追加响应后优先权转给对方、连续 Pass 清零；Pass 使优先权转移、计数加一；双方连续 Pass 关闭加入窗口。到达硬上限也可以直接关闭加入窗口。
- **后进先出**：例如 根攻击→防御者「卸劲」L1→攻击者「截势」L2 指向L1→防御者「截势」L3 指向L2，结算 L3 取消L2、L2跳过、L1生效。
- 牌在声明时必须合法；结算时依赖已变化的状态需重新检查效果前提。无法再达成的效果按规则落空但已付款不退。取消响应只取消目标 Link 的未结算效果，不追溯撤销已支付的费用和公开动作。
- `interrupt_attack` 使**根攻击**停止后续命中判定；不会额外启动一次完整反击回合。未来真正反击应使用受控后续效果命令。
- 在响应窗口和逆序结算中**不推进全局 tick**。任一方响应权与 ACTION 行动权独立。

### 5.2 范围、闪避与变招

- 主动攻击正式宣告时记录攻击方位置、原目标格、目标角色和初始覆盖；不会因为目标移位而自动追踪。
- `变锋式` 可扩大当前攻击的**覆盖区域**，但不自动更换目标 actor；`游身式` 改变目标的实际位置。按 LIFO 逐层结算后，根攻击统一检查最终覆盖与实际位置。
- 若目标已离开覆盖→`ATTACK_MISSED`，不发 `ATTACK_HIT`，命中后状态不附加；攻击已付费用不退。
- 对实际命中但护体完全吸收：仍产生 `ATTACK_HIT`，但不产生 `HP_DAMAGED`。

### 5.3 破招、接招与中断

- 不存在全局的被动概率弹反；角色必须在合法时机使用有 `parry/intercept/break` 效果的卡牌，才能调用 `ContestResolver`。
- `break_score = source.break_power + skill.break_bonus`；`parry_score = target.parry_power + response.parry_bonus + route_bonus`。首版的《迎锋式》分成功（中断攻击并赋露隙）、相持（伤害-1）、失败（无效果）三档，阈值、招路加成以卡牌数据规格为准。
- **接招/迎击**是交锋内的有效效果，不是免费获得新的集气行动。可制造跨行动的【露隙】，下一次符合条件攻击消耗。

## 6. 招式连携：在 Chain 之前判定，但记录结算结果

- `ComboResolver` 读取本次 ACTION 中**已合法完成**的主动攻击历史，包括 `card_uid, definition_id, tags, resolved, hit, interrupted, action_seq`。
- 当前即将宣告的攻击与历史匹配时，声明连携奖励写入 root_attack；随后对方可以响应当前攻击。禁止从非法请求/响应牌/中断攻击中错误获得连携。
- 非攻击位移、护体、观势默认不打断“上一张主动攻击”的历史；如果某条 Combo 要求严格连续卡牌，可单独声明匹配策略。
- 首版只做 `探锋式→追风式` 的本次攻击伤害+1，以及【露隙】目标被《照胆式》真正命中后+2并消耗露隙。每次攻击最多一个主动连携奖励，每种连携每个 ACTION 最多触发一次。
- **不要将 Combo 与 Chain 合成一个栈。** Combo 在不同主动攻击之间连续推进；Chain 只围绕当前这一场已宣告攻击。

## 7. 武学使用时机与通用效果

**CardDefinition 推荐接口（是示意，不与现有 JSON 强制逐字段一一对应）：**

```json
{
  "id": "tf_step",
  "tags": ["movement", "lightness"],
  "usages": [
    {"id":"active", "timing":"ACTION", "cost":{"qi":1},
     "target":{"kind":"reachable_cell","max_distance":2},
     "effects":[{"type":"move","max_distance":2}]},
    {"id":"evasion", "timing":"DEFENSE_REACTION", "cost":{"qi":1},
     "target":{"kind":"adjacent_empty_cell","max_distance":1},
     "effects":[{"type":"move","max_distance":1}]}
  ]
}
```

**必须尽量可复用的原子效果**：`deal_damage`、`add_shield`、`move`、`gain_qi`、`modify_pending_damage`、`modify_attack_area`、`interrupt_attack`、`apply_status`、`draw_cards`、`discard_cards`、`cancel_response_link`、`reveal_card_to_observer`。接招判定是通用 `ContestResolver` 结果，不针对「迎锋式」写死特殊类。

**Hook 三类**：
- `ValidatorHook`：对合法性/额外条件给出结果，禁止直接修改 State。
- `ModifierHook`：返回成本、攻击、接招等修正，按固定优先级排序。
- `TriggerHook`：响应 `ACTION_STARTED, ACTION_ENDED, CARD_PLAYED, ATTACK_DECLARED, CHAIN_LINK_ADDED/RESOLVED, ATTACK_HIT, ATTACK_MISSED, HP_DAMAGED, STATUS_APPLIED, TIME_ADVANCED`，只返回声明式 EffectCommand。

对同一个根行动的 Trigger 命令设确定性顺序、幂等 ID、最大条数（首版32），不允许递归调用 `submit`、重入响应窗口或直接写 State。特殊牌首先尝试通用效果与条件组合，确有必要再登记 Hook ID。原型先做 **Hook 的机制与一条事件验证**，而不是为12张牌写12份脚本。

## 8. 手牌情报是完整的信息权限层

- `BattleState` 维护所有卡实例的真实 ID；对任意玩家或 AI 输出的 `BattleView(observer_id)` **不得包含其无权知道的敌方卡定义或 UID**。
- 基础公开：双方 HP/QI/位置/状态、敌方手牌数量、已宣告招式、公开弃牌/卡牌事实。敌方持有 `threat_level=HIGH` 且无隐匿时，仅显示头顶「危」，**不预告其下一步动作**。
- `观势式` 选择对方一处未知手牌槽，揭示其 UID/牌名给当前观察者；该牌离开手牌后实时知识失效。不能让 UI/AI 通过未知卡 UID 精准选择目标。
- `藏锋式` 使敌方危险提示变「？」并阻止新的普通窥牌；**不删除已经合法看见且仍留在手牌的卡牌事实**。
- `照胆式` 命中后产生【明牌】；持续期间即使有藏锋也公开当前整手牌和新抽到的牌。优先级 `明牌 > 藏锋 > 已知单牌 > 危险提示`。
- `VisibilitySystem` 同时过滤战斗日志、错误消息、卡名浮层、合法操作信息，禁止侧信道泄露。玩家与 AI 使用相同权限检查；开发者全知视图必须单独隔离，绝不能当作 AI 输入。
- 认知只代表**知道对方手中有某张牌**，不代表对方计划使用。攻击一旦宣告，发动卡牌、目标、招路和范围公开，不受藏锋遮挡。

## 9. 《听风十二势》作为唯一内容验收包

不重写武学名单和测试 JSON。使用同目录 `听风十二势_技能数据草案_v1.json`：

| 类别 | 测试牌（12 种定义） |
|---|---|
| 主动进攻 | 探锋式、追风式、断岳式、照胆式 |
| 位移/护体 | 游身式、护元式 |
| 交锋响应 | 卸劲式、迎锋式、变锋式、截势式 |
| 情报 | 观势式、藏锋式 |

每方 16 张镜像实体牌、初始抽 5 张；两组连携 `探锋追风` / `乘隙照胆`；三项关键状态【露隙】【藏锋】【明牌】。若 JSON 中定义的 key/费用与本说明文字不一致，**以 JSON 的实际卡牌数据为技能值真值**，但流程与权限由本文约束；发现机制冲突需报出并通过最小兼容处理，不能悄悄改规则。

AI 可以以简单阈值应对：观察「危」时保留内息，有接招/闪避则选择，能连携就尝试，必要时观势或藏锋；不允许读取未知真实牌后反向推理策略。

## 10. 迁移顺序：先通用内核、后测试内容

| 阶段 | 优先处理 | 完成标准 |
|---|---|---|
| 0 基线审计 | 读取项目状态机、牌区、UI/AI、旧卡、请求去重和回放 | 输出“现有文件→目标职责”映射、旧行为测试 |
| 1 自由行动生命周期 | 旧五阶段压成自动 START/END + ACTION；迁移 usages/条件 | 新模式能在一次 ACTION 中移动→攻击→移动→攻击 |
| 2 CTB/资源时钟 | AttributeSystem、Scheduler、统一回气和状态时钟 | 速度影响频率不影响同时间回气，初始不双抽 |
| 3 核心 Clash | root attack、优先权、Pass、LIFO、范围重查、中断 | 可在双方响应 4 层时正确结算及回 ACTION |
| 4 统一 Effect/Combo/Hook | 原子效果、一次支付、连携历史、限流 Hook | 没有按牌名特判，非法行动无副作用 |
| 5 情报与 AI | 权限投影、危/观势/藏锋/明牌、视角日志 | AI 看不到未知敌牌，响应已公开牌可见 |
| 6 《听风十二势》 | 12定义/16实例镜像组接入、界面与短局 | 同一核心实现双方对战且旧Demo未破坏 |
| 7 回归测量 | 针对性自动测试和种子复现 | 逐项输出通过/未通过以及阻塞因素 |

阶段顺序可依既有代码做小范围调整，**但任何内容扩展都不能替代先做好规则内核**。

## 11. 强制专项验收清单

1. 初始双方3QI/5手牌/在t=0准备好，首次 ACTION_START 不重复抽牌；后续才弃旧手牌抽新。
2. 速度120和100的人物在相同100 tick 的可回气量相同（不触上限），只是行动次数不同；行动、交锋和动画均不推进时间。
3. 一次 ACTION 可以普通移动→探锋→游身→追风，连携正确；响应卡不污染主动连携历史。
4. 非行动者仍能提交合法响应，但不获得新的 ACTION、不刷新自己的手牌或普通移动额度。
5. 根攻击→卸劲L1→截势L2→截势L3，LIFO 导致 L1 最终生效；所有成本分别只扣一次。
6. 游身离开覆盖→MISS；变锋改变覆盖后再按实际位置判断；没有自动跟踪，MISS 不触发命中后效果。
7. 迎锋三档按 break/parry 与招路判定；成功中断原攻击时不再造成根攻击伤害，触发露隙。
8. 照胆命中【露隙】+2并消耗且施加明牌；护体完全吸收也算 HIT 但不算 HP_DAMAGED。
9. `断岳式` 在敌方手牌中时显示「危」，藏锋变「？」，打出最后一张高威胁牌后危消失。
10. 观势只揭示合法的一个未知手牌槽；旧已知 UID 保留到离手；明牌持续中新牌实时暴露，覆盖藏锋。
11. AI 在未窥牌时不能针对真实未知卡做精确选择；所有 UI、公共日志和非法请求错误不泄露未知定义 ID。
12. 手牌区守恒，`resolving_zone` 不可在同一连锁中重洗；拒绝/重复/过期命令零副作用。
13. 相同种子 + 相同 ActionRequest 序列 → 相同权威状态和事件日志；不依赖动画帧时间或对象遍历顺序。
14. 角色死亡或战斗结束后停止挂起交锋、时间推进与新行动，不能出现多次结算。
15. 至少有一个 Hook 验证事件、优先级与受限副作用，可不为每张牌单独开发 Hook。

## 12. 当前明确不做

不做十套武学混搭、经脉、门派、永久伤势、庞大架势条、无限连锁、实时帧招、通用任意脚本 DSL、完整多方联机、随机命中/被动闪避率、复杂 AI 搜索、敌方未来行动意图预告、诈牌假情报。上述机制只在抽象接口确有必要时预留，不允许为可能的未来功能提前重构大量代码。

## 13. 交付说明

优先用本文件 + `听风十二势_核心战斗机制验证设计_v1.md` 的牌面细则 + `听风十二势_技能数据草案_v1.json`，由 Codex 读取工程后实施；不要再将 v0.3 的旧阶段约束、v0.6 的八张《听风折锋剑》和最新架构混在一个任务里执行。验收报告必须区分已实现/已测试/仅预留，严格报告路径、测试命令与结果。
