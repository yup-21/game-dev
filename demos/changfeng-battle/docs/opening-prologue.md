# 序章：雨夜残镖 — 开场、过场与经典武侠对话

## 依据与定位
本演示参考《长风浮生录_完整游戏企划案》第一幕“微末草莽，风雨入局”：
- 主角出身破落武馆或偏远山庄，背负血仇；
- 偶遇濒死镖头，得到《太虚引气残篇》；
- 江湖名门与朝廷围绕残篇的阴谋是后续主线，不在短演示中提前揭晓；
- 风格使用素雅水墨、江南暮秋雨夜，与“英雄无百岁，刀剑不饶人”的立意一致。

**注意**：本次“荒道破庙、具体人物对白、马蹄追兵、两种对答”等是基于第一幕写的原创序章示例，不是企划书已经确定的精确场景或台词。后续正式文本可以直接替换 `data/opening_story.json`。

## 已实现的完整流程
`opening.tscn` 现为 `project.godot` 默认启动场景。

1. **主菜单**：水墨群山、落日、云雾与动态细纹；“初入江湖”、“断桥论剑”、“群侠试炼”、“退出游戏”四个真实可用按钮。
2. **过场**：3 个有独立时长的雨夜镜头，雾、山、破庙和断镖车以原始 Godot 绘图、镜头淡入淡出及雨线构成。可等待自动切镜，也可空格/回车/鼠标推进，Esc 或 S 跳过。
3. **可操作叙事场景**：主角在破庙外自由短距离行走（WASD / 方向键），靠近镖头按 E 或点击目标开始交谈。
4. **古典武侠对话**：独立人物名牌、头像画框、墨色对白条、逐字呈现。空格/回车/点击先补全文字再进入下一句。分支可鼠标选择，或按数字 1/2。
5. **序章完成**：两种回答最终都会取得《太虚引气残篇》，显示获得残卷和追兵即将到来的演出画面，随后可进入原始双人 `battle.tscn` 或多人 `party_battle.tscn`。

## 框架设计
- `scripts/opening_story.gd` 是纯数据状态机：`menu → cinematic → explore → dialogue → complete`。负责验证数据、当前镜头、分支选择、取得残卷事件等，不依赖 UI 的帧率。
- `data/opening_story.json` 独立声明镜头与对白节点；每个对白含 `id`、`speaker`、`text`、可选 `next`、`choices`、`event`。有条件的对答由 `choices: [{text, next}]` 跳转，不用为一段新剧情编写独立按钮逻辑。
- `scripts/opening_flow.gd` 只负责绘画、输入、动画和场景跳转。所有水墨、雨丝、简易人物肖像均为本次原创 CanvasItem 程序化绘制；不使用未授权图片或外部字体。
- 本次开场仅提供**剧情物品标记**，不把残篇当作已经接入完整角色库存/寿元系统的道具；实际取得物品的数据持久化将在角色系统落地后统一接入。
- 新剧情的后续章可以复用脚本与 JSON Schema（现版过场和对话均为线性+分支图；复杂条件选择、存档和多地图切换需要后续添加）。

## 运行与检查
```bash
godot --path demos/changfeng-battle
godot --headless --path demos/changfeng-battle --script res://checks/test_opening_story.gd
godot --path demos/changfeng-battle -- --opening-visual-check
godot --path demos/changfeng-battle res://battle.tscn -- --tingfeng-visual-check
godot --path demos/changfeng-battle res://battle.tscn -- --wuxue-visual-check
```

`--opening-visual-check` 会运行真实窗口截图检查，输出 `captures/opening-title.png`、`opening-cinematic.png`、`opening-explore.png`、`opening-dialogue.png`、`opening-choice.png`、`opening-complete.png`。战斗图形检查需要显式指定 `res://battle.tscn`，否则默认启动的是序章菜单。还应运行战斗 `checks/verify.ps1`，以保证切换到战斗后仍正常操作。

**验证状态**：GitHub 代码写入环境未安装 Godot，以上实机视觉和 headless 运行检查由本地 CI/测试人员执行，不能据此报告“已通过”。

## 变更边界
此 PR 只新增序章状态机、菜单/对话/动画、剧情数据和测试，同时更换项目默认入口。没有更改 `BattleModel`、`CombatRules`、AI、卡牌、CTB 或战斗场景内的可操作流程。
