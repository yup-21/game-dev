# R29：原生剧情、回退美术与旧视图清理

## 当前运行入口

- `opening.tscn`：唯一剧情/主菜单入口。
- `battle_hd2d.tscn`：唯一战斗入口（GRID / FREE、多人、CTB、卡牌、连招）。
- `data/content_manifest.tres`：正式内容入口；序章和第二幕现在是强类型 `WuxiaChapterDefinition` / `WuxiaStoryDefinition`。
- `GameSession` 只记录选择历史并应用声明式事件，不解释特殊剧情 marker。
- 历史 `.json` 仅用于字段数值回归和非法输入解析测试，不参与生产默认载入。

## 删除旧视图的理由

旧 `battle.tscn`、`party_battle.tscn` 及其专用控制脚本无正式消费者。测试改为验证 `BattleModel` 与唯一 `battle_hd2d.tscn`；玩法行为契约保留，而不是维护重复 UI。

原武学定义不等于旧场景。`SchoolCatalog`、`CardSystem`、`BattleModel`、`LegacySkillAdapter` 仍有真实规则或 ID 消费者，不能直接删除。

## 专用默认素材

- `assets/fallback/default_actor_6x4.svg`：透明 6×4 角色图，1536×1024。
- `assets/fallback/default_portrait.svg`：人物头像。
- `assets/fallback/default_story_pose.svg`：剧情静态姿态。
- `assets/fallback/default_scene.svg`：中性山路场景；缺图时不挪用别的章节原画。

只有素材缺失或无法读取时才使用这些资源；有效的原生 AssetRegistry 绑定与现有原创素材保持最高优先级。

## 测试与剩余边界

- `checks/test_r29_native_cleanup.gd`：原生章节、剧情双分支、事件、战斗、默认美术和旧视图移除。
- `checks/test_demo_flow.gd`、`checks/test_opening_story.gd`：真实剧情事件到战斗的端到端合同。
- 既有 GRID/FREE、CTB、规则、截图与导出 CI 继续执行。

剩余七份 `WuxiaDataDocument` 仍涵盖武学表、听风牌、旧技能 ID、技法、遭遇、时间轴与地图 Schema。这些仍有正式规则消费者，并非死代码。其进一步强类型化需要分别实现对应 Resource 定义并核对规则 trace；不能直接删除。
