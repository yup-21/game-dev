# 模块化内容制作指南（R11–R15）

本项目保持 **定义层 / 运行态 / 规则执行 / 表现层** 分离。添加内容应优先修改 JSON 资源与索引，不再修改 `BattleModel`、`CombatResolver`、`BattleHUDView`。

## 当前模块接口

| 内容类型 | 定义入口 | 运行态 | 战斗接入 |
| --- | --- | --- | --- |
| 角色 | `data/characters/index.json` + 角色 JSON | `CharacterRuntime` | `CharacterRegistry.battle_options()` |
| 武学与招式 | `data/school_forms.json` | `CardSystem` / `ComboResolver` | `BattleModel` |
| Buff / Debuff | `data/buffs/index.json` + 单独 JSON | `StatusSystem` | `StatModifierSystem` |
| 装备 | `data/items/index.json` + 单独 JSON | `InventoryRuntime` 的 item UID / equipment | 开局 `modifier_sources` |
| 消耗品 | 同一 `ItemCatalog` | `InventoryRuntime` 的 stack count | 返回 effects；战斗使用指令尚未接入 |

所有定义校验失败时返回错误，不得在失败目录中悄悄使用半套配置。

## 新增 Buff

1. 创建 `data/buffs/steady_breath.json`：
```json
{
  "schema_version": 1,
  "id": "steady_breath",
  "name": "调息",
  "public": true,
  "stack_limit": 3,
  "expiry": { "kind": "global_ticks_after_apply", "duration": 200 },
  "modifiers": [
    { "stat": "MND", "op": "flat", "value": 2 },
    { "stat": "qi_regen_u_per_100", "op": "percent_bp", "value": 1000 }
  ]
}
```
2. 在 `data/buffs/index.json` 的 `buffs` 数组增加 `steady_breath.json`。
3. 任何有效卡牌使用 `apply_status` 效果并引用该 ID，即可经统一 `StatusSystem` 应用。武学目录的引用校验会验证独立 Buff ID。
4. 叠层会乘算每条修正。移除、到期后从角色基础属性完整重算，不直接做逆向减法。

`op` 支持 `flat` 与 `percent_bp`。1000 basis points = +10%；所有来源的百分比先相加，再作用于“基础值 + 平直加成”。Buff 状态也可配置 `{ "kind": "permanent" }`，但剧情永久成长建议存于 `CharacterRuntime.growth_sources`。

## 新增装备 / 消耗品

装备定义示例（`data/items/...`）：

```json
{
  "schema_version": 1,
  "id": "training_sword",
  "name": "练习剑",
  "description": "朴素的练习用剑。",
  "kind": "equipment",
  "slot": "weapon",
  "stack_limit": 1,
  "modifiers": [{ "stat": "attack", "op": "flat", "value": 1 }]
}
```

再把文件名加入 `data/items/index.json`。装备槽位目前为 `weapon`、`armor`、`accessory`。相同定义的多件装备各有独立 item UID；装备不会消耗持有的物品实例。

消耗品通过 `effects` 描述 `heal_hp`、`gain_qi` 或 `add_shield`。**重要：** 目前 `InventoryRuntime.consume()` 只负责原子扣除并返回声明式效果，不能直接改动战斗气血、卡牌或回合状态。接入战斗时需要定义版本化 `USE_ITEM` 请求，由统一指令分发器校验费用、阶段、合法目标、动画及重放安全性后执行，避免消耗物品和战斗结算分离。

## 角色构建与装备入场

```gdscript
const CharacterRuntime = preload("res://scripts/character_runtime.gd")
const CharacterRegistry = preload("res://scripts/character_registry.gd")

var hero = CharacterRuntime.new("shen_changfeng")
hero.inventory.add("river_sword")
var sword_uid: String = hero.inventory.last_added_uids[0]
hero.inventory.equip(sword_uid)
hero.set_growth("growth:story_reward", [{"stat":"STR","op":"flat","value":1}])

# 角色永久身份与这一场战斗的 actor ID 无关。
var roster = [
    {"id":71,"name":"沈长风","team_id":0,"controller":"PLAYER","cell":[6,4]},
    {"id":72,"name":"追兵","team_id":1,"controller":"AI","cell":[8,4]}
]
var registry = CharacterRegistry.new()
var options = registry.battle_options(roster,
    {71:"shen_changfeng",72:"pursuer_captain"},
    {"shen_changfeng":hero.battle_build()})
# battle_model.reset(2026,-1,"tingfeng",options)
```

角色存档应通过 `CharacterRuntime.snapshot()` 保存，并用 `restore()` 校验后恢复。这个版本保存属性、已学/已装备武学、永久成长来源、背包、装备及 UID 序号；**完整的战斗中途存档、战斗状态转存和版本迁移仍需单独实现**。

## 验收与扩展边界

- 添加第 11 门武学、新角色、Buff 或装备，仅修改定义/索引及必需的美术资源。
- 旧 `GRID` 与 `FREE` 模式、CTB、牌组 12 张规则、连携次数和原有伤害逻辑不受内容数量变化影响。
- 自定义角色可使用 `battle_actor_id: -1`，而本次战斗使用任意合法 `actor_id`。
- 新美术路径限制为 `res://assets/`；正式导出时应验证动态路径资源包含在导出包中。
- `checks/test_catalog_extensibility.gd`、`test_character_dynamic_identity.gd`、`test_status_modifiers.gd` 和 `test_inventory_equipment_runtime.gd` 是内容扩展的最低自动回归。
