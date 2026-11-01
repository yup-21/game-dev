# Portable Demo 导出管线

`export_presets.cfg` 定义 Windows Desktop 与 Linux x86_64 发行配置；`.github/workflows/wuxia-export.yml` 在 PR 与 main push 时使用 Godot 4.7.2 Export Templates 导入 Resource、打包并执行外部 PCK smoke。

## 正式资源

游戏使用 `data/content_manifest.tres` 显式引用角色、技能、章节、遭遇、地图及美术 `Resource`，Godot 导出系统跟踪其中的依赖。生产不读取历史内容 JSON；`export_presets.cfg` 排除 JSON，包括仓库内仅用于美术来源审核的离线 metadata。

- Windows：`changfeng-demo.exe`，Linux：`changfeng-demo.x86_64`，资源包：`changfeng-demo.pck`。
- `checks/test_export_resources.gd` 在工作检出目录之外用 `--main-pack` 启动，验证默认 Manifest、原生内容和关键美术可从已打包资源读取，而非误读源码文件。
- workflow 上传构建产物，实际 Windows/Linux 桌面 GUI、操作手感、性能与素材授权仍需人工验收。

## 本地验证

```sh
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --export-release "Linux" build/changfeng-demo.x86_64
```

在 CI 中从仓库根目录执行上述工作流；本地若没有导出模板，需要先通过 Godot 编辑器安装与版本匹配的 Export Templates。不要通过临时恢复旧格式文件修复缺资源错误，应检查 Manifest 和 Resource 依赖。
