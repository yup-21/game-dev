# 雨夜追兵 · 镂金青玉战斗 HUD（第 2 期）

本期在 PR #42 的 **真实 CTB 集气跑轴** 和已有精细卡面基础上继续迭代；没有新增任何卡牌插画或修改牌组。

## 独立素材

| 路径（相对 `assets/ui/ornaments`） | 用途 |
| --- | --- |
| `hand_fan_tray.svg` | 底部扇形手牌的透底暗玉托盘、弧线与角花 |
| `card_frame.svg` | 覆盖原本卡面插画的可缩放细金边，**不替换插画** |
| `portrait_frame.svg` | 左侧 58×65 角色头像框 |
| `ctb_rail.svg` | 右侧真实 CTB 纵轴的半透底纹、上下菱纹 |
| `ctb_marker_frame.svg` | 右侧头像圆形外圈；同盟青绿、敌人暗赤、行动者金色 |
| `chapter_filagree.svg` | 顶部章节标题两侧金线、回纹 |

以上为透明 SVG 原生矢量资源，和仓库现有 SVG 资源采用相同的 Godot 导入方式。布局不依赖任何参考图的嵌入式截图。

## 交互与约束

- 手牌：保留 `CardUI.make_card()`、每个 `usage_id`、按键/鼠标命令、禁用牌和原有横向 `ScrollContainer`。HBox 仍决定逻辑排序；`_layout_fan_cards()` 仅给 Button 加受限角度（±11.5°）和轻微上下偏移。选中卡抬升，鼠标 hover 沿用原有缩放。
- 人物：左侧状态仅显示我方，头像放在独立可点击 slot 内；框纹 mouse-ignore，不影响查看角色详情。生命和真气仍直接使用战斗 snapshot。
- 集气：`hd2d_ctb_rail.gd` 沿用 `gauge_y()`、`set_state()` 和真实 actor gauge。我方头像位于轴线左侧、敌方位于右侧，头像内缘直接贴合纵轴；**同阵营同一集气值允许完全重叠，不做防碰撞错位**；行动者通过金色描边和较高 z-index 优先展示。每次收到新的 CTB snapshot 后，在 0.32 秒内以 ease-out 垂直滑动至真实位置；中途再次变化则从当前画面位置重新补间，重复快照不会重启动画。仅修改显示层，不连续推进集气、不改变 CTB 时序。轨道底纹、阵营色及出手/集气标签保留。
- 战场：遮罩透明，从中间逐渐淡出；扇形托盘高度 255 px，CTB 宽度 108 px，不新增全屏面板；1600×1000 截图和逻辑回归交给 GitHub Actions。

## 验证

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_ornament_hud.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_unified_hud.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_ctb_rail.gd
```

`wuxia-hud.yml` 仍生成真实 1600×1000 战斗 / 选牌 / 角色详情截图以供人工验收。小屏幕或超长手牌通过原有横向滚动访问。
