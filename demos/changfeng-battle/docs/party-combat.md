# 多角色阵营战斗框架（3v3）

**目标：** 在不复制任何战斗计算代码的情况下支持：多名手动队友、友军 AI NPC、多个敌方 AI。采用相同的 CTB、卡牌、武学状态、费用、状态、攻防响应、条件、可见性与胜负规则。

## 启动可玩场景

在 Godot 4.x 中打开 `party_battle.tscn`，或使用：

```bash
godot --path demos/changfeng-battle res://party_battle.tscn
```

演示阵容（固定种子 2026，开始角色 0）：

| 角色 | ID | 阵营 | 控制 |
| --- | --- | --- | --- |
| 沈长风 | 0 | 0 友方 | PLAYER |
| 顾清霜 | 2 | 0 友方 | PLAYER |
| 青衫客 | 3 | 0 友方 | AI |
| 拦江客 | 1 | 1 敌方 | AI |
| 铁衣卫 | 4 | 1 敌方 | AI |
| 夜行刀 | 5 | 1 敌方 | AI |

其中角色 0、2 会在各自拥有 ACTION 或交锋响应权时等待玩家操作；其余角色使用 `EnemyAI.choose_action(model.decision_context(actor_id))` 自动提交**完全相同**的合法动作。右侧按合法动作分组选择，若动作有目标，则点击棋盘中高亮的格子或人物。Space / Enter 结束行动／Pass，右键取消，R 相同种子重开。默认 `battle.tscn` 仍为两人战斗，未被替换。

## 通用阵容协议

```gdscript
model.reset(2026, 0, "tingfeng", {
  "combatants": [
    {"id": 0, "name": "侠客", "team_id": 0, "controller": "PLAYER", "cell": [6, 4]},
    {"id": 2, "name": "友军", "team_id": 0, "controller": "AI", "cell": [5, 4]},
    {"id": 1, "name": "敌人", "team_id": 1, "controller": "AI", "cell": [8, 4]}
  ],
  "schools": {0: "tingfeng", 2: "tingfeng", 1: "tingfeng"},
  "attributes": {2: {"AGI": 12}},
  "passives": {2: {"insight": 1}}
})
```

- `combatants` 可选。不提供时默认 0: PLAYER 友方，1: AI 敌方，与旧测试兼容。
- 数量为 **2–8**，ID 唯一、非负且不大于 1023，出生格必须可通行且不可重叠；当前版本仅支持阵营 0/1，至少各有一名角色。控制类型是 `PLAYER`／`AI`，不决定角色强度及规则。
- `schools`、`attributes`、`passives`、`techniques` 继续按 actor ID 向同一个系统注册，双方无特殊待遇。
- `BattleState.is_hostile()` 用于所有基础攻击和武学敌方目标查询，不允许攻击友军。
- 交锋仍为**单次攻击、一个攻击方与一个被攻击方**的已有四层 LIFO 响应链，第三方不能介入。本迭代不增加多角色合击或范围伤害，这类新规则需要单独设计。
- 胜负由阵营所有成员存活情况决定。阵营 0 全员败北记 `defeat`，阵营 1 全员败北记 `victory`，双方均不存在记 `draw`；`winner_id` 保持为获胜阵营第一名存活角色 ID，新增 `winning_team` 提供明确阵营归属。
- `round_no` 在多人局按角色数量估算集气轮次，但实际时机仍只由 CTB 决定，不用于判定效果。
- `knowledge`、`combo_history` 和完整角色私有状态均按动态 ID 初始化；`snapshot(observer_id)` 只向观察者展示自身私有卡牌／阶段，其他角色的手牌仍遵循观势／藏锋规则。
- `controller` 是表现层和 AI 决策路由信息。它**不应**放进 `CombatRules.validate()` 限制执行主体，因为 Player 与 AI 必须共用同一个命令入口；在需要真正联网/防作弊的场景应由外层权限层验证客户端的玩家身份。

## 验证

```bash
godot --headless --path demos/changfeng-battle --script res://checks/test_parties.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_tingfeng.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_tingfeng_ai.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_wuxue_v3.gd
```

同时运行原有完整回归脚本 `checks/verify.ps1`，并用窗口手动验证 `party_battle.tscn` 的手动队友、自动队友、敌方轮次、目标选择与连续交锋。注意：本次提交环境无 Godot 可执行文件，**未能实际跑通测试或抓取截图**；提交 PR 后仍需这些验证。

## 暂不包含

- 友军辅助/治疗目标类型、多目标 AOE、援护/夹击、中途增援、动态转换阵营和网络多人权限认证。
- 原 `battle.tscn` 是双人 UI，为确保其现有自动化截图不变化，新的多人界面使用独立 `party_battle_view.gd`；今后可把两者汇合到一个角色卡片和目标组件，规则层已经共享。
