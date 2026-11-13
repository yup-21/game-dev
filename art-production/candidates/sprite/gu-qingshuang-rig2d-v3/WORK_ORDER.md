# 顾清霜 v6 骨骼动画 v3 候选工作单

## 基本信息

- asset_id: `gu_qingshuang_rig2d_v3`
- asset_type: `sprite`
- target_usage: `battle`
- status: `candidate`
- 角色：顾清霜，右向 90° 侧视，右手单剑、左手空置
- 离线可编辑真源：[`pose_templates` PR #1 的 `project_biomech_v3.json`](https://github.com/yup-21/pose_templates/pull/1)
- 目标 Godot Resource：尚未建立，正式导入后应使用 `res://data/native/animations/<id>_frames.tres`，由目标角色 AnimationProfile 的 `native_frames` 引用；不得当前替换
- 预计帧规格：384×288，统一原点 (171,256)，动作计划标称身高 180 源像素（角色实际设定身高待身份资料复核）
- 原画：`pose_templates/rig2d/gu-qingshuang-v6/source/gu_qingshuang_sideview_parts_atlas_v01.png`，原图和 SHA-256 未变
- 本轮输入方法：程序化 UV 拆件＋手臂/鞋尖骨骼姿势修正，没有调用新的 AI 绘图模型，无新增提示词
- 制作报告：[`BIOMECH_V3_REPORT.md`](https://github.com/yup-21/pose_templates/blob/codex/gu-qingshuang-rig2d-project/rig2d/gu-qingshuang-v6/variants/BIOMECH_V3_REPORT.md)

## 输出与进度

- [x] 12 组共 117 帧候选动作源数据，原始时长、剑握点、脚接触方案和世界位移保持
- [x] 27 个部件图层定义，新增左右鞋尖 UV 分件；肩袖／靴筒沿用 v2 候选纹理
- [x] Blender 4.3 全套骨骼几何求解与合成图集的渲染通路试验
- [ ] 使用顾清霜真实透明图集渲染 v3 全套 GIF 与逐帧 PNG
- [ ] 逐动作实速检查肩腋、肘内面、鞋尖连接、裙摆遮挡、重心和脚滑
- [ ] 按原画补绘必要 P0 内衬、鞋褶和裙片遮挡
- [ ] Alpha 与四边至少 8px 透明边距、身份／武器、真脚点、循环与收势检查
- [ ] Godot 原生 SpriteFrames 导入、实际动画预览、1600×1000 与 1440×900 实机检查
- [ ] 人工视觉、权属审核以及明确的绑定批准

## 结论

- 技术结果：几何通过；合成纹理仅用于验证程序能渲染，不代表真实角色美术合格。
- 视觉验收：**待复核**。
- 当前正式使用的 Resource：未修改。此单只是离线候选追踪，不进入 Content Manifest。
