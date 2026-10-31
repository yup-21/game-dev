# R40 · 正式 Demo 入口收口与废弃实现清理

## 审计基线

PR #68 的 `feature/r18-native-resource-content` 分支。正式启动 `project.godot` → `opening.tscn`；唯一战斗 `battle_hd2d.tscn`，唯一战斗规则权威 `BattleModel`。这不是并行新引擎，也没有恢复旧美术、旧 UI、3D 拼接地形或第二套卡牌结算。

## 已实际修改

- 主菜单快捷战斗由原生 `data/native/encounters/r40_quick_duel.tres` 注册。正式/快捷入口都从 `GameSession` 经 `ScenarioDirector.battle_options()` 与 `CharacterRegistry` 生成；使用 `CharacterFactory` 对角色卡内的初始药品、装备与成长负载进行原子创建。直接实例化战斗场景的测试也读取同一个原生遭遇，杜绝另一套手工双人配置。
- `ScenarioDirector` 对 `map_id` 查询 ContentRegistry 原生地图 Resource；全部已注册遭遇均携带实际地图 Resource 引用，失败时直接返回无效而不拼接 JSON 路径。`MapBake.DEFAULT_PATH` 已切为原生 `rainy_bridge.tres`。
- `SchoolCatalog`、`CardSystem`、`TechniqueRuntime` 的默认数据入口为原生 Resource/Manifest。40 项旧武学 ID 对照只在主动运行 `LegacySkillAdapter` 时做合法性校验，不阻碍正式游戏启动。
- `BattleSpatialService` 持有唯一的连续空间碰撞、`find_path`、`trim_path`、`find_attack_approach`，删除 `battle_spatial_waypoint.gd` 和旧 waypoint 分派分支，历史空间测试改为验证统一实现及角色占位/净空半径。
- `OpeningRoleSprite` 不再手动写 `frame_coords`，使用 `NativeSpriteAnimation` (`AnimationPlayer` + `AnimationLibrary`) 驱动动作；静态 NPC 仍原画展示。
- 删除无生产用途的 `ACTIVE_BATTLE_SCENE` 重复常量，所有 UI 跳转通过 SceneRouter，保留唯一正式场景。
- `export_presets.cfg` 排除所有 `.json`，并用外部 PCK 运行 `checks/test_export_resources.gd` 明确验证**旧 JSON 不存在、原生目录均存在、快捷/剧情遭遇均可解析为 .tres**。

## 删除与保留

真正删除的旧实现：`battle_spatial_waypoint.gd`、历史 `battle.tscn/party_battle.tscn` 与专用 View、`WuxiaDataDocument` 及旧 `data/native/documents/`、历史 3D/重复表现脚本。项目源码仍保留用于差异比对的历史 JSON 和显式测试 JSON 参数处理：这些是**工程测试输入**，不属于正式内容、未被默认玩家入口调用、不会打入发布包，不应随意删除导致迁移验收失去可核查基线。原生 LegacySkillAdapter 只承担用户主动触发的旧配置转换，未被战斗规则动态调用。

## CI 证据

Godot 4.7.2，提交 `f297743`：

- [Modular Wuxia content contracts](https://github.com/yup-21/game-dev/actions/runs/41225015657) — PASS，`R40_NATIVE_ENTRY_PASS failures=0`，原版 R11–R39 内容、装备、剧情及坏输入测试回归通过。
- [Original Wuxia HUD regression](https://github.com/yup-21/game-dev/actions/runs/41225015761) — PASS，UI、FREE/GRID 空间、剧情及视觉截图三个作业均通过。
- [Portable Changfeng demo export](https://github.com/yup-21/game-dev/actions/runs/41225015754) — PASS，发布包以 `--main-pack` 在检出目录外启动，日志 `EXPORT_RESOURCE_PASS failures=0`。

## 尚需人工验收

Godot 4.7.2 Editor 实际编辑/保存 Resource、场景遮挡与动作质量、两种移动模式手动试玩、Windows/Linux 桌面真机运行、原画授权与商用许可。自动回归合格并非这些事项的完成证明；PR #68 继续保持 Draft，不自动合并主分支。
