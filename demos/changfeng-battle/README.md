# 长风浮生录 · 断桥听风

> **默认启动入口已变更**：运行 Godot 项目首先进入《长风浮生录》主菜单，可选择“初入江湖”，观看可跳过的雨夜过场、行走到镖车前与镖头交谈并作出选择，再进入战斗试玩。剧情详见 [序章“雨夜残镖”说明](docs/opening-prologue.md)。旧 `battle.tscn` 与 `party_battle.tscn` 仍可独立运行。

## 插画式 HD-2D 画面预览（当前开发分支）

默认菜单新增 **“插画立体战场 · HD-2D”**，可直接进入 `battle_hd2d.tscn`：以非像素 SVG 角色插画、平滑 6×4 逐帧 Sheet、3D 斜俯视断桥、暖灯松林和战斗镜头标题卡呈现既有双人规则。序章“雨夜残镖”的菜单、过场、探索人物和对话头像也复用相同插画素材，并新增雨水反光与分镜。原有 `battle.tscn` / `party_battle.tscn` 不删除。

序章结尾的“迎战追兵”仍然进入原有多人剧情战斗；“插画战斗场景预览”是独立双人画面试玩，**尚未接通多人剧情战斗模型**。实现范围、定向检查及后续替换手绘素材方案见 [插画式序章和战斗说明](docs/illustrated-opening-battle.md)。这一分支的 Godot 实机渲染尚待验证。

当前默认场景已经迁入听风五式：**CTB 集气 → 自由行动 → 有限连锁交锋**。保留原来的 15×10 断桥地图、河流浅滩、角色与移动/受伤表现。玩家和敌人使用同一个 BattleState、校验、费用、牌区与效果结算，仅决策来源不同。

已接入 [武学V3：兼容性分析与移植结果](docs/wuxue-v3-integration.md)。头部“我方／敌方”菜单各有听风五式与十门武学，选择后点击底部“应用流派与等级并重开”。双方可同门或异门，各用独立12张测试牌组。

详细设计与接入方式见 [战斗机制与框架详细说明](docs/tingfeng-engine.md)：包括22节规则、状态模型、完整属性公式、费用、LIFO算例、语义事件、Hook、AI/UI接口与已知边界。

## 启动与操作

用 Godot 打开本目录的 `project.godot` 后运行，或在 Windows 双击 `run-demo.cmd`。需要自行准备 Godot 4.x；已验证的环境是本地 4.7.2 自定义版本，其他版本尚未验证。仓库不附带 Godot 二进制。

脚本优先使用 `-GodotPath`，其次 `GODOT_BIN`、PATH 中的 `godot` / `godot4`；在原 Creator 工作区也可自动找到已有引擎。运行日志为 `captures/play.log`，输出目录会自动创建。

```powershell
.\run-demo.cmd -GodotPath "C:\Tools\Godot\godot.exe"
.\run-demo.cmd -CheckOnly
```

启动后先进入主菜单。选“初入江湖”体验序章；也可选“断桥论剑”跳过故事进入原双人战斗。进入战斗场景后仍使用下列按键。

| 操作 | 输入 |
| --- | --- |
| 普通移动 | 右键合法空格；M 恢复移动选择 |
| 基础攻击 | Q 或右键相邻敌人 |
| 基础格挡 | G 或右侧按钮 |
| 选择招式用法 | 点击手牌或按 1–5，展开当前页对应分支；超过5张可用手牌区箭头翻页 |
| 选择双方武学 | 头部我方／敌方按钮，选择后应用并重开 |
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

观势1首次行动重复揭牌的边界已在V3接入时修复，详见 [框架说明第16.3节](docs/tingfeng-engine.md#163-首次刷新边界的修复)。现在只有真正新抽牌才产生新刷新批次。

新增状态：凝势最多2层、250tick，下次根攻击宣告时消费增伤；封气150tick只减半自然回气；灼痕最多2层，每100tick绕护体扣层数伤害并衰减。周期同刻可能使双方死亡，显示平局。V3远程采用正交直线和角色／地形挡线；血费、按用法限次和状态条件均经同一管线校验。

## 五式内容

数据文件：`data/tingfeng_cards.json`。5 个定义、12 个用法、每人 12 张镜像实体牌，每个实例一次只能选一种用法。

新增武学定义位于 `data/school_forms.json`，由SchoolCatalog校验并规范化；40旧定义引用映射在 `data/legacy_id_map.json`。详见V3分析文档，不用于在战UID热替换。

| 招式 | 张数 | 用法 |
| --- | ---: | --- |
| 探锋式 | 3 | 试探／追风；同次 ACTION 已完成试探后接追风，后招 +1 伤害 |
| 断岳式 | 2 | 重斩：高伤、落空露隙；照胆：命中明牌，利用露隙 +2 并消耗 |
| 游身式 | 2 | 踏雪：主动移动 ≤2；避锋：防御响应移动 ≤1 |
| 化劲式 | 3 | 护元 +3 护体；卸劲本击 −3；迎锋进行接招判定 |
| 变锋式 | 2 | 进攻响应追击扩区；攻守截势取消一个敌方响应层 |

## 架构和历史

见 [当前引擎说明](docs/tingfeng-engine.md) 与 [迁入接口](TINGFENG_MIGRATION.md)。当前核心拆分为状态、属性、调度、校验、费用、交锋、效果、状态生命周期、连携、Hook、信息投影与日志。没有在现有引擎旁边另起一份 TingfengEngine 真值。

本仓库收录当前听风与V3武学Demo；迁移前源码、旧五阶段检查和旧40单用法牌的完整设计源留在原Creator工作区。V3规范化目录、映射与技术参考已纳入当前工程；旧架构文档仍只用于说明演变，不代表所有旧设计已适配。

## 已执行的验收

| 定向检查 | 实际结果 |
| --- | --- |
| 规则、全部五式用法、CTB、牌区、连锁、情报 | 105 PASS / 0 FAIL |
| 只读 AI 决策 | 15 PASS / 0 FAIL |
| 畸形请求、Hook、死亡清理、条件效果、HP 费用与强制位移 | 145 PASS / 0 FAIL |
| 3 种子 × 2 先手 × 双次对局 | 12 场结束，重复结果相同；每请求检查牌区与资源 |
| 原生 OpenGL 图形界面输入 | 82 项通过，无运行错误 |
| V3目录／映射／坏配置拒绝 | 198项通过 |
| V3全部用法／连携／时钟／范围／限次／路径 | 342项通过 |
| V3真实UI | 61项通过 |
| V3正常对局 | 16组终局，2783次请求无不变量错误，2组重复trace一致 |

复现单组定向检查：

```powershell
.\checks\verify.ps1 -Stage Rules
.\checks\verify.ps1 -Stage Policy
.\checks\verify.ps1 -Stage Edges
.\checks\verify.ps1 -Stage Playthrough
.\checks\verify.ps1 -Stage Catalog
.\checks\verify.ps1 -Stage Schools
.\checks\verify.ps1 -Stage SchoolPlaythrough
.\checks\verify.ps1 -Stage Framework
.\checks\verify.ps1 -Stage Generated
.\checks\verify.ps1 -Stage Lifecycle
.\checks\verify.ps1 -Stage Opening
.\checks\verify.ps1 -Stage Parties
.\checks\verify.ps1 -Stage DemoFlow
.\checks\verify.ps1 -Stage HD2DStartup
.\checks\verify.ps1 -Stage HD2DInteractions
```

`Framework` 检查能力图和 JSON 整数值校验，`Generated` 检查生成卡牌与保留期限，`Lifecycle` 检查模型重开、释放及子系统引用回收。校验同时核对退出码、成功标记和 Godot 错误日志。

`Opening` 检查序章数据、分支和场景脚本，`Parties` 检查多人队伍、目标、胜负及无效阵容重开。

`DemoFlow` 检查剧情会话、JSON 遭遇配置、战斗与结算的衔接。

`HD2DStartup` 直接加载插画立体战场，检查模型、当前相机、界面、角色图集、动画队列与剑光特效。`HD2DInteractions` 检查该场景的按钮、棋盘鼠标、键盘操作和动画／AI衔接。`-Stage HD2D` 合并运行这两项；`All` 也包含这两项，避免仅检查默认序章而漏掉可选场景。

以上命令同样支持 `-GodotPath` 和 `GODOT_BIN`。例如：

```powershell
.\checks\verify.ps1 -Stage Rules -GodotPath "C:\Tools\Godot\godot.console.exe"
```

图形输入验收：

```powershell
New-Item -ItemType Directory -Path captures -Force | Out-Null
& $env:GODOT_BIN --path . --log-file captures/tingfeng-ui-render-run.log res://battle.tscn -- --tingfeng-visual-check
```

图形检查前将 `GODOT_BIN` 指向 Godot 可执行文件。检查会自动退出。控制台检查日志生成于 `captures/checks/`，对局记录生成于 `checks/tingfeng-playthrough-results.json`，运行截图生成于 `captures/tingfeng-*.png`；这些生成文件均忽略提交。已选取的界面截图见 [docs/screenshots](docs/screenshots)，验证摘要见 [reports/validation.md](reports/validation.md)。

## 本地美术资源（CC0）

本分支已将 Kenney 的 18 张 CC0 原始 PNG **实际提交到 `assets/kenney/`**，用于双人/多人战场的人物精灵、地形装饰、卡牌外框和序章菜单按钮。来源、逐组许可和固定上游版本详见 [素材来源与许可](docs/asset-licenses.md)。

```powershell
.\checks\verify.ps1 -Stage ArtAssets
```

这是一轮优先解决占位图粗糙问题的素材替换，完整五式教学、连续技槽、动画骨骼和战场镜头仍需单独设计。未触及现有战斗规则。
