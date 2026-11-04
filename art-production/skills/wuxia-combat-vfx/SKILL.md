---
name: wuxia-combat-vfx
description: "为《长风浮生录》创作、优化或审核剑气、格挡、命中、闪避、连携等 2D 武侠战斗特效时使用；负责透明逐帧动画、事件时序、目标可读性和 Godot 表现层接入。"
---

# 武侠战斗 VFX

## 制作依据

- 读取 art-production/standards/ART_PRODUCTION_STANDARD.md 和 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md 的风格、动画与 VFX 章节；使用模板 art-production/templates/asset-work-order.md 留档。
- 效果使用克制水墨边缘、可辨识的力量方向和短促明亮的核心；不得使用不受控的全屏霓虹，遮蔽角色脚点、目标状态、交锋提示或右侧 CTB。
- 将每个新增效果先归档至 art-production/candidates/<asset-type>/<asset-id>/，保存源帧、提示词、参考、模型/seed（如可得）、修订和权属。
- 绘图只发送 `ART_STYLE_AI_PROMPTS_V1.md` §10 的 VFX 短模板与必要方向、颜色、阶段；帧索引、触发窗口、性能与验收规则留在 Resource／制作检查，不拼入生图提示词。

## 制作与接入

1. 明确事件类型、施放者、目标、方向、有效窗口、屏幕占位和视觉层级，再基于批准的角色/场景参考确定色彩。
2. 分别建立 slash（剑光方向）、guard（短促碰撞）、impact（目标受击可读）、evade（速度残影）和 combo（区别于普通攻击）的关键帧与过渡帧。
3. 输出有真实 Alpha 的独立 RGBA 序列，保持相邻帧原点、方向和形状连续；可装配为 Atlas 或原生动画 Resource。黑底/白底不是透明。图集用 `WuxiaVFXDefinition.columns`、`rows`、`frame_indices`（绝对索引）描述播放顺序，不能把 6×4 当作新 VFX 的固定格式。
4. 与 BattleActionTimeline 的起手/有效/收招语义窗口对齐；特效只在表现层播放。按当前 Resource 的 `event_kind`、角色／技能归属与动作有效帧 Cue 配置，不得在 VFX 内修改 HP、Qi、CTB、Buff 或响应规则。
5. 在 Godot 的目标战斗镜头下检查左右朝向、多单位重叠、卡牌 HUD/CTB 遮挡、性能及低性能档关闭效果后的行为。
6. 用真实演出截图/录像和工作单提交人工审核；未冻结的贴图尺寸、FPS、帧数只可标为候选参数。

## 验收输出

- 源帧、装配资源、统一锚点说明、事件绑定、WORK_ORDER.md、Godot 预览及 1600×1000 / 1440×900 截图。
- 技术检查 Alpha、帧尺寸、引用、播放终止和重复触发；人工检查瞬时辨识、受击时机、颜色一致、目标可读性及权属。
- 资产管理只区分 `candidate` 和 `in_use`；把 `vfx/<actor-id>/<skill-id>/atlas.<ext>` 导入并绑定 Resource 后就是当前使用版本，版本切换须预检、保存可回滚记录。技术加载不等于视觉／授权审核通过，审核结论只写工作单。
