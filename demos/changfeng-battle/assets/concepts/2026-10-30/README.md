# 武侠美术素材批次：2026-10-30

本批由项目所有者提供，按用途分类存放。**只提交去重后的原始图片，不替换任何现有资源、不更改游戏逻辑。**

- 角色动作参考：4 张 1536×1024 RGBA PNG，画面按 6×4 排布（24 个*候选姿势格*）。
- 角色画风和立绘参考：3 张精细绘制的 3×2 设计稿 + 3 张较低像素化的 6×4 动作参考（全部为不透明 JPG）。
- 场景概念：2 张 2048×1143 JPG（白天药谷村落、雪山剑派平台）。

## 文件清单

| 文件 | 类型 | 尺寸 | 画面排布 |
| --- | --- | --- | --- |
| [`characters/gu_qingshuang_24_pose.png`](characters/gu_qingshuang_24_pose.png) | character_pose_sheet | 1536x1024 | 6x4 |
| [`characters/green_robed_wanderer_24_pose.png`](characters/green_robed_wanderer_24_pose.png) | character_pose_sheet | 1536x1024 | 6x4 |
| [`characters/black_blade_fighter_24_pose.png`](characters/black_blade_fighter_24_pose.png) | character_pose_sheet | 1536x1024 | 6x4 |
| [`characters/violet_dual_blade_assassin_24_pose.png`](characters/violet_dual_blade_assassin_24_pose.png) | character_pose_sheet | 1536x1024 | 6x4 |
| [`character_style/red_thread_fighter_painted_study.jpg`](character_style/red_thread_fighter_painted_study.jpg) | character_design_study | 2048x1373 | 3x2 |
| [`character_style/red_thread_fighter_pixel_study.jpg`](character_style/red_thread_fighter_pixel_study.jpg) | stylized_pose_study | 2048x1373 | 6x4 |
| [`character_style/blue_swordfighter_pixel_study.jpg`](character_style/blue_swordfighter_pixel_study.jpg) | stylized_pose_study | 2048x1373 | 6x4 |
| [`character_style/blue_swordfighter_painted_study.jpg`](character_style/blue_swordfighter_painted_study.jpg) | character_design_study | 2048x1373 | 3x2 |
| [`character_style/teal_herbalist_painted_study.jpg`](character_style/teal_herbalist_painted_study.jpg) | character_design_study | 2048x1373 | 3x2 |
| [`character_style/teal_herbalist_pixel_study.jpg`](character_style/teal_herbalist_pixel_study.jpg) | stylized_pose_study | 2048x1373 | 6x4 |
| [`scenes/snowy_sword_sect_courtyard.jpg`](scenes/snowy_sword_sect_courtyard.jpg) | scene_concept | 2048x1143 | — |
| [`scenes/mountain_herbal_workshop_day.jpg`](scenes/mountain_herbal_workshop_day.jpg) | scene_concept | 2048x1143 | — |

各图片的原始上传文件名、Git blob SHA 和状态见 [manifest.json](manifest.json)。

## 去重与导入边界

- 对照 `main` 上现有 `assets/characters/concepts/`，没有重新提交现有的 4×2 动作参考稿；本批 6×4 候选图为不同的新增源图。
- 本次仅保留 `顾清霜武侠动作图集-1(3).png`，排除姿态高度相似的 `顾清霜武侠动作精灵图-5(3).png`。
- PNG 虽有 alpha 通道，发丝、兵刃和彩色边缘仍需人工验收；JPG 没有 alpha，需要抠图和统一背景。
- 6×4 格内是动作姿势参考，不能直接当成完整流畅的 24 FPS 逐帧动画；需要检查帧边距、衣袖武器越界、角色比例、脚底锚点，并补中间帧。
- 两张场景均为**单张氛围概念图**，不能直接视为分层、带碰撞或具有可走区域的 Godot 战斗地图。
- 尚未导入运行场景，未修改 `BattleModel`、CTB、卡牌和连携行为。素材的授权、正式角色命名和可用性由项目维护者验收。

此目录定位为美术参考素材，不应被运行时资源扫描逻辑自动视为成品。
