# 非像素插画式 HD-2D：序章与独立战斗场景

本轮画面方向：**保留 HD-2D 的斜俯视立体舞台、景深层次与战斗 UI 布局，但不采用像素美术**。角色和 UI 使用原创的平滑插画/图形小说风；不复制《逸剑风云决》或《歧路旅人》的商业素材。

## 可试玩的两条入口

| 入口 | 场景 | 功能 |
| --- | --- | --- |
| 默认启动 → 初入江湖 | `opening.tscn` | 雨夜三段过场、WASD 官道探索、镖头分支对白、获得残篇、剧情追兵 |
| 主菜单 → 插画立体战场 · HD-2D | `battle_hd2d.tscn` | 独立 15×10 斜俯视战场，插画人物、招式牌、事件动画、剑招 VFX |
| 序章完成 → 插画战斗场景预览 | `battle_hd2d.tscn` | 可直接比较新旧画面，不影响故事已写好的多人遭遇 |
| 序章完成 → 迎战追兵 | `party_battle.tscn` | 保留现有剧情会话、多人战斗结算与存档相关流程 |

**边界：**目前插画战场是独立双人 `BattleModel` 演示，尚未替换 `party_battle.tscn` 的多人剧情遭遇；主线“迎战追兵”仍走原有规则及会话。不能将“预览插画战场”当成已经接通的剧情遭遇。

## 美术与场景实现

- `scripts/hd2d_illustrated_factory.gd`：两名原创武侠人物、透明 RGBA 6 列 × 4 行 Sprite Sheet，单帧 160×200；每帧用 SVG 曲线、服饰明暗渐变、剑刃、发丝等矢量要素绘制，通过 Godot Image 在运行时光栅化。不是像素画。
- `scripts/opening_flow.gd`：菜单人物、雨夜过场人物、可操作探索人物及对话头像复用同一张插画 Sheet；加雨水积洼、灯笼光晕、湿地反光、电影黑边与轻微分镜位移。故事的对白、选项、触发半径和数据状态机保留。
- `scripts/hd2d_battle.gd`：Sprite3D 使用线性纹理过滤及插画尺寸；新增战斗开场标题卡。保持 `BattleModel`、`EnemyAI`、动作合法性、CTB / CLASH / 连携计算和动画确认时序不变。
- `scripts/hd2d_scenery.gd`：松林及远山改为软轮廓实体；战场草地拼缝收拢并加入苔藓/石块，保持权威地图格点、河流与可通行区域不变。
- `scripts/hd2d_animation.gd` 与 `scripts/hd2d_vfx.gd`：继续共享 6×4 动画帧索引、语义事件驱动的出招/格挡/受击/身法/连携剑光。

插画是可以运行的原型资源，仍需真正的角色原画、场景贴图、帧间动作与局部 Shader 美术精修。现阶段没有完整原创手绘逐帧动画，也不是已验收的商业级最终画面。

## 启动及检查

使用 Godot 4.x 打开 `demos/changfeng-battle/project.godot`；默认进入新菜单。

```sh
# 导入资源并检查 GDScript 解析
godot --headless --path demos/changfeng-battle --editor --import --quit

# 新战斗场景：角色尺寸、透明背景、动作队列、剑招特效
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_startup.gd

# 导出真正透明的插画 Sprite Sheet 到 Godot user:// 目录
godot --headless --path demos/changfeng-battle --script res://checks/export_hd2d_sprites.gd

# 实际窗口渲染（保留截图用于对比）
godot --path demos/changfeng-battle -- --opening-visual-check
godot --path demos/changfeng-battle res://battle_hd2d.tscn
```

`checks/opening_visual_check.gd` 会检查菜单的 HD-2D 预览入口、插画尺寸、过场/探索/对话/结尾并导出窗口截图。

## 后续验收优先级

1. 在真实 Godot 窗口中检查透明 alpha、角色足部是否落地、Sprite3D 排序、中文字体与 UI 重叠。
2. 将程序生成的静态矢量人体替换为授权明确的手绘帧素材，保留 6×4 帧布局或者显式迁移动画索引。
3. 为场景补充非像素 2.5D 地形与环境贴图（桥栏、官道、破庙、镖车）、近中远景色彩分级及灯光。
4. 再设计多人剧情遭遇向 3D 展示层的桥接：权威模型仍由原多人战斗系统维护，不在画面层重复维护规则。
5. 对比原 `battle.tscn` / `party_battle.tscn` 的 CTB、卡牌、连携及存档回归，跑图形截图与帧时间预算。

当前执行环境没有 Godot 可执行文件，以上命令提供给有引擎的开发机或 CI 运行；本轮没有声称通过实机渲染。
