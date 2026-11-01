# 第一幕与六人战斗美术扩展 · 2026-11-01

**Draft PR #85，审核分支：`art/chapter-one-candidates-20261101`，依赖 #82 → #83。**

## 实际交付

| 对象 | 原图/母版 | 可导入产物 | Godot 审核分支接线 |
| --- | --- | --- | --- |
| 顾清霜 | 立绘 + 24 姿势源稿 | 1536×1024 归一化 Atlas | 角色卡、九动作 Profile、头像 Registry |
| 青衫客 | 同上 | 同上 | 同上 |
| 黑衣刀客 | 同上 | 同上 | 同上 |
| 夜行刺客 | 同上 | 同上 | 同上 |
| 老镖头 | 全身立绘 + 负伤坐姿 | 独立透明图片 | NPC 角色卡、静态 Pose、头像 Registry |
| 荒道破庙 | 1586×992 场景母版 | 1600×1000 四层 + 合成预览 | 原生 `WuxiaSceneArtProfile`、第一幕章节与剧情层 |

- 生成源图 11 PNG；自动衍生 9 PNG（四套 Atlas、五张场景层/预览）；Godot 导入区 15 个逐字节副本，已同步 `art-production/in-use` 及 SHA-256 清单。
- 来源提示词：`CHAPTER_ONE_PROMPTS.md`；完整二级来源链及精确哈希：`CHAPTER_ONE_MANIFEST.json`。
- 可重复准备脚本：`art-production/tools/prepare_chapter_one_assets.py`，默认只审计，`--write` 仅写入缺失项，覆盖需要显式 `--replace`。
- Godot 仍仅用原生 `.tres` 作为角色、动作、章节和场景数据入口；没有新增 JSON 游戏运行时或角色硬编码。
- 章剧情与六人 `escort_ambush` 的规则不变。新增的多层剧情渲染在探索阶段启用可遮挡前景、独立可关天气，并避开上/下 HUD。

## 机器验证与审核状态

候选源图的尺寸、RGBA、24 格基础动作映射、归一化安全边距与脚点、分层合成一致性、原生 Resource 加载和剧情/战斗入口均安排 CI 验证。具体检查记录见 `art-production/reviews/2026-11-01-chapter-one-extension.md`。

**状态：`candidate / owner_review_required`。** 技术预检通过不代表艺术品质批准，尤其以下事项仍待负责人现场验收：

- 身份设定四视图及旧美术风格一致性；刀剑尖、袖针、技能特效每帧完整度与相邻帧连贯性；
- 目前均为单方向三分之四视图，真实前/后/左/右方向还未补齐；
- 第一幕角色实际站位、镖车附近路径、前景遮挡、两种分辨率 GUI 截图、六人战的多次人工游玩；
- 商业授权与近似风险确认。

**本 PR 不合入 main，直到批准签名。**
