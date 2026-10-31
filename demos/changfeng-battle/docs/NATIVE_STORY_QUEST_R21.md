# R21 — 原生剧情图、章节、任务与遭遇 Resource

R21 继续 R18–R20 的显式 Manifest 方式，不创建新 JSON。旧 `data/chapters/*.json`、`opening_story.json` 和 `demo_scenario.json` 仍可读取，现有序章及第二幕入口保持不变。

## Inspector 制作链路

1. 用 `WuxiaStoryDefinition` 组织剧情镜头 `WuxiaStoryBeatDefinition`、对话 `WuxiaDialogueNodeDefinition` 和选项 `WuxiaDialogueChoiceDefinition`。事件通过 `WuxiaStoryEventDefinition`，条件通过 `WuxiaFlagRequirementDefinition` 引用；无需编写 JSON 字符串。
2. 用 `WuxiaChapterNpcDefinition` 配置 NPC 的人物 ID、脚点、交谈标签和触发 ID；`WuxiaChapterSceneDefinition` 引用场景 Texture2D、主人物、额外 NPC、探索范围和全部界面文案。
3. `WuxiaChapterDefinition` 引用单独保存的剧情 `.tres`、场景资源、遭遇 ID、下一章 ID、入场条件与胜负事务奖励。
4. `WuxiaEncounterDefinition` 引用 `WuxiaEncounterCombatantDefinition`：角色稳定 ID、队伍、位置、操控方。通过现有 `ScenarioDirector.battle_options()` 交给 BattleModel，不复制战斗规则。
5. `WuxiaQuestDefinition` 由多个 `WuxiaQuestObjectiveDefinition` 构成；目标可检查 flag、线索数量或已清除遭遇。任务进度始终由 `GameSession` 已提交的 `flags/items/cleared_encounters` 投影，不另存可失真的可变计数。
6. 将故事、章节、任务、遭遇显式加入 `data/content_manifest.tres`；新章节可通过 `GameSession.start_new_game("章节 ID")` 进入，默认新游戏仍从旧第一幕开始。

示例内容位于 `data/native/stories/r21_crossroads.tres`、`chapters/r21_crossroads.tres`、`quests/r21_find_the_path.tres` 和 `encounters/r21_gate_ambush.tres`。一个章节包含两个独立 NPC 配置；三个任务目标依次验证交谈标志、地图线索和战斗胜利。

## 边界和验证

- `StoryRuntime` 按稳定 ID 取得 `OpeningStory` 实例，后者继续处理对话、条件选项与一次性事件送达。
- `StoryEventExecutor.prepare` 仍负责原子验证/回滚；任务不直接改动 `BattleState`、HP、CTB 或卡牌。
- 原生内容跨类型 ID 唯一；剧情文件的 ID 与章节 ID 分开，用章节的 `story_id` 做显式引用。自定义旧索引/场景 fixture 不会被默认 Manifest 污染。
- `ChapterCatalog` 会验证两个 NPC 的角色引用、位置、重复 ID 与资料；R21 首批先让运行态认识多 NPC 数据，探索界面的多 NPC 实际显示和多触发点交互将在 R24 之前补齐。
- R21 的示例遭遇使用既有格子/地图；无网格地图编辑器与自定义美术装配分别属于 R23 和 R22。

运行 `checks/test_native_story_quests.gd`、`checks/test_chapter_pipeline.gd`，并执行 R11–R20、HUD、导出全量回归。
