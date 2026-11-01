# 追镖首领：敌人/立绘/动画制作工作单

## 身份和用途
- asset_id: `pursuer_captain`，匹配现有敌人 `WuxiaCharacterDefinition`；目标 battle / story
- 身份锁：身材魁梧的中年追索者，蓄须、下颌旧伤、暗黑铁甲与旧皮革、暗朱红围巾及右臂绑带、沉重单刃刀
- 与沈长风严格区分：宽肩重刀、暗赤灰黑，不能沿用主角的直剑/窄腰青袍
- 设定参考：`character_pursuer_captain_identity_sheet_v01.png`（**待负责人确认**）
- 生产日期：2026-11-01
- 生成工具：内置图像生成工具；底层模型 ID 未公开；seed 不可获取
- 风格基准：`art-production/standards/ART_PRODUCTION_STANDARD.md` 与 `prompts/ART_STYLE_AI_PROMPTS_V1.md`
- 来源/权属：本项目定向原创 AI 生成，未使用外部商业角色图；仍须由负责人完成可商用权属、相似性与最终视觉审核
- 状态：**candidate / owner_review_required**；绝不等同 approved 或 runtime/in_use
- 全量提示词见同批 `PROMPTS.md`；SHA-256 与版本源流见 `PILOT_MANIFEST.json`。

## 产物
- 1536×1024 身份设定板
- 1024×1536 透明全身立绘 `portrait_pursuer_captain_fullbody_v01.png`
- V1 原始图集及 V2 动作源图；可技术播放候选 `sprite_pursuer_captain_atlas_normalized_v02.png`
- 1536×1024、6×4、每格 256×256；动作帧映射：`idle` 0–1；`move` 2–5；`attack` 6–8；`guard` 9–10；`hit` 11–12；`evade` 13–15；`skill` 16–18；`combo` 19–21；`defeat` 22–23。
- 脚点范围 227–228 像素；技术裁切安全边距检查通过
- 目标关联：`data/native/characters/pursuer_captain.tres`；正式批准之前禁止改其纹理引用

## 验收现状
- [x] 真实 RGBA、24 帧、九动作合法、格内留白和脚点技术检查
- [ ] 身份板/立绘和动作同脸、同刀、同装甲由人工确认
- [ ] 原始动作剑刀越格造成的刀尖裁断补绘；重刀动作时序与受击/倒地自然度
- [ ] 前/背/左右完整方向；Godot 编辑器预览与攻防/VFX 对齐
- [ ] 两档分辨率截图、商用权属与负责人批准

**结论：候选；敌人当前在用资源保持不变。**
