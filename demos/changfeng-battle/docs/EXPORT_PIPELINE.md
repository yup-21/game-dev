# P4：Portable Demo 导出管线（首版）

`export_presets.cfg` 定义 Windows Desktop 和 Linux x86_64 两种标准发行配置。
`.github/workflows/wuxia-export.yml` 使用 Godot 4.7.2 官方 Export Templates 完成导入、Release 打包、PCK 检查、Linux 无窗口启动和构建产物上传。

## 交付目标

- 每个 PR 的核心 `.gd`、`.tscn`、`.json`、`project.godot` 及美术资源变更会触发独立导出 Job。
- Windows 产出 `changfeng-demo.exe`；Linux 产出 `changfeng-demo.x86_64`；资源存在 `changfeng-demo.pck`。
- `checks/test_export_resources.gd` **从 build 目录运行 PCK**，核对 JSON 目录、场景与关键图像。不能通过读取源目录伪装导出成功。
- `actions/upload-artifact` 保存正式二进制，方便另一台电脑无 Godot 编辑器试玩。

## 使用约束

本方案是**可重现技术构建**，不代表已经完成鼠标、动画、手感和 PC 帧率的人工验收。

- 清单中的内容定义 JSON 由导出 include_filter 明确携带，避免 `FileAccess` 读取不到非 Resource 文件。
- 首次运行请保留 Export Job 的安装模板与导出日志；任何未找到资源都作为 CI 失败处理。
- 商业发布需要单独核实原创/生成素材的使用权、应用图标和平台签名。
- 临时不实现存档；等 P0–P3 玩家流程稳定之后再讨论。
