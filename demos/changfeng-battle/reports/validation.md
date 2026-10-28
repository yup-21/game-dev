# 断桥听风 Demo 验证记录

整理日期：2026-10-29（Asia/Hong_Kong）。本目录来自已迁入听风机制的 changfeng-battle 项目，保留当前可玩代码、数据、定向检查和精选截图。

## 源版本已完成的验证

环境：Windows，Godot 4.7.2 stable custom build；真实图形检查使用 NVIDIA OpenGL Compatibility 渲染。其他 Godot 版本尚未验证。

| 检查 | 结果 |
| --- | --- |
| 全部五式用法、CTB、牌区、响应栈、情报 | 105 PASS / 0 FAIL |
| 仅消费公开／己方上下文的 AI 策略 | 15 PASS / 0 FAIL |
| 畸形请求、重开隔离、费用、Hook 限流、条件效果、终局清理 | 145 PASS / 0 FAIL |
| 真实 UI 输入：分支、地图、响应层、Pass、闪避、费用、重开与结局 | 82 项通过 |
| 3 种子 × 2 先手 × 双次完整对局 | 12 场结束，重复结果一致 |

正常对局记录：

| 种子 | 开局先手 | 胜者 | ACTION 数 | 请求数 | 结束 tick |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2026 | 0 | 1 | 10 | 85 | 400 |
| 2026 | 1 | 0 | 12 | 102 | 500 |
| 13 | 0 | 0 | 11 | 95 | 500 |
| 13 | 1 | 0 | 10 | 92 | 400 |
| 241 | 0 | 1 | 12 | 97 | 500 |
| 241 | 1 | 0 | 14 | 121 | 600 |

每个配置运行两次，逐请求检查12张牌的区域守恒、UID唯一、资源非负，以及自由行动／交锋期间时间停表。0为沈长风，1为拦江客。

## 整理后目录复验

新目录已实际复验，结果全部通过：

| 检查入口 | 本次结果 | 本地日志 |
| --- | --- | --- |
| verify.ps1 -Stage Policy | 15 PASS / 0 FAIL | captures/checks/tingfeng-policy.log |
| verify.ps1 -Stage Rules | 105 PASS / 0 FAIL | captures/checks/tingfeng-rules.log |
| verify.ps1 -Stage Edges | 145 PASS / 0 failures | captures/checks/tingfeng-edges.log |
| verify.ps1 -Stage Playthrough | 12 场结束、6组配置重复一致 | captures/checks/tingfeng-playthrough.log |
| --tingfeng-visual-check 原生 OpenGL | 82 项真实 UI 检查通过 | captures/tingfeng-ui-render-run.log |
| battle_view.gd --check-only | 脚本检查通过 | captures/checks/battle-view-parse.log |
| Windows PowerShell 5.1 启动器 | 显式路径、GODOT_BIN、Creator fallback 检查通过 | - |

启动脚本、验证脚本和截图输出目录均已按新位置适配。本次图形检查自动退出，精选截图已从新目录运行结果更新。原始缓存及生成日志不随源码提交。

可通过 `checks/verify.ps1 -Stage Policy|Rules|Edges|Playthrough` 分别复现；日志生成于本地 `captures/checks`，不会加入 Git。

## UI 截图

- [自由行动](../docs/screenshots/tingfeng-action.png)
- [同牌多用法](../docs/screenshots/tingfeng-branches.png)
- [交锋响应栈](../docs/screenshots/tingfeng-clash.png)
- [闪避落点与锁定范围](../docs/screenshots/tingfeng-evasion-target.png)
- [结局](../docs/screenshots/tingfeng-result.png)
