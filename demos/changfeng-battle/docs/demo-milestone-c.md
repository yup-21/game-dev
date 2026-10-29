# Demo C：可交付试玩、验收与版本导出

本 PR 依赖 Demo B / Demo A，专注发布与通用视图收口；不修改 CTB、状态、伤害、AI 核心或武学定义语义。

## 打开游戏
```bash
godot --path demos/changfeng-battle
```
主菜单“初入江湖”走序章正线：水墨雨夜过场 → 破庙镖头剧情 → 参悟太虚引气残篇 → 3v3 追兵战斗（2 名可操作队友、1 名 AI 队友、3 名敌人）→ 暗伤与寿元选择 → 序章结局。

主菜单“断桥论剑”仍是双人战斗沙盒，“群侠试炼”仍是无剧情状态的多人沙盒。**沙盒不会污染正线进度**。

### 输入
- 剧情：WASD/方向键移动；E 交互；Enter/空格/点击推进；Esc 跳过过场。
- 武学参悟：点击“参悟残篇”，再点击“迎战追兵”；Enter 也可操作。
- 战斗：玩家拥有对应 CTB/响应优先权时，通过右侧列表选择合法行动，再点击目标格；Space/Enter 收势或 Pass；R 重开。
- **统一导航：P 暂停/继续，F10 返回主菜单**。暂停只停止场景的输入及自动操作，不修改 BattleModel 的集气与规则状态。
- 剧情结算：选择疗伤或带伤追查，寿元、暗伤和线索立即更新；结束序章后可返回主菜单。

### 音频
`scripts/demo_sfx.gd` 使用 Godot 的 AudioStreamGenerator 原创合成短剑鸣、打击、护体、对话提示和雨声噪声。音频随战斗语义事件播放。无需下载或使用可能有版权限制的背景音乐、人物素材或音效文件；后续可用单独授权的音乐替换。

## Godot 4.7.2 自动化
新增 `.github/workflows/changfeng-demo.yml`：

1. 安装 Godot 4.7.2（与项目要求版本一致）。
2. 无头导入并运行所有既有战斗检查 + `test_parties.gd`、`test_opening_story.gd`、`test_demo_flow.gd`、`test_demo_technique.gd`。
3. 用 Xvfb 截取主菜单／雨夜过场／对话及战斗截图；上传截图供 PR 审查。
4. 通过 Godot Windows Desktop export preset 生成 `build/ChangfengDemo.exe` / `.pck` 并上传 GitHub Actions artifact。

本地 Windows：
```powershell
cd demos/changfeng-battle
.\checks\verify.ps1 -Stage All -GodotPath "C:\Tools\Godot\godot.console.exe"
```

只跑本次剧情整合：
```powershell
.\checks\verify.ps1 -Stage DemoFlow
.\checks\verify.ps1 -Stage DemoTechnique
.\checks\verify.ps1 -Stage Parties
.\checks\verify.ps1 -Stage Opening
```

导出：
```powershell
& $env:GODOT_BIN --headless --path . --export-release "Windows Desktop" build/ChangfengDemo.exe
```
导出需要安装 Godot 4.7.2 的 Windows Desktop 导出模板。

## 需要验收的场景
- 从菜单新游戏到剧情结算，**不依赖快捷测试入口**，无解析／运行错误。
- 对话两种选择、跳过过场、参悟奖励、三个招式逐个生成及移除、多人 CTB 和 AI 行动。
- 玩家胜利、失败、重试战斗、返回菜单以及新游戏重置，均无旧会话数据污染。
- 按 P 时 AI 停止提交请求，F10 可以退出单双人战斗；在手动角色待决策和 AI 对局时都成立。
- 战斗音效在攻击、伤害、格挡事件触发时播放且不影响战斗随机数。
- Windows exe 可以在没有 Godot 编辑器的计算机上启动，存档和完整世界尚未实现。

## 当前范围外
长期持久化存档、开放世界地图、四位女主长线剧情、复杂事件条件、完整寿元/暗伤模拟、正式动画贴图与长篇配乐。这些应在纵向 Demo 验收后再设计。

**状态说明：** 提交代码的容器没有 Godot 可执行程序，故没有在此声称测试/截图/导出已经成功。GitHub Actions 实际反馈才是下一步验收证据。
