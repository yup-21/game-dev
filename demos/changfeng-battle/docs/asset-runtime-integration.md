# 已提交美术的运行时接入（2026-10-30）

本次将仓库已有图片接入 Godot 场景，保留 `BattleModel` 唯一规则权威，不修改 CTB、多人队伍、卡牌合法性、连携与 CLASH 结算。

## 映射

| 角色 ID | 剧情角色 | 战斗角色材质 |
| --- | --- | --- |
| 0 | 沈长风 | `blue_swordfighter_pixel_study.jpg`（白底 6×4 设定动作图）；对话及阵容头像使用 `shen_changfeng_portrait.png` |
| 1 | 追镖首领 | `red_thread_fighter_pixel_study.jpg`（临时视觉映射，白底 6×4 设定动作图） |
| 2 | 顾清霜 | `gu_qingshuang_24_pose.png`；头像使用 `gu_qingshuang_portrait_v1.png` |
| 3 | 青衫客 | `green_robed_wanderer_24_pose.png` |
| 4 | 黑衣刀客 | `black_blade_fighter_24_pose.png` |
| 5 | 夜行刺客 | `violet_dual_blade_assassin_24_pose.png` |

剧情对话的沈长风/老镖头分别使用已提交的高清单人立绘。菜单与第一段回忆镜头使用药谷原画，独立 HD-2D 战斗预览使用雪山剑派原画，雨夜追兵战斗使用专门的断桥夜雨远景。场景图只作为远景层，战术桥面、树林、灯笼仍由 Godot 场景节点组成。

`scripts/hd2d_art_catalog.gd` 为六名战斗角色创建 6×4 atlas：顾清霜等四张 RGBA 图按 256×256 原格读取；沈长风和追兵首领的 2048×1373 JPG 设定图按比例切为 6×4，并针对每格边缘连通的白底做运行时清理。生成的 `ImageTexture` 交给既有 `hd2d_animation.gd` 使用相同的状态和事件时序，材质在加载后缓存。JPG 设定图属于预览素材，抠底和脚底锚点仍需美术检查；缺失或尺寸异常时回退至原插画 atlas 并打印 warning。

## 运行和回归

先执行导入，再分别运行：

```sh
godot --headless --editor --path demos/changfeng-battle --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_startup.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_art_integration.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
```

人工验收：序章进入老镖头对话可看到高清立绘；完成序章进入追兵战斗，六名角色均使用独立设定动作图，雨夜断桥原画只作为远景，出剑/格挡/受击事件触发各自动作行；雪山只用于独立战斗预览。检查发丝白边、兵刃轮廓、透明区域及加载耗时。

## 尚未解决的美术边界

- 24 格是用户提交的动作姿势候选，不代表逐帧动画的动作连续性已达到正式版质量。仍需逐角色修正 foot anchor、服饰与兵刃连贯性、补关键帧与过渡帧。
- 白底连通清理可去掉明显背景，但不能替代 Photoshop/Krita 手工 alpha 精修；靠近边缘的白色衣物或浅色高光可能仍有毛边。
- 沈长风和追镖首领的两张 JPG 设定图不是专门交付的战斗精灵图；白底清理、动作连贯性与追兵首领的正式角色对应关系仍需审核。
- 原始素材的使用权声明仍按 `manifest.json` 中提供者信息由仓库所有者核实。设计稿及不透明 JPG 动作研究并未强制当战斗贴图使用。
- 本次本地 Godot 4.7.2 定向验证覆盖导入、HD-2D 启动、序章遭遇、六人美术映射及窗口序章流程；完整规则套件未运行。
