# 平江府主干道：DNF 式三屏滚动验证

这是一张**独立 QA 测试地图**，不会替换当前序幕、战斗地图或 GameSession 正式关卡。背景为简化 SVG 地图布局（不是正式美术）。

## 打开方式

1. 使用 Godot 4.7.x 打开本目录的 `project.godot`。
2. 在编辑器中打开并运行 `res://scenes/pingjiang_scroll_qa.tscn`。
3. 用 **WASD/方向键**控制沈长风；或**鼠标左键**点击绿色有效地面指定目标。按 **F3** 切换可走区边界显示。
4. 从西端行至世界 X≈2400，再走到东端 X≈4600，观察 HUD 的滚屏偏移。

## 预期结果

| 人物世界脚点 | 可见窗口的世界 X 范围 | 世界偏移 |
| --- | --- | --- |
| X=200 | 0–1600 | 0 |
| X=2400 | 1600–3200 | -1600 |
| X=4600 | 3200–4800 | -3200 |

- 人物标准高度 200 世界像素，占位半径 24 世界像素，世界比例尺 80px/u。
- 全图场景真实世界尺寸 4800×1000；固定游戏视口 1600×1000，不拉伸 1600px 旧背景。
- 可走多边形为 X=50–4750, Y=635–930；边界和三处测量脚点由 `WuxiaMapDefinition` 定义。
- 镜头通过现有 `world_viewport_offset.gd` 计算，所有层及人物同步平移，固定 HUD 不跟随地图移动。
- 鼠标点击通过同一镜头偏移执行逆变换。

## 无界面验证

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_pingjiang_long_street.gd
```

测试加载真实分层 Resource，验证图像尺寸、地图多边形、FREE 连续可达、三屏镜头限位及坐标逆变换。该检查**不是**图像截图或人工视觉验收。

## 素材与管理

候选记录：`art-production/candidates/2026-11-02/pingjiang_long_street/WORK_ORDER.md`。当前三个纹理为代码生成的低保真 SVG 占位素材，不含受版权保护的商业游戏贴图，不应视为最终可商用美术验收。
