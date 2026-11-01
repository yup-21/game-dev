# 荒道破庙 · 剧情分层场景试点 WORK_ORDER

## 基本信息

- asset_id: `rain_escort_prologue_story`
- asset_type: `environment | scene_layer`
- target_usage: `story`
- status: `concept`
- owner/reviewer: **待指派**
- source / rights: **旧背景来源与商业权属待核实**
- prompt_template_version: `ART_STYLE_AI_PROMPTS_V1`
- model/version/seed: **尚未开始分层制作**

## 参考与镜头锁定

- 当前运行时背景：`demos/changfeng-battle/assets/scenes/story/ruined_temple_story.webp`，作为回退原图保留。
- 剧情绑定：`res://data/native/chapters/rain_escort_prologue.tres` → 内嵌 `WuxiaChapterSceneDefinition.scene_art`。
- 人物/脚点：沈长风初始 (350,705)，受伤镖头 (1050,560)，玩家范围 x=155..1415、y=345..755（不改变现有剧情触发/角色逻辑）。
- 镜头：1600×1000 固定逻辑画布，兼顾 1440×900；不能让雨雾/前景遮住对白与按钮。

## 输出与验收

- `background`：1600×1000 远景；`ground`：1600×1000 独立透明可站立地面（必选）。
- `foreground`：1600×1000 可遮挡前景；`weather`：1600×1000 可开关雨雾。
- 层像素对位、左右雨夜光向、角色地面接触处、NPC 交互位置和对白安全区均需实机审查。
- Godot 目标：`res://data/native/scene_art/rain_escort_prologue_story.tres`，通过 Art Production Dock 挂到章节 `scene_art`；旧背景继续作为回退。
- 必须归档原图参考、制作提示词、分层母版、图像版本和授权记录。

## 审核清单

- [ ] 镜头、地图脚点、NPC 交互距离核对
- [ ] 1600×1000 图层/透明通道/母版技术检查
- [ ] 剧情探索时前景遮挡正确，进入对白后 UI 不被覆盖
- [ ] 1600×1000 / 1440×900 视觉截图核验
- [ ] 来源、商用授权、Owner 签核及 SHA

## 结论

- 审核状态：`pending`
- 阻塞：原图权属、批准构图、可编辑分层母版及实机视觉审核尚缺。
