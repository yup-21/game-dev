# Godot 导入素材与文件名范式

`assets/imported/` 仅保存 Godot 已导入的素材。**不按 candidate / in_use、日期或制作批次分目录**。归属由文件夹确定，文件名只表达资源用途；同角色、同技能、同场景的素材紧邻存放。

```text
assets/imported/
├── characters/<actor-id>/
│   ├── portraits/portrait.png       # 默认立绘
│   ├── portraits/portrait_alt.png   # 手选替代版本
│   ├── sprites/atlas.png            # 默认角色动作图集
│   ├── sprites/atlas_v02.webp       # 显式版本（不会自动选中）
│   ├── story-poses/<pose-id>.png     # 剧情姿态
│   └── concepts/<concept-id>.png    # 设定参考
├── scenes/<scene-id>/
│   ├── background.png               # 场景远景
│   ├── ground.png                   # 独立地面
│   ├── foreground.png               # 可选前景
│   ├── weather.png                  # 可选天气
│   └── story_preview.png            # 可选合成预览
├── vfx/<actor-id>/<skill-id>/atlas.png
├── ui/<component-id>/<element-id>.svg
└── placeholders/<asset-type>/default.svg
```

## 命名与绑定规则

1. **小写 ASCII + snake_case** 用于文件名、角色/场景 ID；技能 ID 保持现有 Resource ID（允许短横线，目录与 ID 必须逐字一致）。无需在文件名重复所属 ID，也不在目录使用日期。
2. 主文件固定语义名：立绘 `portrait`、动作和技能特效 `atlas`、场景五层 `background/ground/foreground/weather/story_preview`；UI 采用组件内的功能名。图片可用 `.png/.webp/.svg/.jpg/.jpeg`；默认主文件**在所有格式中至多存在一份**，多份同名不同格式视为配置错误。
3. 同一目录的未选版本用 `_v02`、`_alt`、`_normalized_v02` 等描述后缀；不根据最高版本号、最新修改时间、模糊匹配或任意备选路径挑图。
4. `WuxiaContentManifest` 加载时，原生 Resource 的手动 `Texture2D` 引用**优先**；空槽位才按 `res://assets/imported/...` 约定的精确文件名填充。必需素材未找到或匹配多个格式，加载时报错；明确可选图层可以为空。绝不自动以占位素材顶替正式内容。
5. `art-production/candidates/` 保存多份原稿及工作单；`art-production/in-use/` 只镜像正式引用图片，并使用与导入目录相同的相对路径。候选原稿无需改名，导入器将选中的副本规范化命名。切换候选时通过 Importer 或手动修改 Resource 绑定，不会因为移动文件自动改变已选素材。
6. 已有 `legacy/` 归属于明确命名的旧场景素材，和 `placeholders/` 均不得参与默认查找。编辑器中的 `.godot/imported/` 是可重建缓存，不是素材目录。

整理后运行 `python3 art-production/tools/inventory_assets.py --check` 验证路径、引用和正式镜像；还需运行 Godot 的 Resource 绑定与导入工作流测试。
