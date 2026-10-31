# 长风浮生录 Demo 重构路线与测试基线

> 基于 `main@8d1486b4b27dd06aaae78739ca13740a5169074d` 创建长期分支 `refactor/battle-architecture-consolidation`。
> 本文是实施 checklist；没有完成验证的项目一律不能打勾。

## 分支与提交政策

- 所有 R1–R7 的重构提交进入 `refactor/battle-architecture-consolidation`；`main` 在用户要求合并前不变。
- 避免在同一提交里进行逻辑改造、文件搬迁和画面改版。先建立测试，后重构，再删除兼容代码。
- 每次提交保留清晰 subject（`docs:`、`refactor(battle):`、`refactor(ui):` 等），记录验证命令、实际结果和剩余限制。
- 有新的 `main` 更新时先检查影响和可能冲突，再决定怎样同步；绝不强推或覆盖已有分支历史。

## R1 — 冻结已知架构和回归基线

- [x] 从最新 `main` 创建长期重构分支。
- [x] 新增 [ARCHITECTURE.md](ARCHITECTURE.md)，明确定义唯一正式入口、权威模型、GRID/FREE 实情、派生/CTB/Chain 契约。
- [x] 新增此路线图，梳理后续模块和验收。
- [x] GitHub Actions Godot 4.7.2 自动化已验证（R6 head `d8363d19`，运行 #41092291979 的 `godot-ui` 为 success）；本地手动 GUI 不在本项内。
- [ ] 做一次 1v1 + 序章 3v3 人工回归录像，确认 PR #65 的修复没有倒退。

退出标准：有明确契约文档、完整当前基线 SHA，测试不再以历史 Demo 的截图代替正式战斗验证。

## R2 — 提取正式战斗输入与命令控制

从 `hd2d_battle.gd` 拆出 **`BattleInputController`** 和 **`BattleCommandController`**：前者处理鼠标、卡牌/阶段选择和 FREE 落点意图；后者统一 `request/submit`、合法性、错误反馈与版本管理。不改 `BattleModel` 的协议；逐步给旧 UI 增加薄适配器。

验收：同种子请求 trace 等价；卡牌暂不可用时仍存在手牌区；重复点击不会双扣费；GRID/FREE 输入均正常。

## R3 — HUD 子组件化

分离扇形手牌、CTB 跑轴、交锋响应、角色头像/状态和武学切换；根节点只协调快照更新，细节由视图组件负责。保留已有素材、缩窄跑轴和头像贴轴运动。

验收：1v1 与 3v3 操作均完整；手牌置灰/提示准确，派生牌与阶段能力不混淆；测试 `test_hd2d_hand_visibility.gd`、`test_hd2d_ctb_rail.gd` 不退化。

## R4 — 演出时序与 ticket 生命周期

统一语义事件动画队列、自由移动路径播放、VFX/SFX 和 `acknowledge_animation(ticket)`；可跳过演出而不再次结算。动作层不允许直接修改 HP、牌区、CTB 或权限投影。

验收：动画正常/中断/跳过/切场景/死亡均不锁死；每个 ticket 最多确认一次；`Chain` 结算和演出顺序不会混为一谈。

## R5 — 正式战斗纯 2D 化

将可见场景稳定在 `Node2D`、`Camera2D`、插画背景、脚点演员、`VFX2D`；独立清理 `_build_world` 的不可达旧 3D 分支，避免一次提交同时删旧测试。必须逐项检查 `Camera3D`、`Node3D` 兼容依赖。

验收：鼠标落点、移动路径、角色遮挡、第一幕背景、朝向、剑光和 3v3 HUD 在真实画面中正确。

## R6 — GRID/FREE 空间接口收敛

建立统一几何 facade：落点、路径/预算、距离、LOS、自动接近、强制位移。GRID 复用原格子规则；FREE 复用当前 `BattleSpatialService` 算法。**本阶段不切换到 NavigationPolygon，以维持验证等价性**。

验收：所有 FREE 独立测试与旧 GRID 同时通过；拥挤两人/多人落点不会卡死；不能安全重锚时拒绝切模式，资源状态不变。

## R7 — 遗留 Demo、资产和文档清理

标明 deprecated 的历史视图，确认测试依赖后才搬迁；整理图片/音效来源与人物注册引用；将现有说明与实际 2D 路径对齐。不得删除玩家已提交的原创素材。

验收：正式入口唯一，旧回归可运行；无悬空 `res://` 路径，无角色 ID 特殊硬编码新引入。

## 最小回归矩阵

在仓库根运行（按实际安装的 Godot 可执行名调整）：

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_dual_spatial_mode.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_continuous_battle_space.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_move_and_attack.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_free_martial_movement.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_free_space_ai.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_derived_wuxue_decks.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_multi_school_switch.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_hand_visibility.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_auto_pass.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_parties.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_demo_flow.gd
```

以上为计划命令，**不是本次测试执行结果**。 Windows 可改用 `demos/changfeng-battle/checks/verify.ps1` 各 Stage，注意脚本自身参数规范。

每个阶段至少核对：

| 场景 | 不得退化的行为 |
| --- | --- |
| 单人 FREE | 自由落点、自动接近、距离/LOS、避锋落点与费用 |
| 多人 FREE | 角色圆形碰撞、拥挤导航与 AI 决策 |
| GRID | 15×10 正交棋盘、原移动/攻击和切换安全 |
| 牌组/武学 | 试探→追风、变锋阶段、流派切换、手牌可见 |
| CTB/Chain | 无限等待保护、自动 Pass、有限 LIFO 和双边规则 |
| 画面 | 战场角色朝向正确、原画正常显示、CTB 头像跑轴 |
| 序章 | 破庙背景不空白、追兵 3v3、战后结算重试 |

## 工期与开发顺序

粗估 R1–R7 约20–34个工作日（依赖 Godot 测试与美术项目现状）。优先 R1→R2→R3→R4→R5→R6→R7，每一个阶段形成可审核提交。架势条、绝招、动作型连续技属于完成结构治理后的新功能，另开功能提交。

参考：[ARCHITECTURE.md](ARCHITECTURE.md) · [项目入口](../README.md)。


## R2–R7 实施结果（2026-10-31）

| 阶段 | 接入代码 | 对应回归 |
| --- | --- | --- |
| R2 | `battle_input_controller.gd`、`battle_command_controller.gd`、`battle_command_dispatcher.gd` 统一点击意图、人类输入门控及版本化动作投递 | `test_battle_input_controller.gd`、`test_battle_command_dispatcher.gd` |
| R3 | `battle_hand_view.gd` 实际手牌可见性/置灰与扇形布局；`battle_hud_status.gd` 状态、CTB、交锋投影；原 `hd2d_ctb_rail.gd`、`character_card_ui.gd` 保留职责 | `test_battle_hand_view.gd` 与旧 HUD/CTB 用例 |
| R4 | `battle_presentation_coordinator.gd` 管理单次动画 ticket、S 跳过和取消，规则已结算后不二次执行 | `test_battle_presentation_coordinator.gd` + 自动 Pass/交互 |
| R5 | `Node2D + Camera2D` 正式场景、`battle_vfx_2d.gd`、`Sprite2D` 演员、震动偏移坐标校正；旧 3D 构图从正式路径删除 | `test_battle_pure_2d.gd`、`test_hd2d_startup.gd` |
| R6 | `battle_spatial_facade.gd` 统一 GRID/FREE 查询，基础攻击、自由攻击、自动接近和移动预览接入；不更换 MapBake/AStarGrid2D | `test_battle_spatial_facade.gd` + 已有双模式测试 |
| R7 | 文档、历史模块标记、静态 `res://` 资源及授权核查、PowerShell `-Stage Refactor` 回归集 | [审计](REFACTOR_ASSET_AUDIT.md) · [遗留边界](LEGACY_COMPAT.md) |

**现有自动化证据**：R6 提交 `d8363d19` 对应 GitHub Actions [#41092291979](https://github.com/yup-21/game-dev/actions/runs/41092291979) 的 `godot-ui` 已全部通过。后续 R7 提交必须重新执行完整 CI，不得沿用旧结果。

**仍未验收的人工工作**：1v1 和序章 3v3 的手动鼠标/键盘全流程录像、动画/美术质量、音效时序。视觉截图工作流不能替代人工试玩；因此 R1 的「人工回归录像」保持未打勾，PR 在视觉验收前维持 Draft。

架势条、无敌帧、连续技打断、终式和完整四方向逐帧素材属于新增玩法与美术制作，**不属于**本次结构 R1–R7 可宣称完成的功能。

## R8 — 正式场景职责拆分（2026-10-31）

- `BattleWorld2D` 持有 Camera2D、手绘地图、Sprite2D 演员和已经结算的移动路径。正式场景保留旧字段别名以维持回归兼容；逻辑位置仍由 BattleModel 唯一提交。
- `BattlePresentationPlayer` 持有动画驱动、VFX 与 ticket 协调，不允许写规则；旧 `animation_driver`、`presentation` 字段仍指向同一实例。
- `BattleHUDView` 创建完整的 HUD 节点树、状态栏、CTB、手牌和头像，绑定原有交互回调，并负责快照投影；正式场景仅保留兼容字段别名及命令按钮逻辑。
- R8 live-scene 测试：`checks/test_battle_r8_components.gd`。本阶段不改变卡牌规则、GUI 素材、行动顺序或剧情。

## R9 — 统一 GRID/FREE 空间契约（2026-10-31）

- `BattleSpatialFacade.plan_free_landing` 负责统一 FREE 选点、圆形避让、量化与可达路径预检；移动和武学身法仍在 `CombatRules` 判断时机、预算与费用。
- `check_attack_approach` 对自动接近的量化坐标重新验证站位、距离和 LOS；GRID facade 的远距 LOS 也按轴线校验，基础邻接攻击规则保持不变。
- `forced_displacement` 与 `forced_move_preview` 统一为轴向遇阻停止的几何方案，并由 `CombatResolver` 直接消费，避免界面预览与真实击退走不同路径。
- `BattleModel.preview_free_path` 使用 battle ID、revision、actor ID 与量化落点作为单条缓存键，避免静止鼠标每帧重建可见性图；提交或重开战斗后自动失效。
- 新增 `checks/test_battle_spatial_r9.gd` 和 CI 检查。当前 FREE 实现为 MapBake + AStar2D 可见性图，不是 AStarGrid2D 或 NavigationPolygon。

## R10 — 数据驱动动作时序（2026-10-31）

- `data/action_timelines.json` 定义九种基础表现动作的起手、有效、收招和视觉窗口，并声明语义事件到动作段的映射。
- `BattleActionTimeline` 验证总时长、阶段、cancel/reaction/visual-invulnerable 窗口与关键帧 cue，兼容已有动画长度。
- `HD2DAnimation` 消费统一动作配置并公开 `action_phase()`、`visual_window_open()` 与 `drain_action_cues()`；`BattlePresentationPlayer` 维护有界 cue 缓冲。
- **明确约束**：所有时间窗当前仅用于演出、调试与未来技法配置，绝不自行授权实战无敌帧、格挡命中、派生卡或实时输入。真正带规则的动作反应必须另经 BattleModel 版本化动作协议设计和测试。
- 新增 `checks/test_battle_action_timeline.gd` 和 CI 步骤；保持 CTB、卡牌、费用、交锋结算、原场景和角色素材不变。

### R8 HUD 收口补充

HUD 的 2D CanvasLayer 创建、布局、头像/控制绑定和完整饰件节点树已由 `BattleHUDView.build()` 负责，`HD2DBattle._build_ui()` 只获取返回的兼容句柄。节点名称和事件回调与之前保持一致；真正的战斗决策仍走 Controller/Dispatcher，HUD 不修改模型。

## R11 — 定义驱动武学扩展（2026-10-31）

- `SchoolCatalog` 不再将已有 10 门流派、20 张招式、7 个连携和 3 种状态作为数量上限；仍严格验证字段、引用、费用、牌组和连携效果。
- `ComboResolver` 执行连携定义中的 `max_activations_per_action`，默认值为 1；既有连携仍只触发一次。
- `checks/test_catalog_extensibility.gd` 动态新增第 11 门流派、两种核心式、一套连携和 2 次触发上限，不修改正式游戏资源。
- 不改变 CTB、GRID/FREE、卡牌数量或旧关卡与演出行为。下一阶段解除角色身份与战斗 actor ID 的绑定。
