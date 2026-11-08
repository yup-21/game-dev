# 序章 V2：荒庙偶遇 · 雨夜残镖（正式可玩入口）

本页记录现有序章的**玩法流程**；新增对白、分支或新章节的唯一制作说明见 [原生 Resource 制作指南](../../../docs/changfeng-native-authoring.md) 和 [章节指南](CHAPTER_AUTHORING_GUIDE.md)。

## 正式入口

项目默认场景是 `opening.tscn`。主菜单「初入江湖」先 `GameSession.start_new_game()`，再 `activate_prologue_chase()`，进入可编辑的 `scenes/prologue/prologue_exploration.tscn`。先在殿内篝火旁获得控制权，自由经过前院、官道，调查劫镖现场，再决定是否救下严守诚。独立「进入战斗 · HD-2D」仍由 `GameSession.start_quick_battle()` 进入 `r40_quick_duel`。

本版正式对白使用 `data/native/stories/prologue_chase_story.tres`：分支为「救／不救（失败可重选）」，救人后在殿内包扎、庙外 **1v2**、官道 **1v3**，到断桥后严托付**无名残卷**、引开追兵，主角单独对上 **1v1 哨探**时获得原生洞察手牌能力，最后逃往平江府。韩啸不在新手流程登场。战斗均进入 `battle_hd2d.tscn` 使用唯一的 `BattleModel`。战胜后按 `Esc` 返回四区探索，战败则在结算页重试该场。

`rain_escort_prologue.tres`、原章节的 `escort_ambush` 仅保留为历史回归测试数据，**不作为正式序幕修改入口**。四区独立 QA 测试在 `GameSession.prologue_active=false` 时运行，复用同一 `.tscn`，不会污染正式剧情状态。

## 作者应如何扩展

- 更新序章对白：修改 `data/native/stories/prologue_chase_story.tres` 的 `WuxiaDialogueNodeDefinition` 子资源，并同步检查 `scripts/prologue/prologue_exploration.gd` 使用的触发 ID。
- 调整场景：在 Godot 中编辑 `scenes/prologue/zones/*.tscn` 的 `Entries/Exits/Landmarks`、`Navigation/Walkable`、美术分层；不要把位置硬编码回故事脚本。
- 调整追兵：修改三个 `data/native/encounters/prologue_*.tres`，场景阶段由 `GameSession.prologue_stage` 串联；主角初始被动必须没有洞察。
- 添加新章：复制 `data/templates/story.tres`、`chapter.tres`，如需新战斗再复制 `encounter.tres`；重命名内容 ID、重连 Story、NPC/对话 trigger 和 Encounter，加入正式 `data/content_manifest.tres`。
- 更改战斗背景：编辑注册的 `data/maps/*.tres` 与 Scene/Asset Resource；UI 和 `BattleModel` 不应加入章节专用规则。

## 验收

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_chase_flow.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_prologue_native_scenes.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_opening_story.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_chapter_pipeline.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_r40_native_entry_closure.gd
```

实际 GUI 仍需人工走图，检查护送严守诚的贴图表现、三场战斗难度、胜负切换与平江府承接；自动化 PASS 不代表正式美术或手感已验收。详见[序幕企划 V2](../../../docs/game-design/chapters/act-0-prologue-v2.md)。
