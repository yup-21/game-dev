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
- [ ] 验证完整 CI/本机 Godot 测试，并记录本次真实结果（不可继承旧 PR 的 PASS）。
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
