# R41 · 原生 Resource 唯一内容架构及历史兼容代码清理

## 目标

R40 已完成玩家入口、单一 BattleModel、GRID/FREE 以及表现层的迁移，R41 进一步消除**源码级**旧格式解析分支；不承诺旧未发布存档或 JSON 数据兼容。PR #68 是已合并 R40，R41 在 Draft PR #69 中审查，目标分支仍为 `refactor/battle-architecture-consolidation`，**不是 main**。

## 正式运行时

- **内容层**：`ContentRegistry` 唯一加载 `WuxiaContentManifest`，在 Godot Inspector 中引用角色、技能、Buff、装备、地图、故事、章节、遭遇、动作时间轴等强类型 `.tres`。
- **领域层**：`SchoolCatalog`、`CardSystem`、`CharacterRegistry`、`StatusCatalog`、`ItemCatalog`、`EquipmentAffixCatalog`、`ChapterCatalog`、`ScenarioDirector`、`TechniqueRuntime`、`OpeningStory`、`MapBake` 均不包含旧 JSON 文件解析支路。
- **玩法层**：`GameSession` 统一快捷战斗/剧情遭遇入口，`BattleModel` 仍是 CTB、卡牌、技法、连携及棋盘/自由移动的唯一规则真值，`BattleSpatialService` 保留唯一 FREE 几何算法；没有切回旧场景、3D 地形或老图。
- **测试层**：以 Resource Manifest、内存错误定义和真实战斗行为回归取代 JSON 字段比对。专用 `test_chain` 技法和 15×10 拓扑测试地图也作为 `.tres` fixture。无效数据测试仍然保留。

## 删除

- 删除原内容目录下旧 `data/**/*.json`（含武学、角色、章节/剧情、Buff、道具、词条、遭遇、地图和时间轴）。
- 删除 `LegacySkillAdapter`、旧 ID 映射定义类、`legacy_skill_ids.tres` 及其 Manifest 注册，删除相关兼容和迁移对照测试。
- 不影响 `assets/production_manifest.json`：它仅是开发时的**素材来源与授权核对元数据**，正式逻辑不读取，导出包继续排除 JSON；运行时快照可进行普通数据序列化，不属于旧内容加载 API。

## 自动化验证

- `test_r41_native_only.gd` 确认关键旧资源不存在、正式加载器无 `JSON.parse`、无旧映射协议、无效类型化 Manifest 原子失败、核心角色/规则/地图/遭遇资源加载正常。
- `Modular Wuxia content contracts` 测角色/技能/剧情/装备/目录与坏输入；`Original Wuxia HUD regression` 测 UI、3v3 战斗、空间路径、动画、截图；`Portable Changfeng demo export` 在检出目录外用导出的 PCK 运行核心资源加载检查。

**合并门槛**：上述三个 GitHub Actions 工作流全部成功，随后必须在 Godot Editor 手工验证资源编辑/保存与玩法手感，并对 Windows/Linux 桌面导出和素材授权做人工验收。Draft PR #69 不自动合并。

## 非目标

R41 不改变 CTB、费用、牌组、连携、角色属性、FREE 路径代价或剧情规则，也不承诺商用美术完成。Git 历史已足够追溯旧数据，不需在生产仓库保留重复 JSON。
