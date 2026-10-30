# HD-2D 定向验证与修复（2026-10-30）

基线为 `02bfff5`（PR #23 合并后）。本次在 Windows、Godot `4.7.2.stable.custom_build.ed1daf0bf`、Compatibility / NVIDIA OpenGL 3.3 环境实测。

## 问题与修复

- `test_hd2d_startup.gd` 假定运行时相机和精灵具有固定节点名称，实际动态名称导致 `camera missing` 等误报。改为检查实际相机引用、挂载位置、当前视口相机及角色下的精灵类型，同时保留图集、动画与特效检查。
- HD-2D 每帧按 `Sprite3D` 路径更新角色悬浮，但创建精灵时未命名，导致这一表现更新被跳过。创建时显式设置名称。
- 完整交锋中的多阶段动画可能在独立倒计时结束后提前确认票据，截断尚未结束的表现队列。实测复现了仍有约 4.7 ms 动画未完成即确认的情况；现在同时等待倒计时与语义队列结束，回归覆盖完整交锋、实际扣血与多阶段队列。
- 序章图形检查将 `Texture2D.get_size()` 的 `Vector2` 与 `Vector2i` 比较，脚本无法解析。改为同类型比较，六阶段图形检查恢复。
- 序章插画仍继承旧像素版本的最近邻过滤，改为线性过滤以匹配插画缩放。
- 将独立场景的启动和真实输入检查接入 `verify.ps1`，可按 `HD2DStartup`、`HD2DInteractions` 或聚合 `HD2D` 运行；`All` 也包含这些检查。

## 复现与验证

以下命令在 `demos/changfeng-battle` 执行，`GODOT_BIN` 指向本机 Godot 控制台可执行文件：

```powershell
& $env:GODOT_BIN --headless --path . --editor --import --quit
.\checks\verify.ps1 -Stage HD2D -GodotPath $env:GODOT_BIN
.\checks\verify.ps1 -Stage Opening -GodotPath $env:GODOT_BIN
.\checks\verify.ps1 -Stage DemoFlow -GodotPath $env:GODOT_BIN
.\checks\verify.ps1 -Stage Rules -GodotPath $env:GODOT_BIN
.\checks\verify.ps1 -Stage Edges -GodotPath $env:GODOT_BIN
& $env:GODOT_BIN --path . --script res://checks/test_hd2d_interactions.gd --log-file "$PWD/captures/checks/hd2d-interactions-graphical.log" -- --capture
& $env:GODOT_BIN --path . --log-file "$PWD/captures/checks/opening-visual-final.log" -- --opening-visual-check
```

| 定向检查 | 结果 |
| --- | --- |
| Godot 资源导入 | 退出 0 |
| HD-2D 独立启动 | `HD2D_STARTUP_PASS` |
| HD-2D 真实输入（headless） | 49 PASS / 0 FAIL |
| HD-2D 真实输入（NVIDIA OpenGL，含截图检查） | 53 PASS / 0 FAIL |
| Opening | 71 PASS / 0 FAIL |
| DemoFlow | 38 PASS / 0 FAIL |
| Rules | 105 PASS / 0 FAIL |
| Edges | 145 PASS / 0 FAIL |
| 序章真实渲染 | 菜单、过场、探索、对话、选择、结尾六阶段通过 |

输入检查通过 `Input.parse_input_event` 进入 Godot 输入管线，覆盖可见按钮与操作区、相机选格、非法水域/占用格、合法移动、选牌与取消、目标提交、Space 结束行动与交锋 Pass、AI 轮转、动画票据及 R 重开。完整交锋观察到 14 个动画票据和两阶段表现，总气血从 40 降至 36.2，再恢复玩家行动。图形运行同时验证水面 Shader 和角色/操作区的实际显示。

本地证据保留在 `captures/checks/`、`captures/hd2d-validation/` 的战场、选牌、交锋与结算截图，以及 `captures/opening-*.png`，生成文件不提交。各验证同时核对退出码、成功标记及 Godot 错误日志；没有把导入成功等同于独立场景可运行。

## 验证边界

本次只运行上述定向检查，没有运行完整 `All` 或全部武学流派对局。HD-2D 仍为双人垂直切片，测试不代表完整游戏或所有卡牌组合已验收。战斗规则与数值未修改。
