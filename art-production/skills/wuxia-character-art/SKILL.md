---
name: wuxia-character-art
description: "为《长风浮生录》创建、重绘、修订、提帧、补间、标注脚点、打包或审核角色立绘与2D武侠动作精灵图时使用；涵盖单帧生成、视频转精灵图、角色身份锁定、根位移、Godot 原生动画验收。"
---

# 武侠角色美术与动画工作流

## 必读合同与素材边界

- 开始前读取 `art-production/standards/ART_PRODUCTION_STANDARD.md` 与 `art-production/standards/SPRITE_ANIMATION_QA.md`；使用 AI 生成时再读 `art-production/prompts/ART_STYLE_AI_PROMPTS_V1.md` 第 1、3、5 节。
- 读取 `art-production/templates/asset-work-order.md`，在 `art-production/candidates/YYYY-MM-DD/<asset-id>/` 留候选工作单、真实提示词与目标原生 Resource。来源可记录对应提示词/Resource，不强制额外模型、seed 或审批字段。
- 资产管理只有 `candidate` 与 `in_use`：技术预检不会批准画面；未完成视觉验收不覆盖当前绑定。Godot 运行内容仍仅来自 `.tres` 与 Content Manifest，离线 CSV/JSON 不成为运行时源数据。

## 执行流程（每一阶段可返工，不跳闸）

1. **确认身份与视角**：用同一批准角色设定图与立绘锁定头身比、简化手绘画风、衣服层次、鞋和武器数量/持手。沈长风一柄右手剑、左手空手。横版侧视动画锁定 90° 镜头、人物尺度与地线；现有左右镜像不代表四方向完成。
2. **写单动作脚本**：明确 `idle/move/attack/guard/hit/evade/skill/combo/defeat` 的起手、承重/蓄力、有效、收势、循环/非循环、预期根位移、接触脚和帧数。按复杂度确定帧数，不强迫 6/8 帧；先做 `idle/move/attack/guard` 四动作试点，达标再扩展。
3. **生产原始帧**：逐帧/重绘路线先做正确关键姿势再补真实间帧；视频路线先固定镜头生单动作视频，用 FFmpeg 实际抽帧（抽帧不是补帧）、逐帧去背景；3D 渲染帧同样受合同约束。如存在 `art-production/tools/VIDEO_TO_SPRITE.md`，按其 `extract → pack → assemble` 流程制作候选。
4. **先审原图**：逐帧检查手中武器数、握剑手、侧视方向、人体结构、衣摆/剑尖是否缺失、Alpha 色边及视频闪烁。断剑、跨源格、额外手臂、视角变化需要回源重绘；切开图集、增加边距不能补回丢失部分。
5. **标注接触与位移**：用 `art-production/tools/sprite-anchor-editor.html` 标每帧真实承重鞋底，倒地改用躯干接地；自动 Alpha 最低点和复制点仅 `reviewed=0`。行走换脚、攻击前冲、闪避位移需独立记录根坐标增量，不能因固定局部脚点而抹掉世界位移；离线 root CSV 目前**不被 Godot 运行时自动读取**。
6. **无损对齐打包**：先取所有动作的最大完整轮廓确定同格尺寸，再原像素平移打包；不对每帧不同程度缩放/强行居中/裁剪。剑尖、发丝、鞋底距边留足透明空间，24px 为试点建议。以实际列行和绝对帧索引装配 Atlas，检查循环闭合与真实预览 FPS。
7. **原生绑定**：基于 `demos/changfeng-battle/data/templates/actor_animation_profile.tres` 配置 `WuxiaActorAnimationProfile` 的 atlas/columns/rows/feet_offset/actor_scale 和九个 `WuxiaActorAnimationClip`；每 clip 1–256 帧、只循环 idle/move、列行 1–64。正式角色经 `WuxiaCharacterDefinition.animation_profile` 绑定。当前非循环动作由 `BattleActionTimeline` 决定时长，设置 `loop_fps` 不会让 attack 等独立按该 FPS 播放。新增 `ultimate` 在合同支持前只留候选。
8. **双重验收**：自动检查真实 Alpha、源格截断、帧索引、留白、脚点复核覆盖与引用；人工在实际 FPS 下看身份连续、镜头、脚滑、根位移、武器路径、受力、循环拼缝；Godot 中在 1600×1000 / 1440×900 播放、核对角色 200 世界像素高度、战斗事件有效窗口和导出。只交付候选/截图/告警与未解决项，不提前宣称批准。

## 停止条件

- 身份或武器变化、源帧截断、关键姿势错误、持续视频闪烁：回到第 3–4 步重制，不用自动对齐掩盖。
- 接触点未人工核对、攻击/闪避根位移未明确、逐帧缩放、帧序不真实：停在 `candidate`，补齐依据再接入。
- Godot 里播出的帧数/节奏与离线预览不一致、脚点与世界尺度不符：先检查 `.tres`、当前时间线和角色绑定，不为单个角色增加 `BattleModel` 特判。
- 最终报告至少写出候选及 Resource 路径、动作及每动作帧数/FPS、人工脚点复核情况、根位移依据、未通过项与实际 Godot 预览结果。
