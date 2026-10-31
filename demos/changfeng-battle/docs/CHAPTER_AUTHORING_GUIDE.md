# 章节、剧情事件与连续战斗制作指南（V2–V3）

本阶段验证“第二章只靠数据接入”与“连续两场战斗沿用同一角色运行态”。不实现磁盘存档。

## 章节注册

1. 在 `data/chapters/` 新建章节 JSON，并写入 `index.json`。索引顺序的首项为新游戏入口。
2. 章节指定 `story_path`（剧情 JSON）、`encounter_id`（`data/demo_scenario.json` 中的遭遇）、`next_chapter_id` 和 `scene`。
3. `scene` 提供背景、探索玩家初始点、NPC 的 `character_id` 与脚点、移动范围、界面文字。运行时使用同一 `opening.tscn` 模板和真实 `RoleSprite`。
4. `requirements` 是进入战斗的必要 flag 数组；`victory_events` / `defeat_events` 在相应结算时执行。
5. `ChapterCatalog` 会校验章节路径、剧情索引、NPC 引用、遭遇 ID、下一章指向、事件定义和场景配置。

第二章 `river_watch.json` 使用另一张背景、独立信使 NPC、独立遭遇 ID 和条件选择；剧情通过第一幕 `helped_escort` 标志分支，选择结果不会被写死在 `GameSession`。

## 剧情事件

`OpeningStory` 的对话节点或选择可附加 `events` 数组；事件到达时由 `take_events()` 一次性送入 `GameSession.apply_story_events()`。目前支持：

| 命令 | 效果 |
| --- | --- |
| `set_flag` | 设置会话布尔剧情标志 |
| `grant_clue` | 增加非装备类剧情线索（会话计数） |
| `grant_item` | 通过 `InventoryRuntime.add()` 向指定 `character_id` 的常驻背包发放物品 |
| `set_growth` | 通过 `CharacterRuntime.set_growth()` 修改角色永久成长来源 |

对话选择的 `requires` 数组支持 `{ "flag": "helped_escort", "equals": true }` 条件；仅显示合法选项。章节进入战斗的 `requirements` 使用同一条件格式。

事件提交是原子的：先创建角色快照副本，再统一校验和执行。若任一项无效（未知角色、未知物品、背包上限、属性配置错误），所有 flag、线索、装备和库存都维持原值。执行器不持有 `BattleState`，无法直接改变 HP、CTB、卡区。

`record_story_event("obtain_fragment")` 是旧序章的命名事件兼容桥梁；新章节使用 `events`，无需在会话脚本中添加对应 `match` 分支。

## 两场战斗的资源交接

- `GameSession.start_new_game()` 创建本次游玩常驻 `CharacterRuntime`，为主角演示配备江行长剑（锐锋词条）、两份金疮药和一颗回气丹。
- `GameSession.encounter_options()` 将玩家队伍 `battle_build()` 传入 `ScenarioDirector`，按稳定的 `character_id` 绑定本场 actor ID。
- `BattleModel.reset()` 复制每名队员的背包，出牌、Buff 和消耗命令仍全部由战斗权威系统执行。
- 结算时 `hd2d_battle.gd` 向会话递交所有我方角色的 `inventory_snapshot()`。会话只接受同一遭遇中我方角色的快照；校验 `instances`、`equipped` 和 `next_uid` 未变化，仅从战斗副本回写 `stacks`。
- 回写与章节奖励作为一个事务提交。首次战胜遭遇领取一次奖励，点击“重新挑战”不会重复刷奖励。
- `advance_chapter()` 保留角色属性、学会的武学、成长来源、装备 UID/词条、背包及剧情标志，切换章节配置与剧情图。第二章入场不再发初始物品。

**边界：** 战斗结束暂不继承 HP、临时 Buff 或卡牌手牌；它们由每场战斗重新初始化。没有中途存档、跨重启存档，也没有装备经济/锻造材料消耗。第二章的地图与 NPC 动作采用现有资产临时复用，目的是验证资源与关卡生产链路，不代表正式美术通过审查。

## 自动验收

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_chapter_pipeline.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_two_encounter_state.gd
```

- `test_chapter_pipeline.gd`：章节/资源/NPC/条件选项、进入遭遇门槛、奖励事务、非法事件回滚。
- `test_two_encounter_state.gd`：两次真实 `BattleModel` 入场、`USE_ITEM` 消耗、装备防篡改、首次奖励、跨章继承。
- 旧 `test_demo_flow.gd`、六人战斗与全部武学/角色/装备 CI 必须继续通过。
- 导出包需要包含章节索引、章节 JSON、信使角色定义及第二章剧情 JSON。

正式人工验收：从标题新游戏进入第一幕 → 首战胜利 → 结算“进入下一幕” → 第二幕探索与信使分支 → 第二战 → 结算药囊数量，返回主菜单后重新开始不继承旧游玩物品。
