# 序章：雨夜残镖 · 当前剧情与制作入口

本页记录现有序章的**玩法流程**；新增对白、分支或新章节的唯一制作说明见 [原生 Resource 制作指南](../../../docs/changfeng-native-authoring.md) 和 [章节指南](CHAPTER_AUTHORING_GUIDE.md)。

## 正式入口

项目默认场景是 `opening.tscn`。主菜单「初入江湖」通过 `GameSession.start_new_game()` 进入原生 `WuxiaChapterDefinition` 对应的探索剧情；「进入战斗 · HD-2D」通过 `GameSession.start_quick_battle()` 进入独立注册的 `r40_quick_duel`。无论快捷还是剧情遭遇，战斗都进入唯一的 `battle_hd2d.tscn`，规则由同一个 `BattleModel` 负责。

序章使用 `data/native/stories/rain_escort_prologue.tres` 组织镜头、对白、选项、事件和条件。探索画面由 `WuxiaChapterSceneDefinition` 指定背景、NPC、玩家起点与交互范围；主要人物使用 `Sprite2D`/`AnimationPlayer` 展现。若要更新台词，应在 Inspector 中编辑 Story 和它的 `WuxiaDialogueNodeDefinition` / `WuxiaDialogueChoiceDefinition` 子资源，而不是调整脚本中的台词分支。

## 作者应如何扩展

- 更新序章：修改 `data/native/stories/rain_escort_prologue.tres` 和 `data/native/chapters/rain_escort_prologue.tres`，保留已被 Chapter/Encounter 使用的 ID，检查 flag 和奖励引用。
- 添加新章：复制 `data/templates/story.tres`、`chapter.tres`，如需新战斗再复制 `encounter.tres`；重命名内容 ID、重连 Story、NPC/对话 trigger 和 Encounter，加入正式 `data/content_manifest.tres`。
- 更改战斗背景：编辑注册的 `data/maps/*.tres` 与 Scene/Asset Resource；UI 和 `BattleModel` 不应加入章节专用规则。

## 验收

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_opening_story.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_chapter_pipeline.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_r40_native_entry_closure.gd
```

实际 GUI 仍需手工验证序章探索、对白、NPC 触发、胜败结算和 3v3 战斗；自动化 PASS 不代表正式美术或玩法手感已验收。
