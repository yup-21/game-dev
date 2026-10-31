# R20 — 原生技能/阶段 Resource 与可注册效果执行器（首版）

R20 在 R18–R19 的原生资源管线之上增加 `WuxiaSkillDefinition`、`WuxiaSkillUsageDefinition`、`WuxiaEffectDefinition`、`WuxiaTechniqueDefinition`、`WuxiaTechniqueNodeDefinition` 和 `WuxiaEffectHandlerDefinition`。未来新技能不需要编写 JSON；在 Godot Inspector 中组合 .tres 子资源、加入 `data/content_manifest.tres` 后即可完成注册和校验。

## 明确分层

| 类型 | 职责 | 不负责 |
| --- | --- | --- |
| `SkillDefinition` | 技能身份、使用入口、卡牌生命周期和效果组合 | 行动权、HP/Qi 实际修改 |
| `SkillUsageDefinition` | ACTION/Reaction、消耗、目标和效果链 | 直接提交战斗命令 |
| `EffectDefinition` | 参数和嵌套效果的只读数据 | 执行 GDScript 或访问 BattleState |
| `TechniqueDefinition` | 额外阶段节点与状态转换，独立于手牌 | 自动生成物理卡牌 |
| `EffectRegistry` | 效果类型 → 独立 Handler 的注册与执行 | 管理 Actor 或卡牌持有 |
| `CombatResolver` | 权威结算入口和事件发布 | 针对每张新技能写特殊分支 |

原有 `CardSystem` 与 `TechniqueRuntime` 从同一 Manifest 额外接入原生内容；旧 JSON 的既有十套武学与听风原始卡牌继续保持兼容，验证后再逐批迁移。不同机制的运行态仍属于 `BattleState`，不会复制进共享 `.tres`。

## 在 Inspector 中制作

1. 新建 `WuxiaSkillDefinition`，配置稳定 ID、名称、所属已有武学 ID、是否衍生卡和 `usages`。
2. 新建 `WuxiaSkillUsageDefinition`，设置 ACTION/反应时间、Qi/HP 费用、目标和效果列表。
3. 在 `effects` 中加入 `WuxiaEffectDefinition`，设置 `effect_type`、`target`、`amount` 以及特有的 `parameters`。例如 `apply_status` 的参数有 `status_id` 和 `stacks`；`grant_card` 包含 `card_id`、`count`、`destination`。
4. 如果一个阶段能力不应进入牌堆，新建 `WuxiaTechniqueDefinition` + `WuxiaTechniqueNodeDefinition`，写清入口与下一阶段。角色 `techniques` 通过稳定 ID 学会该能力。
5. 将定义文件拖入 `data/content_manifest.tres` 的 `skills` 或 `techniques` 列表。
6. 运行 `checks/test_native_effects.gd` 验证引用、战斗命令、Buff、衍生卡和阶段能力。

演示内容：
- `data/native/skills/r20_probe.tres`：施加「铁壁」→ 按层数回气 → 生成 `r20_follow` 衍生卡。
- `data/native/skills/r20_follow.tres`：独立的一次性追击攻击卡。
- `data/native/techniques/r20_guard_stage.tres`：不占牌堆的额外护盾阶段。
- `data/native/effect_handlers/r20_qi_by_status.tres`：注册新底层机制 `r20_qi_by_status`。

## 注册式扩展及安全边界

已有 `gain_qi`、`heal_hp`、`add_shield`、`apply_status`、`consume_status` 由 `basic_effect_handler.gd` 接手；`CombatResolver` 在原有合法性检查和目标解析后通过 `EffectRegistry.dispatch()` 执行。移动、交锋、连携等复杂原有效果仍走原有路径，逐步迁移时必须保留状态事件时序。

真正新增底层效果时：

1. 在 `scripts/effects/` 下创建继承 `effect_handler.gd` 的 GDScript，提供 `valid_spec()` 和 `execute()`。
2. 新建 `WuxiaEffectHandlerDefinition`，指定效果类型和仓库内的脚本 Resource。
3. 将 Handler 引用加入 Manifest 的 `effect_handlers`，然后编写对应合法/非法输入与实战测试。
4. 不能覆盖内置 Handler；不接受任意外部脚本路径，也不支持内容表达式执行。Handler 仍然只能通过权威 Resolver 操作游戏状态。

**本轮范围**：完成原生技能、衍生卡、额外阶段能力及新 Handler 的实战闭环。不宣称已经重构旧十套武学、完成所有 Effect Handler，亦未实现全新的卡组编辑器或可视化条件树；这些属于后续 R20 增量工作与 R24 无核心修改验收。
