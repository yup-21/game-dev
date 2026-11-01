# 长风战斗 Demo · 唯一正式内容制作指南

本指南是项目**当前唯一的内容注册流程**。打开 Godot 4 项目 `demos/changfeng-battle/project.godot`，使用 Inspector 编辑或复制 `.tres` Resource；正式内容由 `res://data/content_manifest.tres` 显式引用。角色、门派、招式、章节、剧情、遭遇、Buff、物品均不通过 JSON/目录扫描加载。历史 R18–R41 文档只用于查阅迁移过程，不是制作步骤。

## 通用步骤

1. 在 `data/native/<领域>/` 中复制现有同类 `.tres`，或用 Inspector 的 **New Resource** 新建对应 `Wuxia*Definition`。为每个 Resource 设置唯一的小写 `content_id`，不要复用其他类别的 ID。
2. 在 Inspector 中设置强类型子资源、资源引用、文字与数值。`.tres` 的 `[sub_resource]` 属于该资源内部，无须额外注册；跨文件的 `[ext_resource]` 路径必须实际存在。
3. 打开 `data/content_manifest.tres`，把完整资源加入**匹配的数组**（`characters` / `schools` / `skills` / `techniques` / `chapters` / `stories` / `encounters` / `items` / `buffs` / `affixes` / `maps` 等）。只复制文件而不注册，运行时**不会发现**新内容。
4. 在 Godot Editor 保存，然后运行现有验证命令。新增可玩角色/章节/战场需要从现有 `GameSession` / `ScenarioDirector` 入口进入，不能在 HUD、`BattleModel`、`CombatResolver` 中新增内容专用分支。

请先完成资源的引用闭包，再注册到正式 Manifest；如校验失败，查看对应 `ContentRegistry`、`CharacterRegistry`、`SchoolCatalog` 或 `ChapterCatalog` 的 `load_error`，不要绕开校验。

## 角色（`WuxiaCharacterDefinition`）

保存到 `data/native/characters/<id>.tres`，设置 `display_name`、`school_id`、`learned_schools`、`attributes` 四维（`STR/AGI/CON/MND`）、`passives` 和需要的 `starting_items`。初始装备子资源类型为 `WuxiaStartingItemDefinition`，`item_id` 必须是已注册物品，词条必须匹配装备槽。一个场景内的角色身份由 `character_id` 指定；`battle_actor_id=-1` 表示不预留默认战斗 actor 槽位，剧情、招募后仍可在遭遇中使用。

`portrait`、`sprite_sheet` 使用 Godot 导入的 `Texture2D`，推荐角色图集 6 列 × 4 行；正式资源缺失时使用独立 fallback，不能因此将候选美术自动标记为批准。添加角色后，`CharacterFactory` 创建 `CharacterRuntime`；不需要修改 `CharacterRegistry` 或 `GameSession`。参照 `data/native/characters/r24_lan_chen.tres`。

## 武学（`WuxiaSchoolDefinition` + `WuxiaSkillDefinition`）

新增一个门派至少要准备 **2 张非生成型核心招式**，分别在 `data/native/skills/` 中使用 `WuxiaSkillDefinition` 定义，令各自 `school_id` 等于门派 `content_id`，并设置 `generated_only=false`。每张招式至少有一个 `WuxiaSkillUsageDefinition`：设置出招时机 `timing`、合法目标 `target_kind`、距离、内息消耗及 `WuxiaEffectDefinition` 效果子资源。

在 `data/native/schools/<id>.tres` 创建 `WuxiaSchoolDefinition`，把两张招式放进 `core_forms`，通过 `WuxiaSchoolDeckEntryDefinition` 配置共 **12 张**起始牌（示例各 6 张）；`deck` 只能包含两张核心式，不能直接发放 `generated_only` 派生牌。把 School 与 Skill **分别**加入 Manifest 的 `schools` 和 `skills` 数组。若使用额外阶段技法，再用 `WuxiaTechniqueDefinition` 和 `techniques` 注册，无需在 `BattleModel` 添加分支。参照 `data/native/schools/r24_mist_sword.tres` 及 `data/native/skills/r24_mist_veil.tres`、`r24_mist_cut.tres`。

派生牌、连携和自定义效果必须满足既有校验；仅复制两张招式就可以形成一套基础可用的门派卡组，复杂衍生能力是可选扩展，不是新门派的前置条件。

## 章节与遭遇（`WuxiaStoryDefinition` / `WuxiaChapterDefinition`）

一个可进入的章节需要**剧情 Resource、遭遇 Resource、章节 Resource**：

1. `data/native/stories/<story_id>.tres`：用 `WuxiaStoryDefinition` 配置 `entry_node`、`WuxiaDialogueNodeDefinition`、镜头节点与可选事件。`return_to_explore=true` 时必须设置完成条件，否则校验失败。
2. `data/native/encounters/<encounter_id>.tres`：用 `WuxiaEncounterDefinition`、`WuxiaEncounterCombatantDefinition` 配置至少两名、最多八名角色；`character_id` 指向已注册角色，`display_name` 必须与角色卡姓名一致；地图使用已注册的 `map_id` 或 `data/maps/` 下的 `map_resource`。`actor_id` 是本场实例 ID，与角色永久身份无关。
3. `data/native/chapters/<chapter_id>.tres`：用 `WuxiaChapterDefinition` 引用保存后的 Story、Encounter ID 和 `WuxiaChapterSceneDefinition`（背景 `Texture2D`、NPC、可行走边界、探索起点等），设置 `chapter_order`、`next_chapter_id` 与可选 `requirements`、`victory_events`。
4. 在 Manifest 中登记 Story、Encounter 和 Chapter；新章节由 `ChapterCatalog` 排序/按 `next_chapter_id` 衔接，不需要为每章增加脚本。预览独立章节可用 `GameSession.start_new_game(entry_chapter_id)`。

参照 `data/native/stories/r24_fog_pass.tres`、`data/native/encounters/r24_fog_pass_battle.tres`、`data/native/chapters/r24_fog_pass.tres`。更多跨战斗背包和奖励行为见 [章节与连续战斗说明](../demos/changfeng-battle/docs/CHAPTER_AUTHORING_GUIDE.md)。

## 物品、装备、Buff 和词条

- `WuxiaItemDefinition`：放入 `data/native/items/`，配置 `kind=consumable`（`effects`，例如 `heal_hp` / `gain_qi`）或 `kind=equipment`（`slot`、`modifiers`、`affix_pool`、`max_affixes`）。登记到 `items`。
- `WuxiaAffixDefinition`：放入 `data/native/affixes/`，配置 `allowed_slots` / `modifiers`，登记到 `affixes`。
- `WuxiaBuffDefinition`：放入 `data/native/buffs/`，设置叠层上限、`expiry_kind`（`permanent` 或 `global_ticks_after_apply`）、可选持续时间及属性修正，登记到 `buffs`。

同类资源示例分别见 `river_sword.tres`、`healing_powder.tres`、`iron_body.tres` 和 `keen_edge.tres`。`InventoryRuntime` 和 `StatusSystem` 负责运行时状态，不把物品数量、装备 UID 或 Buff 剩余时间写回定义。

## 地图、表现及素材权属

地图使用原生 `WuxiaGridMapDefinition` / `WuxiaMapDefinition`，通过 Godot 的多边形地图画笔编辑边界、障碍和标记；保存到 `data/maps/` 并加入 `content_manifest.tres.maps`，遭遇按已注册地图引用。角色纹理、场景与 VFX 可通过 `WuxiaAssetDefinition` 登记；美术 `candidate / approved` 状态与版权依据必须单独审核。`assets/production_manifest.json` 只保存离线素材来源/审核信息，**不是**可加载的游戏内容配置，也不会进入发行包。

## 验证与人工验收

在仓库根目录运行（使用项目 CI 验证的 Godot 4.7.2）：

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_native_content_resources.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_character_factory.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_r25_native_documents.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_r40_native_entry_closure.gd
```

完整合入须通过 GitHub Actions 的 `Modular Wuxia content contracts`、`Original Wuxia HUD regression`、`Portable Changfeng demo export`；此外在 Godot Editor 实际编辑保存、运行剧情与 1v1/3v3、验证 GRID/FREE、检查导出包，人工确认素材来源和授权。自动测试不替代这些检查。
