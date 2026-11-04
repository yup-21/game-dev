# 黑衣刀客 v06 精灵图固定点重排工作单

- asset_id: `black_blade`
- asset_type: `sprite`
- target_usage: `battle / story`
- status: `candidate / visual review pending`
- 身份源：`demos/changfeng-battle/data/native/characters/black_blade.tres`
- 立绘参考：`art-production/candidates/characters/black_blade/baseline/portrait_black_blade_fullbody_v01.png`
- 身份/武器硬约束：暗色护甲、赤锈腰绳、黑刃长刀，检查长刀轨迹完整
- 原图：`art-production/candidates/characters/black_blade/baseline/sprite_black_blade_atlas_aligned_v03.png`
- 既有生成提示词：参见 2026-11-01 工作单及批次 Prompt；v06 不使用新的 AI 图像生成提示词
- 本次处理：原像素平移、接地点标注、动态透明边距；不重绘和不改动动作结算
- 目标输出：`sprite_black_blade_atlas_anchor_v06.png`、9 组动作 GIF、`black_blade.csv`、`frame_review.json`
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

## 2026-11-04：十二动作新候选与 Resource 接线

- 原始素材：本目录 `concept/character_design_v01.png` 及 `actions/<action-id>/sprite_<action-id>_vNN.png`；对应来源、目标分镜与技术初筛见 `AI_12_ACTION_CANDIDATES.md`。
- 新建**不参与 Content Manifest** 的候选原生 Profile：`res://data/candidates/characters/black_blade/animation_profile.tres`。
- 对应正式角色：`res://data/native/characters/black_blade.tres`；正式 Profile：`res://data/native/animations/black_blade.tres`；两者保持原绑定不变。
- 候选 Profile 已逐项声明 `idle/walk/run/attack1/attack2/attack3/attack4/skill/evade/guard/hit/defeat`；目前所有 Clip 仅引用已在用的 **旧 6×4 Atlas**，是验证原生 Resource 接线和替换入口的临时配置，**不代表本轮新生成动作已导入或验收**。新 `walk/run` 暂共用旧 `move` 帧，四组攻击暂共用旧 `attack` 帧；这是候选 Profile 的显式配置，非运行时隐式回退。
- 新源图暂不进入 `assets/imported/`：14 张动作图未通过 G1 分格和安全边距；三组 `guard/hit/defeat` 新原图缺失。不得将这些未经检查的 Sheet 按一格一帧伪装导入。
- 后续逐动作通过 G1/G2 后，先导入合格的单动作 Atlas，填写每个 Clip 的 `atlas/columns/rows/frames/frame_durations/root_offsets`；全部 12 组通过动态验收后，再另行评估替换正式绑定。
- 实际完整生图提示词未随原始文件保留，本次没有杜撰；`AI_12_ACTION_CANDIDATES.md` 记录了可追溯的用户要求。
- 检查：`godot --headless --path demos/changfeng-battle --script res://checks/test_black_blade_candidate_profile.gd`。
