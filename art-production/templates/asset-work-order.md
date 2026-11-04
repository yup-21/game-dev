# 美术素材制作工作单模板

复制本文件至 `art-production/candidates/<asset-type>/<asset-id>/WORK_ORDER.md` 并填写。文中的值只是示例。

## 基本信息

- asset_id: `shen_changfeng`
- asset_type: `character_design | portrait | sprite | environment | scene_layer | item_icon | card_art | ui | vfx`
- target_usage: `story | battle | inventory | card | hud`
- status: `candidate`（工作区状态；正式使用后由原生 Resource 确认 `in_use`）
- 目标 Godot Resource：`res://data/native/characters/shen_changfeng.tres`
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

- 最终目标尺寸（非默认猜测）：
- 文件格式与 Alpha：
- Atlas 行列 / 帧索引（如适用）：
- 候选 Resource 中测得的源图像素 / 参考姿势可见高度 / 建议显示比例（如适用）：
- 脚点 / 承重脚类型 / 复核状态 / 根位移 / 方向 / 时间轴（如适用）：
- 场景图层及共享原点（如适用）：
- Godot 目标 `.tres`：
- 参考提示词全文及每次修订（至少记录实际生效版本）：
- 原始生成图和可编辑母版：

### 审核清单

- [ ] 造型、色板、材质与批准参考一致
- [ ] 透明背景真实有效，边缘无色边（如要求）
- [ ] 帧连续、身份/武器数量不漂移、脚点经真实接触复核、根位移独立审查、无源图截断（如动画）
- [ ] 场景图层同尺寸、遮挡和可行走区一致（如场景）
- [ ] UI / 图标小尺寸清晰、文字独立排版（如适用）
- [ ] Godot Resource 加载与导出通过
- [ ] 1600×1000、1440×900 GUI 实机截图通过
- [ ] 来源、授权与商业近似风险人工审核
- [ ] 负责人批准并记录日期

## 结论

- 视觉验收结论：`待复核 | 需返工 | 已通过`（不是第三种资产管理状态）
- 反馈与修订：
- 当前使用中的 Resource 槽位／文件路径（如已导入）：
