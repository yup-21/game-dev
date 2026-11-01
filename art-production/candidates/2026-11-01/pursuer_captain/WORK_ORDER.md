# 追镖首领 · 身份与重刀动画试点 WORK_ORDER

## 基本信息

- asset_id: `pursuer_captain`
- asset_type: `character_design | portrait | sprite`
- target_usage: `battle | hud`
- status: `concept`
- owner/reviewer: **待指派**
- source / rights: **历史 JPG 来源与商业权属待核实**
- prompt_template_version: `ART_STYLE_AI_PROMPTS_V1`
- model/version/seed: **尚未开始新一轮生成**

## 参考与身份锁定

- 正式角色数据：`res://data/native/characters/pursuer_captain.tres`，人设“追镖首领／重刀／冷厉执拗”。
- 当前占位图：`demos/changfeng-battle/assets/concepts/2026-10-30/character_style/red_thread_fighter_pixel_study.jpg`。
- 已批准身份设定板：**暂无**；必须先定脸、发式、重刀尺寸、武器惯用手、布甲材质与敌友色彩区分。
- 与沈长风共用光向、材质密度和身高/脚点尺度，仍保持重刀身形的独立识别度。

## 输出与验收

- 文件格式：透明 RGBA PNG/WebP 立绘与统一网格 Atlas；不可继续以白底 JPEG 作为最终动画交付。
- 九动作：`idle/move/attack/guard/hit/evade/skill/combo/defeat`，完整实际索引；重刀动作需辨识起手、有效帧和收招。
- `columns`、`rows`、`feet_offset`、`actor_scale` 和 FPS：待试点定，不强制 6×4。
- Godot 目标：`res://data/native/characters/pursuer_captain.tres`、`res://data/native/animations/pursuer_captain.tres`。
- 需归档参考输入、提示词全文、模型/seed、分层母版、版本、权属。
- 当前角色/敌方 AI 和战斗数值保持不变。

## 审核清单

- [ ] 原创身份设定板与来源批准
- [ ] 透明边缘、Atlas 切格与帧范围检查
- [ ] 同一身份从立绘至战斗及方向一致
- [ ] 重刀动作在事件窗口内可读，脚点无漂移
- [ ] 1600×1000 / 1440×900 两种 GUI 复测
- [ ] Owner 批准版本及 SHA

## 结论

- 审核状态：`pending`
- 阻塞：批准参考、正式逐帧素材、可编辑母版、授权与实机签核尚缺。
