# Godot 原生内容模板（仅编辑器示例）

本目录的所有文件都是可用的 Godot `.tres` Resource，不是游戏自动加载的正式内容。**默认 `data/content_manifest.tres` 不引用这些模板**；`template_manifest.tres` 只用来独立校验，不能替换正式 Manifest。

复制时必须在 Godot Inspector 中检查并保存资源路径，不要只修改文件名而忘记内部 `content_id` 和跨资源引用。

## 1. 复制新角色

将 `character.tres` 复制到 `data/native/characters/<new_id>.tres`，在 Inspector 修改：

- `content_id`（全局唯一小写 ID）、`display_name`、身份、性格、`attributes`、`team_hint`。
- `school_id` / `learned_schools` 指向已注册门派；默认使用 `wind_sword`，后续可以换成新门派。
- 按需编辑 `WuxiaStartingItemDefinition`，只引用正式 Manifest 已登记的物品。新角色默认 `battle_actor_id=-1`，遭遇时再指定 actor ID。
- `portrait` / `sprite_sheet` 目前是中性 fallback，只用于检查接入，不代表已完成正式美术或版权审核。

如有正式逐帧动作素材，复制本目录 `actor_animation_profile.tres`，在 Inspector 替换为原创 Atlas 并调整每个动作的绝对帧号、循环速度、脚点与朝向；再把该 `.tres` 挂到角色的 `animation_profile`。不要将本模板的 fallback 占位帧标为正式动画。该资源不需要写入 Content Manifest。

把新角色加入 `data/content_manifest.tres.characters`。创建永久游戏会话角色的逻辑由现有 `CharacterFactory` 完成。

场景分层：新地图可新建 `WuxiaSceneArtProfile`，配齐统一尺寸的 `background`、`ground`，按需加入 `foreground` 与 `weather`，在地图原生资源 `scene_art` 中引用。不得用贴图颜色反推出碰撞或改动地图脚点。

## 2. 复制一套武学

同时复制 `skill_a.tres`、`skill_b.tres`、`school.tres` 到 `data/native/skills/` 和 `data/native/schools/`。

1. 三个 Resource 分别设置不同的全局唯一 `content_id`；两张 Skill 的 `school_id` 均改为新的 School ID。
2. **在新 School 的 Inspector 中重新绑定复制后的两张 Skill**：更新 `core_forms` 和两条 `deck[].card`。复制文件时旧外部资源引用不会自动指向新文件。
3. 保持两张核心式均 `generated_only=false`；默认起始牌为 `6+6=12`。编辑 Usage 的目标、费用和 `WuxiaEffectDefinition` 子资源即可修改基础招式。
4. 将 School 及两张 Skill 分别加入正式 Manifest 的 `schools` 与 `skills`，再用角色卡的 `school_id` / `learned_schools` 使用该门派。

不需要修改 `CardSystem`、`SchoolCatalog` 或战斗规则核心。派生招式、技法和连携可后续追加到既有原生定义，不是基础卡组的必要条件。

## 3. 复制新章节

同时复制 `story.tres`、`chapter.tres`；如果需要独立新战斗，也复制 `encounter.tres`，保存到 `data/native/stories/`、`chapters/`、`encounters/`。

1. 更新 Story / Chapter / Encounter 的 `content_id`。在 Chapter Inspector 中**把 `story` 重连到新 Story 文件**。
2. 修改 `WuxiaDialogueNodeDefinition.node_id`、`entry_node`、场景 NPC `trigger_id`，让对话入口一致；修改事件与章节门槛的 flag ID，防止多个章节复用同一个 `template_met_npc`。
3. Chapter 默认引用已注册的 `r40_quick_duel` 遭遇，复制 Story + Chapter 后即可单独验证。如果复制了 `encounter.tres`，将 Chapter 的 `encounter_id` 改为新 Encounter ID，并在 Encounter 中设置已注册的 `character_id`、与角色卡完全一致的 `display_name`、队伍和合法地图站位。
4. 修改背景（当前是中性 fallback）、探索起点和 NPC 位置，设置 `chapter_order` 与 `next_chapter_id`。将 Story、Chapter、可选 Encounter 分别登记到正式 Manifest；无须新增 `GameSession` 分支。

新章节不自动变成主线第一章；由 `chapter_order` 决定初始章节，`next_chapter_id` 控制故事衔接。需要单独启动时可由 `GameSession.start_new_game(entry_chapter_id)` 指定。

## 4. 复制新物品

把 `item.tres` 复制到 `data/native/items/<new_id>.tres`，设置 `content_id`、名称、`kind`、堆叠上限及效果。默认是回复 2 点 Qi 的消耗品；需要装备时在 Inspector 将 `kind` 改为 `equipment`，填写 `slot`、`modifiers`，可选绑定已注册的 `WuxiaAffixDefinition`。然后加入正式 Manifest 的 `items`。

如果要给角色作为开局物品，先确保该物品已注册，再在角色卡 `starting_items` 中引用物品 ID。

## 验收

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_content_templates.gd
```

该检查会使用独立 `template_manifest.tres` 验证模板可加载、两张核心式和 12 张牌、角色/物品目录、章节与场景引用、遭遇地图及实际卡牌注册，且模板**不会污染正式游戏资源**。复制后的内容必须加入正式 Manifest，随后运行既有 Modular / HUD / Export CI 并在 Godot Editor 中实际试玩。

总纲：[正式内容制作指南](../../../../docs/changfeng-native-authoring.md)。
