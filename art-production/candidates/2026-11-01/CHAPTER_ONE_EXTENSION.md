# 第一幕与六人战斗美术扩展 · 2026-11-01

- 前置分支：#82 首批样板；#83 候选运行时试玩接线。本批新分支基于 #83，不覆盖原有正式角色。
- 新增：顾清霜、青衫客、黑衣刀客、夜行刺客四套**透明立绘候选与 24 姿势源稿**，受伤老镖头立绘及坐姿、荒道破庙场景母版，共 11 张源 PNG。
- 本批图片均处于 `concept / needs cleanup`，**不等于批准的动作图集与分层场景**。源图规格及缺陷详见审核记录。
- `art-production/tools/prepare_chapter_one_assets.py`：本地图像 Alpha/Atlas 审计和破庙四层确定性切分，默认不写，`--write` 只输出缺失层。
- 初始来源/描述：`CHAPTER_ONE_PROMPTS.md`；逐图 SHA-1 Blob 和预期尺寸：`CHAPTER_ONE_MANIFEST.json`；SHA-256 可由审计脚本实时输出。
- 第一幕 Godot 原生章节不改：`rain_escort_prologue.tres`，`escort_ambush.tres`；原生 `.tres` 继续唯一运行时内容入口。

## 距离正式交付的门槛

1. 每名战斗角色身份板/四方向、武器不裁切、24 帧纯净透明、同脚点，输出规范化 RGBA Atlas，动画与动作时间轴吻合。
2. 破庙四层 PNG 实际生成并入库，与现有 `ChapterSceneDefinition` 的剧情层和地图碰撞对齐；前景遮挡截图通过。
3. 导入 Godot preview，再在**单独审核分支**接角色卡、头像 Registry、动画 Profile 与场景；检查实时不再取旧缓存。
4. CI+Godot GUI 1600×1000、1440×900 视觉验收、商用权属与负责人批准。未完成前不进入 `approved`。
