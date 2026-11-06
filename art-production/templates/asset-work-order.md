# 美术素材制作工作单模板

复制本文件至 `art-production/candidates/<asset-type>/<asset-id>/WORK_ORDER.md` 并填写。文中的值只是示例。

## 基本信息

- asset_id: `shen_changfeng`
- asset_type: `character_design | portrait | sprite | environment | scene_layer | item_icon | card_art | ui | vfx`
- target_usage: `story | battle | inventory | card | hud`
- status: `candidate`（工作区状态；正式使用后由原生 Resource 确认 `in_use`）
- 目标 Godot Resource：`res://data/native/characters/shen_changfeng.tres`
- 最终原生编辑入口（按类型填写）：`res://data/native/animations/<id>_frames.tres | res://scenes/.../<id>.tscn | legacy Atlas Clip`
- 原生绑定关系：`Character.animation_profile.native_frames | Map.scene_art | Chapter.scene_art | UI PackedScene | VFX PackedScene / Cue`
- 编辑真源：`SpriteFrames 动作帧 / 探索 .tscn 几何 / 战斗 Map .tres 玩法 / UI .tscn / VFX .tscn`（只选对应项）
- 候选 Godot Resource：`res://data/art_candidates/characters/shen_changfeng/<source-file-stem>.tres`（自动补齐后可修改）
- 计划导入路径：`res://assets/imported/characters/shen_changfeng/portraits/portrait.png`
- 原始提示词／修订：`记录实际发送内容`
- 来源与权属：`如已知则记录；待核实可留空`
- 模型/version/seed：`可选；不要猜测未知历史数据`

## 参考与身份锁定

- 批准的风格参考路径：
- 角色设计板或场景母版路径：
- palette / light / camera：
- 不得变化的身份或场景要素：
- 实际输入给 AI 的参考图：

## 输出与验收

- 角色设定身高 `height_m`（仅角色动画）：
- 角色自然站姿源像素高度（仅角色动画）：`round(height_m × 100)`，应为 100–220px
- 角色全动作统一单格（仅新制作角色动画）：`328x256` 普通档 / `384x288` 高个档（宽×高，选定一档）
- 最终目标尺寸（非默认猜测）：
- 文件格式与 Alpha：
- Atlas 行列 / 帧索引（如适用）：Sheet 宽 `W×C`、高 `H×R`，各动作有序索引
- 动画候选形式（仅角色动画）：`AI 5x5 Sheet | 每动作一张透明 GIF | 独立帧`；GIF 记录 `action_id`、单帧尺寸与原始帧时长，**不填造 C×R**
- 新原生动画输出：`SpriteFrames.tres` 路径、每动作 FPS／逐帧 duration／loop；历史 Atlas 才记录 Clip 绝对帧序
- 候选 Resource 中测得的源图像素 / 参考姿势可见高度 / 建议显示比例（如适用）：
- 脚点 / 承重脚类型 / 复核状态 / 根位移 / 方向 / 时间轴（如适用）：
- 场景图层及共享原点（如适用）：
- 场景原生编辑入口与同步状态（如适用）：`.tscn` 路径、关联 `source_map.tres`、探索碰撞／Marker／Exits 同步验证；战斗地图另记录玩法 `.tres`
- Godot UI/VFX 原生场景及实际消费它的 Resource／Cue（如适用）：
- Godot 目标 `.tres`：
- 参考提示词全文及每次修订（至少记录实际生效版本）：
- 原始生成图和可编辑母版：

### 审核清单

- [ ] 造型、色板、材质与批准参考一致
- [ ] 透明背景真实有效，边缘无色边（如要求）
- [ ] 新角色动画按设定身高×100源像素生产，整角色统一 328×256 或 384×288，每格四边至少8px真透明边距、无越格（如适用）
- [ ] 帧连续、身份/武器数量不漂移、脚点经真实接触复核、根位移独立审查、无源图截断（如动画）
- [ ] 新角色动作帧序、FPS、逐帧时长在 `SpriteFrames.tres` 中可编辑、保存、重新打开；旧 Clip 仅兼容（如动画）
- [ ] 场景图层同尺寸、遮挡和可行走区一致（如场景）
- [ ] 已原生化的探索地图 `.tscn` 几何同步到 `.tres` 并验收双向出口；战斗地图未把视觉图层误作玩法几何（如地图）
- [ ] UI / 图标小尺寸清晰、文字独立排版（如适用）
- [ ] 导入器预检所改路径并保留人工 `.tscn`／`SpriteFrames` 微调、备份与可撤销记录（如正式导入）
- [ ] Godot Resource 加载与导出通过
- [ ] 1600×1000、1440×900 GUI 实机截图通过
- [ ] 来源、授权与商业近似风险人工审核
- [ ] 负责人批准并记录日期

## 结论

- 视觉验收结论：`待复核 | 需返工 | 已通过`（不是第三种资产管理状态）
- 反馈与修订：
- 当前使用中的 Resource 槽位／文件路径（如已导入）：
