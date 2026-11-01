# R31 · GitHub Actions 精简与并行

## 数据依据

PR #68 的 R30 提交 `b2bbcc5` 上，四条工作流均通过，耗时：

| workflow | 运行时间（约） | 处理 |
|---|---:|---|
| Original Wuxia HUD regression | 3m24s | 保留并将空间/战斗测试拆成独立并行作业 |
| Modular Wuxia content contracts | 1m05s | 保留；独立的原生资源、强类型迁移与规则契约门禁 |
| Kenney CC0 art integration | 54s | 删除独立 workflow；它的截图与 HUD 完全重复 |
| Portable Changfeng demo export | 49s | 保留，修复 `.tres` / `.gdshader` / `addons/**` 改动不触发导出检查的问题 |

这些是 GitHub Actions 运行从启动到完成的墙钟时间；原四条工作流并行运行，因此不能相加作为用户等待时间。

## 变更

1. **移除 `kenney-art.yml`**。其唯一的 `test_kenney_assets.gd`、`test_opening_story.gd`、`test_parties.gd` 已迁入 HUD 的 `godot-ui` 作业；`test_tingfeng.gd` 仍在 HUD 旧武学回归。重复的 `capture_hd2d_unified_hud.gd` 和 `capture_opening_story_2d.gd` 只在 HUD `visual-evidence` 运行一份。
2. **HUD 的长串测试分组**：`godot-spatial` 负责路径/空间/规则适配/时间轴/R30 原生动画，`godot-ui` 负责原版美术/交互/技能 UI/剧情；`visual-evidence` 独立截图。三作业并行，分别保有 Godot 导入，避免跨作业共享缓存或存档状态。
3. **去除七个重复的 HUD 测试步骤**；它们已被保留的模块化 workflow 执行。同一脚本测试只需有一个 CI 所属者，HUD 仍保留必要的端到端行为测试。
4. **按 PR 折叠过期运行**：三条剩余 workflow 增加 `concurrency`，新提交自动取消同一 PR/分支更早的执行；不合并不同 PR。
5. **导出覆盖补洞**：原导出工作流没有把 `.tres` 原生资源、shader 和 Godot 插件加入触发路径。现在三类改动都会触发 Windows/Linux 便携导出检查。

## 保留理由与边界

- 模块化回归验证内容注册、迁移、效果与规则，不与 HUD 的屏幕输入/战斗演出等价。它耗时较短，独立失败定位有价值。
- HUD 的空间适配和动作时序测试不应因“历史”二字删除：它们现在运行在正式 `battle_hd2d.tscn` 与 `BattleModel` 之上，验证重构未破坏既有行为。
- 导出不只是编译：还在仓库外加载 `.pck` 与 Linux 二进制。Godot 编辑器内成功不能代替此检查。
- 截图证据保留一份，避免删掉真正能发现 headless 逻辑测试不能覆盖的渲染失效。
- 同一 PR 的新提交会取消旧 CI；若希望针对某个历史提交保留完整证据，应在其运行完成后再推下一提交，或手工触发独立分支验证。

后续如需继续缩短等待时间，应先记录新基线，确认确切慢步骤再动。不要默认将所有测试并行启动在**同一个** Godot 项目工作目录；它们可能共享 `user://` 状态或导入缓存，拆分到隔离 job 是更安全的方案。
