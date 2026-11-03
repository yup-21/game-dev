---
name: wuxia-character-art
description: "为《长风浮生录》制作、修订或审核角色设定板、透明立绘、头像、2D Sprite 动作帧与动画 Atlas 时使用；确保同一角色身份、脚点、动作与 Godot WuxiaActorAnimationProfile 合同一致。"
---

# 武侠角色美术与动画

## 依据与边界

- 在开始制作前读取仓库中的 art-production/standards/ART_PRODUCTION_STANDARD.md；使用 AI 生成时再读取 art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md 的全局风格及角色章节。
- 读取 art-production/templates/asset-work-order.md，复制为 art-production/candidates/YYYY-MM-DD/<asset-id>/WORK_ORDER.md，填写身份参考、来源、权属、模型/seed（若可得）、提示词、版本与审核人。
- 采用原创国风精细 2D 手绘、克制水墨、真实材质；HD-2D 指空间构图而非强制像素化。不得临摹商业角色，不得用未经批准的候选覆盖运行图。

## 制作流程

1. **冻结身份**：先提出正/背/左/右轮廓、发型、服饰层次、主辅色、武器、脚底接触点和动作态度，取得人工确认。角色立绘、剧情姿态、Sprite 和头像必须以同一批准设定为身份锚点；未获批准时明确标记为暂定参考。
2. **制作立绘**：输出单人物透明 PNG/WebP，保留头发、剑尖、衣摆安全边距。逐一核验真实 Alpha、发丝与武器边缘；纯色底图和白底 JPEG 不算透明成品。
3. **制作动作**：按 idle、move、attack、guard、hit、evade、skill、combo、defeat 九类逐帧制作。循环动作能闭环；非循环动作展示起手、有效与收招，不得通过简单拉伸单一姿势冒充动画。仅叙事用静态 NPC 可在工作单注明豁免原因，不伪造完整战斗动画。
4. **对齐帧与方向**：固定脚点与角色比例，检查衣袂、武器轨迹连续且不越格；目标为前、后、左、右四方向。当前左右镜像和上下复用水平朝向只是过渡，未真正补全前不得宣称四方向已批准。
5. **装配 Atlas**：全部格子同宽高，纹理尺寸须能被 columns/rows 整除；帧索引为绝对索引，不能越界。旧 6×4 和 256×256 试点值不作为新内容的固定要求，真实尺寸、帧率待首批验收冻结。
6. **接入原生资源**：以 demos/changfeng-battle/data/templates/actor_animation_profile.tres 为模板；在 WuxiaActorAnimationProfile 中绑定 Atlas、columns/rows、feet_offset、actor_scale 和九个 WuxiaActorAnimationClip。只允许 idle/move 使用 loop，正式角色经 WuxiaCharacterDefinition.animation_profile 引用，并在 data/content_manifest.tres 注册角色。不要加入角色 ID 特判，不得由动画修改 BattleModel、HP、Qi、CTB 或响应规则。

## 交付和验收

- 保存原图、可编辑母版、逐帧源文件、Atlas、角色预览与 WORK_ORDER.md，不覆盖旧版本。
- 自动检查：文件可解码、Alpha、图集可整除、所有九类动作存在且索引合法；profile 的 columns/rows 为 1–64，clip 帧数 1–256，循环 FPS 在 1–60 范围。
- 人工检查：身份一致、透明边缘、脚点无漂移、武器方向正确、帧间连续、特效与 BattleActionTimeline 有效窗口匹配。
- 在 Godot Editor 播放，留存 1600×1000 和 1440×900 GUI 截图与必要的动画录像。技术通过只可视为 candidate，人工视觉及授权验收完成后方可标记 approved。
- 向调用者汇报：候选路径、动作覆盖率、仍待冻结的参数、未通过项目、审批状态；不得自行宣称已获批准。


## 单手剑逐帧动作：支撑脚与帧间留白硬约束（2026-11-03 补充）

适用 idle / move / attack / guard / hit / evade / skill / combo / ultimate 候选 / defeat；不要求统一每动作 8 帧，按需要选 4–12 帧以上。

- **身份锁**：沈长风为单手剑，右手一柄完整直剑，左手不持剑；保留青灰墨蓝手绘武侠身份和固定向右侧身角度。像素风支点图只是力学示意，不得替代角色成品画风。
- **先逐帧后图集**：优先逐张透明 PNG；若 AI 生成多格源稿，先按母图真实几何拆格。跨格、断剑、断袖必须回源重绘；后处理裁切只能隔离，不能恢复缺失画面。
- **落脚点不是透明轮廓最低像素**：逐帧记录承重鞋底或倒地的实际接地点坐标及其审查状态，人工校正后才能认定支点稳定。禁止仅通过“统一下边缘”宣布脚点对齐。
- **运动分阶段**：待机后脚锁定，只让胸肩和衣袂小幅活动；格挡在架剑承重阶段锁脚；行走轮流换支撑脚；攻击从后脚蹬地、重心向前、出剑、前脚接地到收招，不允许根节点瞬间往后弹；倒地最后几帧用躯干地面接触点，不再强迫鞋底固定。
- **留白验证**：每帧剑尖、头发、衣摆、鞋底与当前格边均留至少 24px（试点值，随资源可变）；以所需最宽动作决定统一格宽，不许挤格、横向拉伸或偷裁切。
- **尺度与时序**：源帧实际尺寸从原生 .tres 确认，1 战斗单位=80 世界像素、普通角色200世界像素不变。非循环动作仍由 BattleActionTimeline 控制，绝招若无运行时 clip 合同先作为候选，不为角色编写 ID 特判。
- **自动与人工分开**：自动检 alpha、帧数、索引、每帧 margin、接触候选误差、源格边触碰；人工复核脚底真实位置、双剑误生成、剑尖完整、动作连续性、脚滑与 Godot GUI。机器将候选点移动为 0px 不等于视觉通过。
