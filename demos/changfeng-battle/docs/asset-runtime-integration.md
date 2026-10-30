# 已提交美术的运行时接入（2026-10-30）

本次将仓库已有图片接入 Godot 场景，保留 `BattleModel` 唯一规则权威，不修改 CTB、多人队伍、卡牌合法性、连携与 CLASH 结算。

## 映射

| 角色 ID | 剧情角色 | 战斗角色材质 |
| --- | --- | --- |
| 0 | 沈长风 | 既有插画 atlas（待制作匹配动作图）；对话及阵容头像使用 `shen_changfeng_portrait.png` |
| 1 | 追镖首领 | 既有敌方插画 atlas（待制作匹配动作图） |
| 2 | 顾清霜 | `gu_qingshuang_24_pose.png`；头像使用 `gu_qingshuang_portrait_v1.png` |
| 3 | 青衫客 | `green_robed_wanderer_24_pose.png` |
| 4 | 黑衣刀客 | `black_blade_fighter_24_pose.png` |
| 5 | 夜行刺客 | `violet_dual_blade_assassin_24_pose.png` |

剧情对话的沈长风/老镖头分别使用已提交的高清单人立绘。菜单与第一段回忆镜头使用药谷原画，独立 HD-2D 战斗预览的远景使用雪山剑派原画。**雨夜追兵战斗不使用雪景**，保留断桥与雨夜光照，避免美术与剧情地点矛盾。

`scripts/hd2d_art_catalog.gd` 读取 6×4（每格 256×256）原图，针对每格边缘连通的白色底做运行时 matte cleanup，非纯白内层服饰不会统一抠空。生成的 `ImageTexture` 仅作渲染，交给既有 `hd2d_animation.gd` 使用同样的状态和事件时序；材质在加载后缓存。源图保持原样，便于后续非破坏性精修。缺失、尺寸不符时回退至既有插画 atlas，并打印 warning。

## 运行和回归

先执行导入，再分别运行：

```sh
godot --headless --editor --path demos/changfeng-battle --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_startup.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_story_encounter.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_art_integration.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
```

人工验收：序章进入老镖头对话可看到高清立绘；完成序章进入追兵战斗，顾清霜等四人的模型不是生成的青红同款，出剑/格挡/受击事件正确触发各行帧；雪景只在单独战斗预览出现，雨夜追兵维持暗色河桥。检查发丝白边、兵刃轮廓、透明区域及加载耗时。

## 尚未解决的美术边界

- 24 格是用户提交的动作姿势候选，不代表逐帧动画的动作连续性已达到正式版质量。仍需逐角色修正 foot anchor、服饰与兵刃连贯性、补关键帧与过渡帧。
- 白底连通清理可去掉明显背景，但不能替代 Photoshop/Krita 手工 alpha 精修；靠近边缘的白色衣物或浅色高光可能仍有毛边。
- 沈长风和追镖首领目前没有对应的 24 姿态匹配图，战斗用旧 atlas 回退；不能把高清剧情立绘直接作为透明战斗 Sprite3D。
- 原始素材的使用权声明仍按 `manifest.json` 中提供者信息由仓库所有者核实。设计稿及不透明 JPG 动作研究并未强制当战斗贴图使用。
- 当前开发环境只读，**尚未运行 Godot 导入和场景实机检查**；以上命令是待执行的验收程序，不虚报通过。
