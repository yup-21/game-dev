# 长风浮生录 · 断桥听风

> **唯一对玩家开放的战斗场景：`battle_hd2d.tscn`。** 启动 Godot 时进入 `opening.tscn`；主菜单仅提供「初入江湖 · 新游戏」和「进入战斗 · HD-2D」两条游戏路径。序章「迎战追兵」、战斗结算后的「重新挑战」也复用这个场景，不再分流到旧版 2D Demo。

## 唯一战斗入口与美术接入

**正式战斗现已使用原生 2D 场景**：`battle_hd2d.tscn` 为 `Node2D + Camera2D`；`illustrated_battle_map.gd` 持有完整插画、共享脚点与 `Sprite2D` 演员；`battle_vfx_2d.gd` 只负责战斗特效。旧的 3D 地形构造已从正式场景删除，`hd2d_vfx.gd` / `hd2d_scenery.gd` 暂保留为历史模块，不参与玩家战斗。规则仍统一由 `BattleModel` 管理，支持 1v1 / 序章 3v3、CTB、武学卡牌、连携和 CLASH。

**已拆分的职责**：`BattleInputController` 处理 FREE/GRID 点击意图，`BattleCommandController` 做人类输入门控，`BattleCommandDispatcher` 统一投递请求；`BattleHandView`、`BattleHUDStatus`、`ChargeRail` 与 `CharacterCardUI` 只消费投影；`BattlePresentationCoordinator` 管理 animation ticket 的完成、跳过和取消；`BattleSpatialFacade` 提供统一几何查询。上述改动保留原有数值、卡牌、派生与敌方 AI。

**素材覆盖边界**：角色 ID 2–5 使用已提交的24姿态动作图；沈长风（ID 0）和追兵首领（ID 1）仍有插画 atlas 回退。精细逐帧动画尚不完整，新增素材应替换角色表现资源，不应新增第二套规则战场。

本轮长期重构分支的统一依据：[当前技术架构](docs/ARCHITECTURE.md) · [分阶段重构计划与回归矩阵](docs/REFACTOR_ROADMAP.md)。

`battle.tscn`（旧双人 2D）与 `party_battle.tscn`（旧多人 2D）**已经弃用、从所有玩家菜单和重试入口隐藏**。文件和历史检查保留给开发/回归，不应继续扩展为另一套正式战斗 UI。详见 [战斗入口及弃用说明](docs/battle-entry-status.md)。

当前默认场景已经迁入听风五式：**CTB 集气 → 自由行动 → 有限连锁交锋**。保留原来的 15×10 断桥地图、河流浅滩、角色与移动/受伤表现。玩家和敌人使用同一个 BattleState、校验、费用、牌区与效果结算，仅决策来源不同。

已接入 [武学V3：兼容性分析与移植结果](docs/wuxue-v3-integration.md)。头部“我方／敌方”菜单各有听风五式与十门武学，选择后点击底部“应用流派与等级并重开”。双方可同门或异门，各用独立12张测试牌组。

详细设计与接入方式见 [战斗机制与框架详细说明](docs/tingfeng-engine.md)：包括22节规则、状态模型、完整属性公式、费用、LIFO算例、语义事件、Hook、AI/UI接口与已知边界。

## 双章节剧情与跨战斗角色状态（V2–V3）

现有序章胜利后可在结算页选择「进入下一幕」，进入数据定义的「夜渡传书」，在第二张插画背景中与河渡信使交谈，根据第一幕选择分支，领取回气丹，再进入独立的六人战斗遭遇。剧情角色、场景、遭遇、门槛、奖励和下一章关系统一由 `data/chapters/index.json` 注册，新增同类章节无需修改 `GameSession`。

主角背包与装备跨两场战斗存在内存运行态：战斗中的 `USE_ITEM` 只消耗战斗快照，结算时通过完整我方角色快照校验并同步；首次胜利奖励仅领取一次，装备 UID、词条和角色成长来源保留。未实施存档、中途恢复以及临时 Buff/HP 跨场继承。

制作及回归说明：[章节内容制作与跨战斗交接](docs/CHAPTER_AUTHORING_GUIDE.md)。

## 启动与操作

用 Godot 打开本目录的 `project.godot` 后运行，或在 Windows 双击 `run-demo.cmd`。需要自行准备 Godot 4.x；已验证的环境是本地 4.7.2 自定义版本，其他版本尚未验证。仓库不附带 Godot 二进制。

脚本优先使用 `-GodotPath`，其次 `GODOT_BIN`、PATH 中的 `godot` / `godot4`；在原 Creator 工作区也可自动找到已有引擎。运行日志为 `captures/play.log`，输出目录会自动创建。

首次启动或存在尚未导入的媒体素材时，启动脚本会先以无界面模式导入资源，再打开游戏；导入日志写入 `captures/import.log`。

```powershell
.\run-demo.cmd -GodotPath "C:\Tools\Godot\godot.exe"
.\run-demo.cmd -CheckOnly
```

启动后进入主菜单。选「初入江湖」体验序章追兵的多人战斗，或选「进入战斗 · HD-2D」直接体验插画战场。正式战斗场景支持以下操作。

| 操作 | 输入 |
| --- | --- |
| 选择角色移动格/攻击目标 | 左键合法目标格或目标角色 |
| 选择武学用法 | 点击底部手牌；部分招式需要随后选择目标 |
| 基础攻击 | Q（存在合法目标时） |
| 基础格挡 | G |
| 结束行动 / 交锋 Pass | Space 或 Enter；没有合法应变牌或武学时自动 Pass，无须点击 |
| 取消已选择的招式 | 右键 |
| 重新开始独立战斗 | R（剧情战斗不能重置会话） |
| GRID/FREE 模式切换 | M（须轮到我方且无未完成演出） |
| FREE 路线预览 | P |
| 跳过当前动作演出 | S（只确认已有 ticket，不重复结算） |
| 返回菜单或剧情结算 | Esc（剧情需战斗结束后返回结算页） |

更多旧版战斗 Demo 的专用按键说明保留在历史文档，不再属于当前正式 UI。

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

`HD2DStartup` 直接加载纯 2D 插画战场，检查模型、当前相机、界面、角色图集、动画队列与剑光特效。`HD2DInteractions` 检查该场景的按钮、棋盘鼠标、键盘操作和动画／AI衔接。`-Stage HD2D` 合并运行这两项；`All` 也包含这两项，避免仅检查默认序章而漏掉可选场景。

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

## 交锋零响应自动跳过

正式 HD-2D 战斗中，系统以 `BattleModel.legal_actions(responder)` 为准：拥有交锋优先权的任一角色（玩家、友军 AI、敌军 AI）若仅有 `PASS_REACTION` 而没有合法 `PLAY_CARD` 或 `USE_ABILITY`，即立即通过版本化 `BattleModel.request/submit` 自动交还优先权。不会弹出强制 Pass 按钮；若可应变，则仍可主动 Pass。

自动 Pass 不是跳过结算：一次 Pass 交给对方，两次连续 Pass 后仍由 `ReactionController` 逆序结算交锋。纯 `PRIORITY_PASSED` 自动跳过不再等待空动画，若 Pass 触发伤害/死亡等结算事件，保留真实攻击命中/受击动画票据。已有 CTB、LIFO、内息、武学时机与 AI 决策保持不变。

主菜单直达 `battle_hd2d.tscn` 目前仍是 **1v1** 的独立测试战斗；序章追兵进入同一场景，使用 **3v3** 六人队伍，包含两名玩家操控角色及一名友方 AI。当前修改只处理交锋响应的输入体验，未更改人数配置或剧情遭遇。


## 武学派生与人物流派（2026-10-30）

听风五式的「追风」是「探锋·试探」使用后实时获得的**衍生卡牌**，不从初始牌组抽取；「变锋式」则为另一个**可选阶段应变能力**，由 `TechniqueRuntime` 在试探出手后解锁，不会生成变锋卡。序章六人根据人物分配六套不同武学，独立试玩的双方亦为不同门派。详见 [武学衍生与角色流派绑定](docs/derived-martial-schools.md)。


## 战斗手牌显示修复

旧版 `hd2d_battle.gd` 仅将 `legal_actions()` 中的卡牌画出来；独立战斗开场时两名角色相距两格，但绝大多数近战剑招射程一格，导致已抽到的攻击牌被错误隐藏。现统一由 `snapshot(observer_id).hand` 决定卡牌的可见集合，`legal_actions()` 只决定能否点击与目标高亮。暂不可用的牌在原画区置灰，鼠标提示检查目标距离、交锋时机与费用；靠近敌人后会自动恢复可操作。AI行动或动画期间也不再把已有手牌清空。规则、概率、初始12张牌组、抽牌顺序及阶段派生均未更改。


## 统一角色卡模块

七份独立角色档案位于 `data/characters/`；`scripts/character_registry.gd` 负责角色身份、背景、属性、流派、已学阶段技能和美术路径，并通过 `ScenarioDirector` 注入战斗。点击战斗左侧角色头像或按 **C** 打开 `CharacterCardUI`，浏览当前气血/内息/状态、四维/派生属性、武学、人物简介和立绘/动作预览；Esc、背景或收起按钮关闭。装备和成长暂未完成，界面不会展示虚假数值。无档案的旧规则测试保留原行为。


## 多套武学与战斗切换

每名角色在 `data/characters/<id>.json` 的 `learned_schools` 中保存**已学多套武学**，`school_id` 仅表示默认装备流派。档案里可以增加《听风五式》及十套 V3 流派的任意组合；战斗通过 `CharacterRegistry` 注入，系统根据已学列表注册所需卡牌定义，其他未学流派无法切换。正式战斗点击角色头像/按 C，在角色卡中选择另一套武学，或通过右侧「武学 · 切换」入口。只能在本角色 ACTION 阶段、动画结束时提交 `SWITCH_SCHOOL`；切换**消耗当前行动**，不会凭空刷新行动点，换装新流派的12张基础牌，并在下次自己行动开始时抽取5张，原手牌/弃牌/衍生卡不会混入新流派；气血、内息、状态、CTB、人物成长与天赋不变。装备切换后清空旧连携记录及待发招式阶段，避免跨流派免费连招。旧版无档案的规则测试继续按单流派运行。


## 四方向角色朝向

正式 HD-2D 战斗在 `CombatantState.facing` 记录东、西、南、北四方向，并通过只读快照暴露。成功移动（包括击退）按真实寻路**最后一格方向**转身；普通攻击、武学卡与阶段攻击在声明招式时面向目标。演出沿移动路径逐格走位，左右使用 Sprite2D 动作图集水平翻转，脚下小型方向标记提示南北朝向。由于现有 6×4 图集只有动作种类而非四方位逐帧素材，暂不虚称已经提供完整四方向人物立绘；未来可替换为原生分方向图集。朝向目前仅影响表现/状态，不额外叠加背刺伤害或攻击范围判定，CTB、费用、连携保持原规则。可运行 `checks/test_actor_facing.gd` 回归测试。


## 第一幕插画地图（2D）

`opening_flow.gd` 将首幕探索／对白共用同一张完整破庙插画；主角画面由现有 6×4 动作图集单独绘制，交互仍由 `OpeningStory` 状态机控制。正式雨夜追兵与练习入口的 `hd2d_battle.gd` 现使用 `illustrated_battle_map.gd` 创建 2D `CanvasLayer` 的**完整地图 + 2D Sprite2D 角色 + 二维目标落点**。不再创建可见的 3D 棋盘块体、河流 Shader 与叠在背后的远景 Sprite3D；保留旧 `BattleModel`、CTB、卡牌、多武学、事件动画与六人角色图集。战场已迁为 Node2D + Camera2D，动作脚点与鼠标落点共用屏幕坐标；旧 3D 测试假设已迁移为 Sprite2D 校验。

原画入库目标路径：

- `assets/scenes/battle/rainy_bridge_battle.webp`：雨夜断桥河谷完整战斗地图，桥头对应逻辑 `(7,4)`，浅滩对应 `(7,8)`；脚底投影在 `illustrated_battle_map.gd` 手动校准，不能直接用标准 3D 投影。
- `assets/scenes/story/ruined_temple_story.webp`：荒道雨夜破庙探索背景，人物及对话从 `opening_flow.gd` 单独叠加。

两张素材的原始图由项目所有者在对话中提供，均为 1586×992 的 RGBA PNG；优化版使用 WebP q90，不改变原始构图。**原画已在 PR #49 中随代码一并入库。** GitHub Git blob SHA 已与本地转换文件逐字节校验：断桥 `0aa6ed34b25a77144c10bbeef0adb51d60fbfe87`，破庙 `67cd63df2ba48b6af0fefeb07f050f7b000b33d7`。图片丢失时脚本仍可退回旧画面，但 `test_illustrated_maps.gd` 会明确失败，避免误将旧场景验收为新场景。

开发检查：

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_illustrated_maps.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_interactions.gd
```


## 手绘战斗地图的正交网格烘焙

正式剧情战斗和独立试玩使用 `data/maps/rainy_bridge.json`：以用户提交的完整断桥原画为底，将图片旋转 -6° 校平桥面、放大 1.14 倍消除黑边，15×10 的**水平正交矩形网格**不旋转、不使用45°菱形棋盘。地形类型（道路、桥面、急流、石壁、竹丛）已根据原画逐格人工烘焙为可版本管理的行数据。角色脚底、鼠标格子、移动目标、场景出生点统一通过 `MapBake` 投影，`BattleModel` 寻路及碰撞直接消费同一张地形字典。原画前景急流不可通行，不再有虚构的浅滩捷径。**F3** 可显示全部150格的坐标和通行校对层；详情见 `docs/baked-bridge-grid.md`。无地图参数的旧规则测试依旧可独立运行。


## 第一幕角色正式 Sprite2D 替换

`opening_flow.gd` 的破庙探索角色改由 `scripts/opening_role_sprite.gd` 创建真正的 `Sprite2D` 节点，人物身份从 `CharacterRegistry` 查询；沈长风使用战斗同一套6×4动画图，WASD时更新行走帧、左右转向，停止时回到待机。老镖头使用专门绘制的透明 SVG 静态受伤矢量角色姿态（倚石坐地、肩部绷带、旧镖服、手护残卷），通过人物档案 `art.static_pose` 加载为 `Sprite2D`。目前不需要逐帧 NPC 动画，也不再绘制旧运行时 SVG；对白仍使用已有高清立绘。角色以地面脚底作为锚点，按Y深度排序；对白和过场隐藏世界角色，继续使用已有的人物精细立绘。旧 `_portrait()` SVG 人物回退已移除。该次改动**没有改变**第一幕移动范围和镖头交互判定（场景碰撞烘焙属于后续独立任务）。


## 架构重构（长期分支）

全部重构提交持续进入 `refactor/battle-architecture-consolidation`，对应 [Draft PR #67](https://github.com/yup-21/game-dev/pull/67)。独立运行 `checks/verify.ps1 -Stage Refactor`（或见 [重构路线图](docs/REFACTOR_ROADMAP.md) 的 Godot 命令）。`main` 在合并前不会因该分支修改。

- [当前真实架构与接口边界](docs/ARCHITECTURE.md)
- [如何扩展 Buff、武学、角色、装备和物品](docs/MODULAR_CONTENT_GUIDE.md)
- [遗留场景与测试保护](docs/LEGACY_COMPAT.md)
- [素材来源、引用与遗留审计](docs/REFACTOR_ASSET_AUDIT.md)
