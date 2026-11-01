# 夜行刺客 · 第一幕美术制作工作单

- asset_id: `night_assassin`
- target_usage: `battle / story / HUD`
- 角色卡身份来源：`demos/changfeng-battle/data/native/characters/night_assassin.tres`
- 身份锚点：紫黑轻装、双短刃、袖针
- 源图：`portrait_night_assassin_fullbody_v01.png`、`sprite_night_assassin_atlas_source_v01.png`
- 来源：原创图像生成；Prompt 见同批 `CHAPTER_ONE_PROMPTS.md`
- 原始尺寸：透明立绘 1024×1536；Atlas 原稿 1536×1024（6×4，24 姿势）
- 正式运行时目标：`WuxiaCharacterDefinition` + `WuxiaActorAnimationProfile`
- 目前动作：idle 2 / move 4 / attack 3 / guard 2 / hit 2 / evade 3 / skill 3 / combo 3 / defeat 2

## 制作状态

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
