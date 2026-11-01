# 老镖头 · 第一幕美术制作工作单

- asset_id: `escort_elder`
- target_usage: `story`
- 角色卡身份来源：`demos/changfeng-battle/data/native/characters/escort_elder.tres`
- 身份锚点：负伤灰发、墨蓝旧袍、绢帛
- 源图：`portrait_escort_elder_fullbody_v01.png`、`pose_escort_elder_injured_v01.png`
- 来源：原创图像生成；Prompt 见同批 `CHAPTER_ONE_PROMPTS.md`
- 原始尺寸：透明立绘 1024×1536；受伤姿态 1536×1024
- 正式运行时目标：`WuxiaCharacterDefinition`（静态剧情 Pose）
- 目前动作：剧情静态坐姿（不参与第一幕战斗）

## 制作状态

- 分支：`art/chapter-one-candidates-20261101`，基于 #83，**非批准资产**。
- 状态：`concept / requires technical cleanup`。不得标注 `approved` 或替换 main 现有运行资源。
- 图像生成工具：ChatGPT built-in image generation；具体模型版本、seed 未提供。
- 人工审核：身份一致性、商业权属、四方向、动画质量、实机截图均待完成。

## 尚未通过的检查

- [ ] 四视图设定板、身份锁定和旧图风格一致
- [ ] 图像真实 Alpha 与无色边，去除残余底色
- [ ] 破庙剧情摆位、绢帛与老镖头对话姿态吻合
- [ ] Godot 编辑器手工导入、角色卡与肖像 Registry 全链路加载
- [ ] 战斗/剧情与 1600×1000、1440×900 截图验收
- [ ] 商用授权、造型近似、负责人审批

## 结论

原始生成图已归档供修订；**不得直接作为正式战斗 Atlas**。技术处理通过后再导出规范化运行 PNG，保留原稿和版本关系。
