# 武学双路径：衍生卡与可选阶段状态

## 两种机制不能混淆
- **生成卡派生**：探锋式是基础抽牌卡，只有「探锋·试探」这一个核心动作；施展后立即生成一次性「探锋·追风」卡（`tf_follow`）入手，不需从初始牌库随机抽中。追风为 ACTION 主动招，结算后放逐，连携「探锋追风」仍由 `probe_to_follow` 识别。
- **阶段状态派生**：变锋式是 `TechniqueRuntime` 的 **可选额外阶段能力**（`tf_change_stage`），不是出牌抽取物。角色装备后初始处于 `sealed`，施展「试探」切到 `ready`；交锋中根据攻守优先权可选择「变锋·追击」「变锋·截势（攻）」「变锋·截势（守）」之一。使用后归于藏锋态，未使用的 ready 状态最多保留到下一次自身行动之后。
- 两者均由合法动作系统及 BattleModel 处理费用、攻击目标、CTB、连携和 LIFO 逆序结算，独立于 UI 的卡牌排列。
- 旧的 `tf_change` 静态卡牌定义仅为历史模拟/回归脚本保留，不入起始牌库、不会在正式战斗生成；新增阶段技能以 `USE_ABILITY` 提交。
- 初始牌组仍只有 4 种可抽基础卡：探锋、断岳、游身、化劲，合计12张；「追风」/「变锋」是两类派生，各自有真实定义但不占牌组。

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
