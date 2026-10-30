# 武学衍生卡与角色流派绑定

## 已实现的规则（单一 BattleModel）
- 《听风五式》的 **变锋式** 为派生应变牌（`tf_change`，`generated_only` + `exile_on_finish`），**不进入初始抽牌堆**，而是在使用 **探锋式（试探 / 追风）** 发动攻击时以 `grant_card` 实时生成到攻击者手牌。
- 派生卡产生于 `ATTACK_DECLARED`，赶在守方获得第一响应权之前，故守方应变后攻方能在同一场交锋中使用“变锋·追击／截势”。它不靠随机抽到下一张，不额外跳过 CTB 和响应规则。
- 派生卡使用完进入放逐区；未使用的派生卡在正常下一次自身换手时移出，不会回到弃牌堆并循环抽出；关联的 `source_uid`、`parent_uid` 和 `child_uids` 便于后续视觉表现和技能成长。
- 听风五式仍是原有 **5 个卡牌定义／12 种 usage**：`tf_probe`、`tf_sunder`、`tf_step`、`tf_guard` 为抽牌源（4/3/2/3 共12张），`tf_change` 只通过前置招式派生。探锋的“追风”仍是同一式不同 usage，不是第二张独立牌。
- **十套流派** 保持已有完整 V3 核心武学、41 种用法、7 条连携；各流派12张基础牌的公共 `tf_change` 改为一张额外 `tf_probe`，基础牌组与衍生牌严格区分。

## 六人剧情流派

| 角色 | 阵营/操作 | 武学 | 风格 |
| --- | --- | --- | --- |
| 沈长风 | 玩家 | 苍风折柳剑 `wind_sword` | 连斩、乘势追击 |
| 顾清霜 | 玩家 | 沧澜回潮掌 `tide` | 化劲防守、反击 |
| 青衫客 | 友方 AI | 踏雪惊鸿步 `step` | 身法走位、突袭 |
| 追镖首领 | 敌方 AI | 裂岳沉锋刀 `saber` | 蓄劲重斩 |
| 黑衣刀客 | 敌方 AI | 赤炉离火掌 `ember` | 灼痕、引燃 |
| 夜行刺客 | 敌方 AI | 听雨千机针 `needle` | 远程控制 |

快速试玩的 1v1 使用沈长风 `wind_sword` 对决 `saber`，不再默认两边使用同一套听风卡牌。

## 扩展契约
- 定义派生卡：注册正常卡定义，增加 `generated_only:true` 和适当 `lifecycle`；不得在任何 `deck.cards` 中直接出现。
- 在前置攻击的 `effects` 顶层配置 `grant_card`，由 `combat_resolver.declare_attack` 生成。其他攻击效果仍然在命中/未命中或响应结算阶段处理。
- 不要把二/三段连续技变成初始牌组中的额外卡。高级多阶段武学继续使用已有 `TechniqueRuntime` 的 rank、阶段、跨 ACTION 保留与复位；每个流派独立选择其本身允许的连携和响应机制。

## 回归
```sh
godot --headless --editor --path demos/changfeng-battle --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_derived_wuxue_decks.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_wuxue_catalog.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_generated_cards.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
```
