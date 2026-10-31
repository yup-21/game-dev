# 长风战斗 Demo：Godot 原生内容制作流程（R18–R27）

本分支正式内容使用 `.tres`、`.tscn`、Godot 导入的贴图/音频；**新内容不需要也不应创建 JSON 文件**。旧 `data/*.json` 只用于回归对照与自定义旧格式测试，正式目录已经由 `data/content_manifest.tres` 统一引用。

## 添加角色、门派、装备与状态

1. 在 Godot Inspector 中新建对应 Resource：`WuxiaCharacterDefinition`、`WuxiaSchoolDefinition`、`WuxiaSkillDefinition`、`WuxiaTechniqueDefinition`、`WuxiaItemDefinition`、`WuxiaBuffDefinition` 或 `WuxiaAffixDefinition`。
2. 保存到 `demos/changfeng-battle/data/native/` 下的领域目录，配置唯一 `content_id`；把新资源拖入 `data/content_manifest.tres` 中相应的数组。
3. 门派卡牌的核心招式、派生招式、卡组、技法节点由 Resource 相互引用；入队角色的 `learned_schools` 与开局装备由角色资源定义。
4. R39 起动作时间轴、技法、遭遇、GRID 地图、十套武学与听风卡牌、旧技能 ID 适配全部是 Inspector 可编辑的原生 Resource。原来的 `data/native/documents/` 通用数据容器已清空并删除；历史 JSON 仅作回归 fixture，不再由生产默认读取。

## 剧情、招募与战斗衔接

1. 创建 `WuxiaStoryDefinition` 及其节点、选项、事件与条件 Resource，再创建 `WuxiaChapterDefinition`、`WuxiaChapterSceneDefinition`、`WuxiaEncounterDefinition`。
2. `WuxiaStoryEventDefinition` 支持设置旗标、获得线索/物品、成长来源、**招募角色**、学习/切换门派和设置属性。多个事件会先统一验证，再整体提交；任何一项失败都不会留下半成品状态。
3. 若战斗名额须通过剧情获得，在 `WuxiaEncounterCombatantDefinition` 勾选 `recruit_at_story`，随后在对应 NPC 对话事件中招募相同角色。未入队前无法开启该战斗。
4. 参照 `r26_recruitment_trial` 三张 native Resource，测试完整“NPC → 入队 → 习武 → 战斗”流程。

## 地图画笔与锚点

1. 在 Inspector 选中 `WuxiaMapDefinition`，打开右侧“武侠 · 多边形地图画笔”；选择障碍材质、点击顶点并封闭多边形。
2. “点选位置”模式可在同一坐标系放置 `spawn`、`story_trigger`、`vfx_anchor` 标记。为每个标记输入唯一、合法的英文 ID；左键放置后可撤回并保存。
3. 标记储存在同一个地图 `.tres`；运行时可通过 `MapBake.marker_position(id)` 和 `markers_of_kind(kind)` 查询。超出边界、重复 ID、放入碰撞障碍会被验证拒绝。
4. `data/maps/r24_fog_pass_map.tres` 是现成示例；无格子绘制步骤，FREE 模式使用多边形导航。

## 美术、导出和人工验收

1. 贴图、场景和音效用 `WuxiaAssetDefinition` 注册 `resource`、`asset_kind`、所属角色/事件、帧数，以及 `source` 和 `rights`。角色图集为 **6 列 × 4 行**。加入 `content_manifest.tres.assets` 后可由 `AssetRegistry` 自动解析。
2. 没有确认权属的原画保持 `status=candidate`、`rights=owner_review_required`；**禁止擅自标为 `approved`**。
3. CI 应通过 Modular、HUD（含原 Kenney 美术验证、R32 时间轴与 R39 全内容测试）和 Export 三条工作流；R31 已删除重复 Kenney 截图工作流。
4. 合并前必须在 Godot Editor 手工检查：Inspector 资源编辑/保存；地图画笔交互与坐标；剧情 UI 对话及触发范围；角色 24 姿态、方向、遮挡与特效；Windows/Linux 导出实际打开与体验；所有第三方素材的授权与来源。自动测试不代表已完成这些主观或法律审查。

## 回归命令

在 `demos/changfeng-battle` 项目目录执行（Godot 4.7.2）：

```sh
godot --headless --editor --import --quit
godot --headless --script res://checks/test_r25_native_roster.gd
godot --headless --script res://checks/test_r25_native_inventory.gd
godot --headless --script res://checks/test_r25_native_documents.gd
godot --headless --script res://checks/test_r26_story_recruitment.gd
godot --headless --script res://checks/test_r27_authoring_pipeline.gd
godot --headless --script res://checks/test_r32_native_action_timeline.gd
godot --headless --script res://checks/test_r24_content_closure.gd
godot --headless --script res://checks/test_r39_content_cleanup.gd
```
