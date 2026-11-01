# 青衫客 · 第一幕美术制作工作单

- asset_id: `green_wanderer`
- target_usage: `battle / story / HUD`
- 角色卡身份来源：`demos/changfeng-battle/data/native/characters/green_wanderer.tres`
- 身份锚点：旧青衫、直剑、身法游侠
- 源图：`portrait_green_wanderer_fullbody_v01.png`、`sprite_green_wanderer_atlas_source_v01.png`
- 来源：原创图像生成；Prompt 见同批 `CHAPTER_ONE_PROMPTS.md`
- 原始尺寸：透明立绘 1024×1536；Atlas 原稿 1536×1024（6×4，24 姿势）
- 正式运行时目标：`WuxiaCharacterDefinition` + `WuxiaActorAnimationProfile`
- 目前动作：idle 2 / move 4 / attack 3 / guard 2 / hit 2 / evade 3 / skill 3 / combo 3 / defeat 2

## 初稿制作状态（归档时点）

- 分支：`art/chapter-one-candidates-20261101`，基于 #83，**非批准资产**。
- 状态：`concept / requires technical cleanup`。不得标注 `approved` 或替换 main 现有运行资源。
- 图像生成工具：ChatGPT built-in image generation；具体模型版本、seed 未提供。
- 人工审核：身份一致性、商业权属、四方向、动画质量、实机截图均待完成。

## 尚未通过的检查

- [ ] 四视图设定板、身份锁定和旧图风格一致
- [ ] 图像真实 Alpha 与无色边，去除残余底色
- [ ] 24 格逐帧分割、完整刀剑、脚点统一和动作流畅性
- [ ] 前后左右方向补全（当前只有一套 3/4 视图）
- [ ] Godot 编辑器手工导入、角色卡与肖像 Registry 全链路加载
- [ ] 战斗/剧情与 1600×1000、1440×900 截图验收
- [ ] 商用授权、造型近似、负责人审批

## 结论

原始生成图已归档供修订；**不得直接作为正式战斗 Atlas**。技术处理通过后再导出规范化运行 PNG，保留原稿和版本关系。

## 2026-11-01 扩展进度

- [x] 原始生成图保留，逐图哈希与 Prompt 已归档。
- [x] Godot 审核分支已接入对应 `.tres`，不修改 `main`。
- [x] 24 帧源图归一化为 `sprite_green_wanderer_atlas_normalized_v01.png`，安全边距和脚点通过脚本检测。
- [x] 九动作原生 `data/native/animations/green_wanderer.tres`、角色卡与肖像 Registry 已绑定。
- [ ] 四方向和帧间动作质量、刀剑与 VFX 边缘人工补绘审核。
