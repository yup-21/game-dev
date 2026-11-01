# 荒道破庙 · 第一幕剧情场景工作单

- asset_id: `ruined_temple`
- 使用：`rain_escort_prologue` 剧情地图
- 源图：`environment_ruined_temple_master_v01.png` (1586×992)
- 逻辑画布：1600×1000，16:10，1440×900 裁切另测
- 角色足点：沈长风约 (350,705)，老镖头约 (1050,560)
- 通行区域：旧剧情 `player_bounds=Rect2(155,345,1260,410)`；PNG 颜色**不用于碰撞**。
- 风格锚点：暮秋三更、江南荒道、破庙、倒伏镖车、冷雨夜、微弱暖灯。

## 制作状态

- 分支：`art/chapter-one-candidates-20261101`，基于 #83，**非批准资产**。
- 状态：`concept / requires technical cleanup`。不得标注 `approved` 或替换 main 现有运行资源。
- 图像生成工具：ChatGPT built-in image generation；具体模型版本、seed 未提供。
- 人工审核：身份一致性、商业权属、四方向、动画质量、实机截图均待完成。

## 分层合同

目标输出 `background / ground / foreground / weather` 四幅同源同原点 1600×1000 RGBA 与合成预览；当前仅母版，分层尚需执行 `art-production/tools/prepare_chapter_one_assets.py --write` 并做逐像素重组与前景遮挡验收。不能将母版冒充四个可独立编辑的原画层。旧章场景与游戏纹理未更换。

- [ ] 分层导出图被纳入 Git 并验证叠加一致
- [ ] 老镖头与镖车不穿插、前景遮挡自然
- [ ] 神庙门口及地面障碍的地图 Resource 几何对齐
- [ ] 2 种分辨率的真实 Godot GUI 截图
- [ ] 来源/商用权属与负责人审批
