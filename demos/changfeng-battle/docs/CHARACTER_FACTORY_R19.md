# R19 — CharacterFactory 与角色卡迁移

R19 不新增 JSON 格式。沈长风的 **角色身份、初始属性、武学、立绘、行动贴图、初始背包、装备及词条** 已迁到 `data/native/characters/shen_changfeng.tres`。角色 ID `shen_changfeng`、战斗 actor ID、初始数值及对外快照格式保持不变。旧文件 `data/characters/shen_changfeng.json` 保留作历史迁移参考，但已从 `data/characters/index.json` 移除，运行时不再读取它。

## 编辑角色和进入游戏

1. 在 Godot Inspector 新建或编辑 `WuxiaCharacterDefinition`，给出稳定 `content_id`、角色属性、武学 ID、立绘与贴图 Resource。
2. 在角色卡的 `Starting Items` 列表加入 `WuxiaStartingItemDefinition` 子资源，设置物品 ID、数量、是否装备和指定词条。消耗品只需数量；装备按单件 UID 创建。
3. 将角色卡添加到 `data/content_manifest.tres` 的 `characters` 列表。无需写 JSON 或角色专用启动分支。
4. `CharacterRegistry` 在导入时验证角色 ID、武学引用、贴图与场景路径，以及整个初始装备能否按现有 Item/Affix 规则装配；无效内容不会作为合法 Catalog 对象使用。
5. `CharacterFactory.create_runtime(character_id)` 返回初始化后的 `CharacterRuntime`；角色属性和背包均为运行时私有状态。`GameSession.start_new_game()` 使用这一工厂，已移除沈长风专用药品和长剑写死逻辑。

示例：
```gdscript
const Factory = preload("res://scripts/character_factory.gd")
var factory = Factory.new()
var hero = factory.create_runtime("shen_changfeng")
if hero != null:
    print(hero.inventory.snapshot())
```

`CharacterFactory.presentation_assets(character_id)` 解析角色卡关联的 `Texture2D` 和可选 `PackedScene`。若角色卡配置了 `battle_scene`，`instantiate_presentation()` 返回独立 `Node2D` 实例；否则返回 `null`，原有 HD2D 角色表现层继续提供兼容后备。该工厂不控制战斗规则、CTB 或动画时间。

## 安全契约

- `CharacterLoadout.apply()` 在临时库存上构建全部条目，最后一次性提交；无效物品、词条、数量及重复装备槽均不会留下半套库存或消耗 UID。
- 已存在的角色在剧情切换、两场战斗之间复用原 `CharacterRuntime`；不会重播初始配置。
- 进行故事奖励、连续战斗回写、存档恢复时，运行时快照依旧是唯一的可变状态来源；初始配置仅在创建全新角色时执行。
- `CharacterRegistry` 使用默认内容索引时附加正式原生 Manifest；测试所用自定义 JSON 目录保持独立，避免意外混入主角。
- `data/native_examples.tres` 的游侠角色额外绑定了一个可实例化的 preview PackedScene，用于验证场景链接；它不是正式战斗角色动画替代品。
- 仍有其他七份旧角色 JSON 尚待迁移。彻底移除旧读取路径、通用动画 `SpriteFrames` 和地图生成器不属于当前改动。

## 回归验收

运行 `checks/test_character_factory.gd`、`test_native_content_resources.gd`、`test_character_dynamic_identity.gd`、`test_two_encounter_state.gd`、`test_chapter_pipeline.gd`，并运行全量 HUD / export GitHub Actions。

**下一步**：批量迁移剩余角色；R20 再建立可组合的 Skill/Effect/Condition Resource 和注册式 Handler。
