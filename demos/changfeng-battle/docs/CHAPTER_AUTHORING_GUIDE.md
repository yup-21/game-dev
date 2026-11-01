# 章节、剧情事件与连续战斗制作指南

通用 Resource 创建、Manifest 注册及校验步骤以 [唯一正式内容制作指南](../../../docs/changfeng-native-authoring.md) 为准。本文件专门说明**已有双章节游戏会话的行为边界**，不另建章节索引。

## 接入一章剧情

1. 在 `data/native/stories/` 创建 `WuxiaStoryDefinition`；对白由 `WuxiaDialogueNodeDefinition`、`WuxiaDialogueChoiceDefinition` 和 `WuxiaStoryEventDefinition` 组合，条件由 `WuxiaFlagRequirementDefinition` 表示。
2. 在 `data/native/encounters/` 创建 `WuxiaEncounterDefinition`，引用已经登记的角色和地图。为两方配置唯一 actor ID、`team_id`、`controller` 与合法地图脚点。
3. 在 `data/native/chapters/` 创建 `WuxiaChapterDefinition`，引用 Story 与 `encounter_id`，嵌入 `WuxiaChapterSceneDefinition`（背景、NPC、主角起点和行动范围），并配置 `chapter_order`、`next_chapter_id`、战斗门槛与胜败事件。
4. 将三个文件分别登记到 `data/content_manifest.tres` 的 `stories`、`encounters`、`chapters`；原生 `ChapterCatalog` 会核对 Story、角色、地图与 Encounter 引用。`GameSession.start_new_game()` 从最小 `chapter_order` 开始；也可在测试中指定 `entry_chapter_id`。

现有正式章节是 `rain_escort_prologue.tres` 与 `river_watch.tres`，后者引用独立的信使 NPC、剧情和六人遭遇；增加下一章只需要资源和必要美术，不需要在 `GameSession` 写新分支。

## 对话与事件

`OpeningStory` 将当前对白节点的事件交给 `GameSession.apply_story_events()`；`StoryEventExecutor` 校验后原子提交：

| 事件类型 | 效果 |
| --- | --- |
| `set_flag` | 设置布尔剧情标志 |
| `grant_clue` | 增加剧情线索 |
| `grant_item` | 发放已注册物品到指定角色背包 |
| `recruit_character` | 招募已注册角色 |
| `learn_school` / `switch_school` | 学习或切换已注册门派 |
| `set_attribute` / `set_growth` | 设置属性或永久成长来源 |

选项的 `requires`、章节的 `requirements` 都使用 `WuxiaFlagRequirementDefinition`。事件先在角色副本中整体校验，任何一项失败都不会部分修改 flags、背包、装备和成长。`StoryEventExecutor` 不允许直接修改战斗 HP、CTB 或手牌。`return_to_explore` 的 Story 必须配置可以满足的完成条件。

## 两场战斗如何共享角色

- `GameSession.start_new_game()` 创建常驻 `CharacterRuntime`，初始物品来自 `WuxiaCharacterDefinition.starting_items`。
- `GameSession.encounter_options()` 将角色 `battle_build()` 与 `ScenarioDirector` 的 encounter 定义结合，创建本场 `BattleModel`。
- `BattleModel` 只操作本场的背包副本；通过经过校验的 `inventory_snapshot()` 提交战斗消耗，结算后同步常驻角色。角色装备 UID、词条及成长不允许通过伪造的战斗快照篡改。
- `advance_chapter()` 保留物品、装备、已学门派、成长和剧情标志；首次胜利奖励只发一次。HP、临时 Buff、当前手牌不跨战斗继承。

当前 Demo 尚未提供跨程序重启的磁盘存档。章节背景、动画、真实人物脚点及授权仍需 Godot GUI 人工验收。

## 回归

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_chapter_pipeline.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_two_encounter_state.gd
```

完整人工路线：新游戏 → 第一幕 NPC 对话 → 3v3 → 胜利结算 → 第二幕信使 → 3v3 → 物品/装备/奖励确认。不能用 headless PASS 代替人工试玩。
