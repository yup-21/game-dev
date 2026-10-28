# 长风浮生录 · 断桥听风

当前默认场景已经迁入听风五式：**CTB 集气 → 自由行动 → 有限连锁交锋**。保留原来的 15×10 断桥地图、河流浅滩、角色与移动/受伤表现。玩家和敌人使用同一个 BattleState、校验、费用、牌区与效果结算，仅决策来源不同。

## 启动与操作

用 Godot 打开本目录的 `project.godot` 后运行，或在 Windows 双击 `run-demo.cmd`。需要自行准备 Godot 4.x；已验证的环境是本地 4.7.2 自定义版本，其他版本尚未验证。仓库不附带 Godot 二进制。

脚本优先使用 `-GodotPath`，其次 `GODOT_BIN`、PATH 中的 `godot` / `godot4`；在原 Creator 工作区也可自动找到已有引擎。运行日志为 `captures/play.log`，输出目录会自动创建。

```powershell
.\run-demo.cmd -GodotPath "C:\Tools\Godot\godot.exe"
.\run-demo.cmd -CheckOnly
```

启动后点击进入战场或按 Enter。

| 操作 | 输入 |
| --- | --- |
| 普通移动 | 右键合法空格；M 恢复移动选择 |
| 基础攻击 | Q 或右键相邻敌人 |
| 基础格挡 | G 或右侧按钮 |
| 选择招式用法 | 点击手牌或按 1–5，展开全部分支；灰色分支显示原因 |
| 主动攻击 | 选分支后点击敌人 |
| 游身／避锋 | 选分支后点击碧色高亮落点 |
| 截势 | 选择分支后点击右侧高亮的敌方响应层 |
| 弃牌回气 | C 后点击一张手牌 |
| 结束自由行动／Pass | Space、Enter 或右侧按钮 |
| 取消选择 | 右键；Esc 关闭分支菜单 |
| 观势／藏锋 | 底部四个按钮循环 0–2 级，点击“应用等级并重新开战”生效 |
| 相同种子重开 | R |
| 规则帮助 | H / Esc |

朱色格框表示本次攻击锁定区域，碧色内框表示合法闪避落点。交锋时右侧从栈顶向下显示响应；按后进先出结算，取消响应不会返还费用。卡牌显示的是心神与修正后实际费用。

## 当前规则

- 双方初始 20 气血、3 内息、5 手牌，最大内息基础值 6。四维属性影响衍生值。集气阈值 10000；同速默认玩家先手，结束行动扣除阈值并保留溢出。
- 没人就绪时，按最近集气／到期事件推进全局 tick。基础每 100 tick 恢复 3 内息、0.2 气血；速度仅影响行动频率，不额外按行动发内息。
- ACTION 与 CLASH 全局停表；输入等待和动画不会回气。一次 ACTION 内可自由穿插移动、攻击与护体。普通移动基础额度 2 格，每格 1 内息；卡牌身法不占普通移动额度。
- 基础攻击、基础格挡、弃牌回气各每 ACTION 一次。攻击牌可在资源和手牌允许时多次发动。
- 每人首次行动不重复抽牌；下一次本人 ACTION_START 才弃旧手牌、抽至 5 张。结束行动保留手牌供防御。结算区的牌不会参与重洗。
- 每次攻击建立独立交锋：守方先响应，双方交替；每人最多 2 张、合计最多 4 张。两次连续 Pass 或第 4 张响应后逆序结算；无牌时仍可 Pass。
- 根攻击锁定格子，避锋离开覆盖即 MISS，变锋可扩展覆盖；不自动追踪。迎锋按接招／破招／招路确定成功、相持或失败，无隐藏随机弹反。
- 伤害依次应用基础、属性与连携、增伤、减伤、护体、气血。护体全部吸收仍算 HIT，只有实际扣血才产生 HP_DAMAGED；死亡立即停止派生效果，并清理所有挂起牌。
- 观势严格高于藏锋时揭牌，1 级每次换手揭一张、2 级揭整手。明牌覆盖藏锋；已知 UID 保留到离开手牌。AI 不读取未知敌牌。

## 五式内容

数据文件：`data/tingfeng_cards.json`。5 个定义、12 个用法、每人 12 张镜像实体牌，每个实例一次只能选一种用法。

| 招式 | 张数 | 用法 |
| --- | ---: | --- |
| 探锋式 | 3 | 试探／追风；同次 ACTION 已完成试探后接追风，后招 +1 伤害 |
| 断岳式 | 2 | 重斩：高伤、落空露隙；照胆：命中明牌，利用露隙 +2 并消耗 |
| 游身式 | 2 | 踏雪：主动移动 ≤2；避锋：防御响应移动 ≤1 |
| 化劲式 | 3 | 护元 +3 护体；卸劲本击 −3；迎锋进行接招判定 |
| 变锋式 | 2 | 进攻响应追击扩区；攻守截势取消一个敌方响应层 |

## 架构和历史

见 [当前引擎说明](docs/tingfeng-engine.md) 与 [迁入接口](TINGFENG_MIGRATION.md)。当前核心拆分为状态、属性、调度、校验、费用、交锋、效果、状态生命周期、连携、Hook、信息投影与日志。没有在现有引擎旁边另起一份 TingfengEngine 真值。

本仓库收录当前五式 Demo；迁移前源码、旧五阶段检查与十套武学资料保留在原 Creator 工作区，不随此 Demo 重复发布。参考目录中的旧架构文档用于说明演变，不代表旧内容已适配当前 CTB 规则。

## 已执行的验收

| 定向检查 | 实际结果 |
| --- | --- |
| 规则、全部五式用法、CTB、牌区、连锁、情报 | 105 PASS / 0 FAIL |
| 只读 AI 决策 | 15 PASS / 0 FAIL |
| 畸形请求、Hook、死亡清理、条件效果、HP 费用与强制位移 | 145 PASS / 0 FAIL |
| 3 种子 × 2 先手 × 双次对局 | 12 场结束，重复结果相同；每请求检查牌区与资源 |
| 原生 OpenGL 图形界面输入 | 82 项通过，无运行错误 |

复现单组定向检查：

```powershell
.\checks\verify.ps1 -Stage Rules
.\checks\verify.ps1 -Stage Policy
.\checks\verify.ps1 -Stage Edges
.\checks\verify.ps1 -Stage Playthrough
```

以上命令同样支持 `-GodotPath` 和 `GODOT_BIN`。例如：

```powershell
.\checks\verify.ps1 -Stage Rules -GodotPath "C:\Tools\Godot\godot.console.exe"
```

图形输入验收：

```powershell
New-Item -ItemType Directory -Path captures -Force | Out-Null
& $env:GODOT_BIN --path . --log-file captures/tingfeng-ui-render-run.log -- --tingfeng-visual-check
```

图形检查前将 `GODOT_BIN` 指向 Godot 可执行文件。检查会自动退出。控制台检查日志生成于 `captures/checks/`，对局记录生成于 `checks/tingfeng-playthrough-results.json`，运行截图生成于 `captures/tingfeng-*.png`；这些生成文件均忽略提交。已选取的界面截图见 [docs/screenshots](docs/screenshots)，验证摘要见 [reports/validation.md](reports/validation.md)。
