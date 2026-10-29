# 原创水墨战斗表现层

本次美术改造为 **原创程序化绘图**，仅使用 Godot 4 的 CanvasItem 绘制 API，没有引用第三方角色立绘、商业图片或字体文件，也不依赖线上素材服务。项目保留原来的 Godot 系统字体配置。

## 画面设计
- **战场**：远山、宣纸颗粒、河面波纹、桥面木纹、两岸芦苇、水岸细节。世界坐标、格子尺寸（70×39）、棋盘视口和命中区域保持原样。
- **角色**：双色武侠服饰、发冠、佩剑、呼吸微动、脚下气场与行动指示环。原本的血量、护体和状态显示仍保留。
- **卡牌与 HUD**：更明确的攻击／身法／其他用法色带，纸纹描边、选中高亮、衍生卡小印章；按钮反馈及阶段能力区（从合法的 USE_ABILITY 操作获取）。
- **动作**：通过已有 ATTACK_DECLARED、DAMAGE、SHIELD、MOVE、COMBO_TRIGGERED 等事件显示斩击残影、星火、护体圆弧和闪避速度线。所有计时仅作用于画面，**不会推进 CTB 或修改 BattleModel 的状态**。

## 美术素材与授权
- `scripts/battle_art.gd` 是本次提交原创的程序化矢量插画与特效，素材代码随项目仓库的许可证使用；无外部依赖和第三方著作权归属需要追踪。
- 没有复制网页上参考游戏的图片、角色或 UI 资产。
- 后续若替换为开源图片，需逐一记录源 URL、作者、授权许可证、修改范围和署名义务，不得以“网上免费”代替授权确认。

## 测试与截图
```powershell
godot --headless --path demos/changfeng-battle --script res://checks/test_ability_framework.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_generated_cards.gd
godot --path demos/changfeng-battle res://battle.tscn -- --ink-visual-check
```

最后一条指令通过实际窗口捕获 `res://captures/ink-action.png`、`ink-attack.png`、`ink-ability-tray.png`，并核对可点击阶段能力。还应以同样的 `res://battle.tscn` 显式场景运行 `--tingfeng-visual-check` / `--wuxue-visual-check`，验证原有按键、卡牌分支、目标落点、动画确认和战斗结果。

这些检查需要 Godot 环境执行；没有在代码提交环境虚构通过结果。

## 兼容边界
这次只修改 Node2D 展示层及新增独立美术模块、视觉回归脚本。默认卡组、状态逻辑、事件触发、资源消耗、AI、受击判定、目标选取的权威坐标和数值没有修改。美术代码使用确定性的正弦波纹与序号噪声，不读取或扰动战斗 RNG。

`USE_ABILITY` 阶段在手牌上方展示为独立按钮。阶段多目标时先提示选择落点／目标；连锁目标沿用右侧已有响应层列表。装备超过三个阶段能力时，本版只展示前三项，后续可以改为分页。
