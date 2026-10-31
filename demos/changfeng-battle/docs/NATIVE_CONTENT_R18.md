# R18 — Godot 原生 Resource 内容管线（第一阶段）

本项目从 R18 开始，**新增内容只使用 Godot 原生 Resource（`.tres`）制作**。JSON 不再是新内容的编辑格式，亦不建设 JSON → Resource 转换器。R1–R17 的旧 JSON 资产仍需保持可读，迁移完毕后按独立 PR 逐类移除，避免同时破坏剧情、战斗、测试和存档快照。

## 目前已落地

| 领域 | 新原生定义 | 保留的运行时校验 |
| --- | --- | --- |
| 角色 | `WuxiaCharacterDefinition` | `CharacterRegistry._valid()`、武学引用检查 |
| Buff | `WuxiaBuffDefinition` | `StatusCatalog._valid()`、Modifier 规范 |
| 物品 | `WuxiaItemDefinition` | `ItemCatalog._valid()`、装备词条约束 |
| 原生索引 | `WuxiaContentManifest` | `ContentRegistry` 统一 ID、版本、类型与重复检查 |

每一份 `.tres` 是只读定义，不存 HP、武学进阶等级、Buff 计时或装备 UID 的可变实例。运行时通过现有 Catalog 获取**深拷贝 Dictionary**，继续交给 CharacterRuntime、InventoryRuntime 和 BattleModel 等已验证模块。接入层为过渡 Adapter，最终将逐步直接消费带类型的 Resource。

`res://data/content_manifest.tres` 是正式入口。R19 已将沈长风角色卡迁入正式 Manifest，并从旧角色 JSON 索引中移除同名条目；`res://data/native_examples.tres` 仍提供原生资源扩展示例，用于验证新增角色、Buff 和物品的独立加载。

## 在 Godot Inspector 中制作新内容

1. 打开 `demos/changfeng-battle/project.godot`，在 FileSystem 中右键 `data/native` 相应目录，选择 **New Resource**。
2. 搜索 `WuxiaCharacterDefinition`、`WuxiaBuffDefinition` 或 `WuxiaItemDefinition`；设置稳定的 `content_id`、`schema_version=1` 和领域字段。
3. 立绘、动作贴图通过 Godot 的资源槽直接拖入，形成被导出系统识别的资源依赖；角色通过 `school_id` 绑定已有武学。资源 ID 使用小写字母、数字、下划线、点和连字符，开头/结尾不得为点。
4. 在 `data/content_manifest.tres` 的对应列表添加资源文件引用。**无需编辑任何 JSON、扫描文件夹或写新的代码。**
5. 运行 `godot --headless --path demos/changfeng-battle --editor --import --quit`，然后运行 `godot --headless --path demos/changfeng-battle --script res://checks/test_native_content_resources.gd`。遇到重复 ID、错误类型、缺失资源或不合法字段，必须修正后才能合入。

提供的 `native_examples.tres` 可以从 Inspector 查看实际配置；它引用：

- `data/native/characters/guest_swordsman.tres`（新侠客 + Godot Texture2D 立绘）
- `data/native/buffs/steady_breath.tres`（限时属性修正）
- `data/native/items/field_medicine.tres`（战斗药品）

## 契约与局限

- Manifest 显式引用资源，既可在 Godot Inspector 中编辑，又避免运行时不可靠的目录扫描；不要将项目外文件系统路径写进 `.tres`。
- 当前 Registry 对新内容实行全部校验后提交；同一 Manifest 的 ID 全局唯一。与旧 JSON 同名的资源会被拒绝，不允许偷偷覆盖已经发布的定义。
- 技能/武学、剧情/任务、地图和美术自动装配尚未迁入原生 Resource；它们应在 R19–R23 中逐类建立专属类型和 Validator，不能把多种业务字段堆进统一 Dictionary 后冒充完成迁移。
- 当前角色美术 Resource 使用强类型 `Texture2D`；`battle_scene` 为未来 CharacterFactory 预留的 `PackedScene`，尚未接线。动画格式规范、自动切帧和地图编辑器均不属于 R18 本轮完成范围。
- 导出包中的原生资源通过 Manifest 引用可被 Godot 跟踪；继续保留旧 JSON 动态加载时，仍须遵循旧版导出包含规则。
- 如果 Godot 校验失败，保留在功能分支并修复，严禁用跳过检查替代正确实现。

**R19 进度**：已通过 `CharacterFactory` 从角色 Resource 生成 `CharacterRuntime`，并迁入沈长风的角色卡及初始装备；R20 将武学/技能效果拆成可组合 Resource + Handler；后续才处理剧情、地图及素材编辑工具。旧数据删除须在替代资源与全套回归均通过后单独进行。
