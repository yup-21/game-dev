# 摆渡老张 · 序章逐动作 GIF 候选 v01

- 状态：`candidate`，不得覆盖正式运行资产。
- 动作交付：每个动作独立 6 帧透明 GIF，不使用 5×5 混合精灵图。
- 单帧规格：328×256 px。
- 动作 ID：`idle`、`pole_row`、`greet`、`farewell`。
- Godot 接入：每张 GIF 对应独立 `WuxiaArtCandidateDefinition.tres`；GIF 候选不声明 C×R Atlas 网格，必须声明 `action_id`。
- 晋升条件：Godot Native GIF 实速预览、动作节奏、脚点、人物比例与 Alpha 边距人工验收后，才能转为正式 `SpriteFrames.tres` 并绑定运行时角色。
