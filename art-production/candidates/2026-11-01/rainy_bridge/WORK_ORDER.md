# 雨夜断桥 · 战斗地图分层试点 WORK_ORDER

## 基本信息

- asset_id: `rainy_bridge`
- asset_type: `environment | scene_layer`
- target_usage: `battle`
- status: `concept`
- owner/reviewer: **待指派**
- source / rights: **概念生成记录、商用授权待审查**
- prompt_template_version: `ART_STYLE_AI_PROMPTS_V1`
- model/version/seed: **新一轮分层制作未开始**

## 参考与镜头锁定

- 合成构图候选：`demos/changfeng-battle/assets/concepts/2026-11-01/rainy_bridge_environment_candidate.png`，尚不能作为已批准地图。
- 当前实际背景：`demos/changfeng-battle/assets/scenes/battle/rainy_bridge_battle.webp`，源尺寸 1586×992。
- 原生网格地图：`res://data/maps/rainy_bridge.tres`，viewport=1600×1000、旧图旋转 -6°、缩放 1.14、15×10 格与显式通行/障碍定义。
- 对位要求：桥面水平可通行区域以既有网格第 4 行、第 5–10 列为准，河水不可通行；必须保留至少六人清楚站位。**不能为适配图片擅改地图拓扑**。
- 统一原点：1600×1000 的左上为 (0,0)，地图 Marker / 脚点 / 场景层共用逻辑坐标。

## 输出与验收

- `background`：1600×1000 完整远景；`ground`：1600×1000 独立透明可站立地面（必选、不是背景副本）。
- `foreground`：同画布透明遮挡层；`weather`：同画布可关闭的雨雾层。
- 需有可编辑分层母版、层合成对位图、前景遮挡示意、与 grid/collision 对照截图、来源和提示词。
- Godot 目标：`res://data/native/scene_art/rainy_bridge.tres` → `res://data/maps/rainy_bridge.tres` 的 `scene_art`。
- 先导入候选并测试；批准前不可覆盖目前加载的 WebP。

## 审核清单

- [ ] 镜头、桥面与现有 grid 对位人工签核
- [ ] 四层同原点/同尺寸；透明 ground、foreground、weather 均可检验
- [ ] 角色脚点、六人站位、前景遮挡与河水障碍一致
- [ ] 关闭天气不改变 LOS / 通行 / 交战
- [ ] 1600×1000 和 1440×900 GUI 截图、性能与授权
- [ ] Owner 批准版本及 SHA

## 结论

- 审核状态：`pending`
- 阻塞：参考未批准、真实可编辑分层素材尚无，地图美术对位和权属签核未完成。
