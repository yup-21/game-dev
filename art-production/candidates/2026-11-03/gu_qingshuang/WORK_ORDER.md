# 顾清霜 v06 精灵图固定点重排工作单

- asset_id: `gu_qingshuang`
- asset_type: `sprite`
- target_usage: `battle / story`
- status: `candidate / visual review pending`
- 身份源：`demos/changfeng-battle/data/native/characters/gu_qingshuang.tres`
- 立绘参考：`art-production/candidates/2026-11-01/gu_qingshuang/portrait_gu_qingshuang_fullbody_v01.png`
- 身份/武器硬约束：护卫、霜蓝长衣、细剑，保留原立绘比例与持剑手
- 原图：`art-production/candidates/2026-11-01/gu_qingshuang/sprite_gu_qingshuang_atlas_aligned_v03.png`
- 既有生成提示词：参见 2026-11-01 工作单及批次 Prompt；v06 不使用新的 AI 图像生成提示词
- 本次处理：原像素平移、接地点标注、动态透明边距；不重绘和不改动动作结算
- 目标输出：`sprite_gu_qingshuang_atlas_anchor_v06.png`、9 组动作 GIF、`gu_qingshuang.csv`、`frame_review.json`
- 动作：`idle/move/attack/guard/hit/evade/skill/combo/defeat` 全部九类；废弃不同朝向 `frame 0` 不放入待机
- Godot 目标：需另外建立候选 `WuxiaActorAnimationProfile` 后播放，当前正式资源不变

## 逐帧验收

- [ ] 23 个运行姿势全部人工复核承重脚/躯干落地点
- [ ] 脚点锁定、行走换脚、攻击起手/发力/收招和根位移没有异常
- [ ] 原图源格触边、断刃、手脚缺失逐个检查并重新绘制
- [ ] 武器数量、方向、服装/发型与身份参考一致
- [ ] 攻击/技能/连携时序与动画有效窗口一致
- [ ] 新增间帧并检查循环闭合（当前候选仅重排既有姿势）
- [ ] 若要与沈长风 v05 的十动作规格一致，补绘绝招 `ultimate`
- [ ] Godot 实机、1600×1000 和 1440×900 动态截图/录像
- [ ] 权属和项目负责人视觉批准

结论：**工程候选，非最终美术**。固定点自动估算不能替代人工标注；未批准不覆盖任何在用 .tres。
