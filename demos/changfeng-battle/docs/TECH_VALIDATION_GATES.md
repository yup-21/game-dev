# Demo 技术验证验收门槛（P0–P4）

> 适用于长期重构分支 `refactor/battle-architecture-consolidation`。  
> 目标是验证可复用的游戏生产基础，**不把 Godot headless PASS 等同于完成试玩验收**。  
> 当前暂不实施战斗中途存档、版本迁移或存档 UI；优先保证战斗消耗品、装备词条和现有规则回归。

## 验证状态

| 里程碑 | 可复现实证 | 当前状态 |
| --- | --- | --- |
| P0 规则与 CI 基线 | 完整 regression、三种地图拓扑、1v1/3v3 人工交互和帧分析 | **自动化回归通过；GUI 手动待验收** |
| P1 战斗策略与动作机制 | 派生连击、交锋响应窗口、架势/取消的权威规则原型 | **权威规则、取消、连携与独立 VFX 提示已通过全量 CI**；目标 PC 实机性能与动作观感待验收 |
| P2 美术生产管线 | 一名主角 + 一名敌人的连续动画、导入检查及实机截图 | **资产清单、导入合同与 CI 已落地；连续角色动画待验收** |
| P3 内容扩展闭环 | 武学/Buff/角色/装备/消耗品经正式战斗进出，回归通过 | **部分已接入**；R16–R17 回归通过，正式试玩仍待验收 |
| P4 可交付构建 | Windows 导出产物、资源打包检查、导出包 Smoke Test | **Windows/Linux Export CI 与 PCK Smoke Test 已通过** |

## P0 固定自动回归

- 正式场景：`opening.tscn` → `battle_hd2d.tscn` → `demo_result.tscn`。
- 原有 `test_bridge_auto_battle.gd`：三个种子、六人 AI、权威模型完整对局；它只验证逻辑结算，不能证明 UI 不卡住。
- `test_spatial_topology_profiles.gd`：对比开阔、两列障碍、六人占位三种静态拓扑；检查路径端点、实际线段碰撞、绕路费用和重复查询确定性。
- `checks/fixtures/maps/*.json` 是**纯路径压力测试数据**，借用断桥资源完成 `MapBake` 校验。其画面和碰撞 mask 不匹配，**不允许作为正式玩家关卡**。
- 三种拓扑基准输出 `SPATIAL_TOPOLOGY` 的 p50/p95/max 查询耗时。CI 虚拟机性能会波动，因此耗时只作为历史信息，不按绝对毫秒断言 PASS/FAIL。

运行：

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_spatial_topology_profiles.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_bridge_auto_battle.gd
```

## P0 人工验收矩阵（必须在目标 PC 的 Godot GUI 完成）

| 场景 | 操作与断言 | 结果 |
| --- | --- | --- |
| 1v1 FREE | 选中、自由落点、路线预览、超预算立即隐藏路线 | [ ] |
| 1v1 FREE | 卡牌自动接近并出招；障碍阻挡不会扣除非法资源 | [ ] |
| 3v3 FREE | 双角色贴身、狭桥拥堵、不同落点、AI 自动接近；无卡死 | [ ] |
| GRID 兼容 | M 切模式、无法安全切换时无副作用，旧行动可用 | [ ] |
| CTB / CLASH | 多人跑轴、交锋 LIFO、无牌自动 Pass、S 跳动画不会重复结算 | [ ] |
| UI / 动画 | 卡牌有效/置灰、正确朝向、脚点、受击/格挡动作、VFX 可辨 | [ ] |
| 剧情闭环 | 第一幕破庙非空白，追兵 3v3 → 胜败结算 → 重新挑战 | [ ] |
| 音效/资源 | 动画 cue、音效、透明边缘和动态资源引用逐项检查 | [ ] |

每次失败至少留存：构建 commit、Godot 版本、平台/显卡、地图、战斗种子、角色坐标、操作步骤、日志和录屏。

## 性能验收

必须先声明**目标测试机器**。暂以 60 FPS（16.67ms/帧）为设计目标，而非现有 CI 承诺。

- 在开阔地、复杂绕障和六人断桥上采集帧时间 p50/p95/p99、最长帧和 A* 查询次数。
- 静止鼠标、快速移动鼠标、自动接近、连续技能和六人同时存在分别采样至少 60 秒。
- 正常游玩目标 P95 帧耗时不高于 16.67ms；偶发长帧必须定位到具体函数/素材加载，而非只看平均 FPS。
- 连续 20 次完整人工战斗、0 次无法恢复的输入锁死或走位卡位；本门槛必须由 GUI 实测确认。
- 记录资源首次加载峰值和重复进战场耗时。

## 后续开发原则

1. **冻结一次规则真值**：`BattleModel` 写状态，`CombatResolver` 生效，`BattlePresentationPlayer` 只播放 ticket；动画窗不得偷偷决定命中或伤害。
2. **地图拓扑优先**：现有 FREE 为 `MapBake + AStar2D`，只有在多拓扑+GUI profiler 定量显示局限之后才考虑 `NavigationPolygon` 迁移。
3. **内容优先完成真实接线**：现有 Effect 类型内靠 JSON 扩展；新机制补独立校验、模型效果和回归。
4. **原始资产不删除**：concept/candidate/approved/runtime 分级，保留 provenance、hash、脚点、动作及导入元数据。
5. **按里程碑产出证据**：每阶段至少一个独立提交、可执行测试、PASS/FAIL 记录与未完成项。PR #67 在人工验收前保持 Draft。

## 2026-10-31 自动化验证快照

- P0 真实地图拓扑 + 全量 Godot 回归：[Wuxia HUD CI #41163405903](https://github.com/yup-21/game-dev/actions/runs/41163405903) PASS；[Modular content CI #41163405869](https://github.com/yup-21/game-dev/actions/runs/41163405869) PASS。
- P2 素材清单和导入校验：[Wuxia HUD CI #41163635308](https://github.com/yup-21/game-dev/actions/runs/41163635308) PASS；[Modular content CI #41163635317](https://github.com/yup-21/game-dev/actions/runs/41163635317) PASS。
- P4 发行导出：[Portable export CI #41163811832](https://github.com/yup-21/game-dev/actions/runs/41163811832) PASS；Windows/Linux 二进制、PCK 关键资源核对、Linux headless 启动均通过。完整玩家试玩、性能 P95/P99 和 Windows GUI 启动仍待人工验收。
- P1 最终规则与表现闭环（commit `5cff9d2`）：[Wuxia HUD CI #41167123420](https://github.com/yup-21/game-dev/actions/runs/41167123420) PASS，包含 `P1_POSTURE_PASS checks=33 failures=0`、`P1_CLOSEOUT_PASS checks=184 failures=0` 和 `SCHOOL TESTS: 342 PASS / 0 FAIL`；[Modular CI #41167123433](https://github.com/yup-21/game-dev/actions/runs/41167123433) PASS；[Portable Export #41167123397](https://github.com/yup-21/game-dev/actions/runs/41167123397) PASS。上述成绩仅代表自动化通过，目标 PC GUI / 帧时间仍待验收。
- **这些结论只适用于上述 CI 对应 commit；新代码需要重新运行工作流。**

## P1 权威架势原型

见 [P1_COMBAT_RULES.md](P1_COMBAT_RULES.md)。新增 `deal_posture` / `recover_posture` Effect、破势后的 `opening` 状态与只读架势条；实际通过状态以最新 CI 为准，不以本节替代人工 3v3 验收。
