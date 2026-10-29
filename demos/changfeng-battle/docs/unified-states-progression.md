# 统一状态、属性成长与武功进阶（架构替换）

## 目标与设计依据
在 Demo C 上替换旧版彼此独立的 `StatusSystem` 临时状态实现、`TechniqueRuntime` 阶段计时和暗伤专用数值计算。尊重原《四维属性与集气跑轴设计》与《完整游戏企划案》的边界：四维 STR/AGI/CON/MND 为永久属性基础，暗伤仅展示为负面 Buff，**寿元继续隐藏且本 PR 不添加寿元倒计时**。卡牌 UID/牌区、角色成长、武学学习成果仍是独立领域。

## 新权威数据源

| 模块 | 单一职责 |
| --- | --- |
| `state_system.gd` | 状态定义、叠层、来源、作用域、限时、永久、按自身行动到期、事件/次数到期、周期事件和条件关联转换 |
| `status_system.gd` | 薄兼容基类，继承统一 `StateSystem`，没有另一套旧实现 |
| `attribute_modifier_pipeline.gd` | 收集有效状态，按 **平面加成 → 百分比 → 上下限/定点量化** 稳定重算四维与衍生值 |
| `attribute_system.gd` | 永久属性公式、角色初始化和最终有效属性重算 |
| `technique_runtime.gd` | 武学图规则与解锁；通过统一状态实例管理当前阶段与过期，保留旧投影 API |
| `character_progression.gd` | 永久属性点、分配、经验记录，禁止超支和非法字段 |
| `martial_progression.gd` | 武学独立 XP、境界、显式突破、奇穴特质选择 |
| `game_session.gd` | 跨场景保留永久成长记录、角色永久状态、武学等级和 XP；战斗中的短时状态不外溢 |

### 数值分层

```text
初始四维 -> 永久成长/分配 -> 永久四维
永久四维 + 状态/装备/心法修正 -> 有效四维
有效四维 -> 衍生数值公式 -> 衍生数值的状态修正 -> 最终属性
base_max_hp_u  原始永久气血上限，不受 Buff 影响
max_hp_u       受 Buff/Debuff 影响的有效气血上限
hp_u           当前气血，不因解除 Debuff 自动恢复
```

`charge_speed` 变更后立刻影响后续时间推进，不清空或逆向重写已经累计的 `gauge`。与旧回气规则共用一个 `TurnManager`，不新增行动或免费恢复。

### 状态 JSON 示例

```json
{
  "id": "meridian_wound",
  "scope": "character",
  "expiry": {"kind": "permanent"},
  "stack_limit": 3,
  "modifiers": [
    {"stat": "max_hp", "op": "flat", "value": -2},
    {"stat": "AGI", "op": "percent", "value": -10}
  ]
}
```

另有 `fleet_step`（130 tick 轻身）、`meridian_open`（角色永久通脉）、`sword_flow`（下一次本角色攻击命中触发 `focused_stance`），均在 `data/tingfeng_cards.json` 中声明。

- 状态到期类型：`permanent`、`global_ticks_after_apply`/`global_ticks`、`owner_actions`、`charges`、`on_event`。
- 层数策略：`add`、`replace`、`refresh`、`ignore`，有每定义上限；过期状态不再生效。
- 关联转换：`transitions: [{event, subject, when, remove, apply, effects, consume_charge}]`；条件复用 `ConditionEvaluator`，效果复用 `CombatResolver.apply_effects`，不存在状态自身的任意脚本执行。
- 事件处理按 actor ID、状态 ID 和定义数组顺序排序，设有单次批次 32 次关联转换上限，避免递归事件风暴。
- `periodic` 定义统一进行周期伤害、减层；`scorch` 灼痕不再需要 `StatusSystem` 中的特殊分支。
- `scope: character` 且 `expiry.kind=permanent` 的状态可以 `export_persistent`/ `import_persistent`，角色级限时状态没有虚构“跨场景时间钟”；不能作为永久状态导入。
- 招式阶段现在存在 `technique:<id>` 私有状态实例中，过期计时由 `StateSystem` 执行；`TechniqueRuntime` 只提供配置、执行规则和投影同步。敌方观察者不能读取这些私有状态。

### 永久成长

`CharacterProgression` 的 `growth`/ `earned_points`/ `unspent_points` 不能超支；战斗中的 Buff 绝不写进成长记录。`MartialProgression` 使用独立 `xp`/ `rank`/ `traits`；阈值原型为 50、150、350、700 XP，达到阈值后仍需显式 `breakthrough`。只有达到招式 `unlock_rank` 才可发动该式。战斗中合法的 `ABILITY_USED`、标记 `martial_id` 的 `CARD_PLAYED` 可获得 XP。

Demo 结算中，战斗胜利最多奖励一次训练点及一次太虚修炼所得（防止单场重试刷取），可以选择修炼力道/身法及突破太虚。剧情会话的永久成长会进入下一场战斗。

## 兼容与验收

- 旧 `statuses.has/stacks/add/remove`、`TechniqueRuntime.configure/node/advance/reset` 和旧版 `actor.technique_states` 投影依然存在；核心生命周期已归 `StateSystem`。
- 旧卡牌数据里的 `apply_status`/`consume_status`、观察隐藏手牌、武学阶段、转移、连锁和 3v3 对称规则继续走已有 `BattleModel`。
- 无法把战斗专用状态冒充永久角色状态持久化。
- 核心回归要求：状态触发、过期不提前改变已积累集气；三个气血层次独立；角色成长与武功 XP 跨战斗存储；敌我使用同一系统。

```bash
godot --headless --path demos/changfeng-battle --script res://checks/test_unified_state_progression.gd
```

并运行 `checks/verify.ps1 -Stage All` 和 GitHub Actions 中所有原有回归。**提交环境没有 Godot 二进制；静态检查不等同于 Godot 运行通过，PR 保持 Draft。**

## 尚未实现

完整角色存档文件、装备栏和装备来源持久化、技能树的大型 UI、长线闭关修炼、持续消耗世界时间、隐藏寿元显化条件。留待完整 RPG 层开发。本 PR 只建立其可扩展基础和序章可操作的成长入口。
