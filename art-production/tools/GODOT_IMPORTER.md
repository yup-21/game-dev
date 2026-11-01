# Godot Art Production Importer（P1）

本编辑器插件位于 `demos/changfeng-battle/addons/wuxia_art_importer/`，默认启用。
它将仓库根目录 `art-production/in-use/` 和 `art-production/candidates/` 下的图像
**复制**到 Godot 项目的 `res://assets/imported/`，然后生成或更新原生 Resource。
不会把 `asset-index.json` 加入游戏运行时，也不修改规则模型。

## 使用

1. 使用 Godot **4.7.2** 打开 `demos/changfeng-battle/project.godot`，找到右侧 **Art Production** Dock。
2. 选取图片；可搜索文件名。右侧预览会显示尺寸、Alpha 和 SHA-256 摘要。
3. 选择导入类型并指定目标：
   - **角色立绘**：选择现有 `WuxiaCharacterDefinition`，更新 `portrait`。
   - **角色动作 Atlas**：选择角色、列/行、脚点和朝向；预览可切换九种动作；
     更新 `sprite_sheet` 与 `WuxiaActorAnimationProfile`（新 Profile 放到 `data/native/animations/`）。
   - **分层场景**：选择 `WuxiaMapDefinition` 或 `WuxiaGridMapDefinition`；
     选中主背景，再指定必需的 `ground` 和可选的 `foreground`、`weather`；
     更新 `WuxiaSceneArtProfile`（存放 `data/native/scene_art/`）。
   - **UI Atlas / VFX**：填写唯一的内容 ID；生成/更新 `WuxiaAssetDefinition`，
     新 ID 同时写入 `data/content_manifest.tres`。VFX 可填写事件名称。
4. 先检查并预览变更，确认后才复制图片、等待 Godot 原生 Importer 完成，并保存 `.tres`。
5. 提交导入结果前，运行项目测试和 `python3 art-production/tools/inventory_assets.py --write`
   更新离线索引，并人工检查动作、脚点、遮挡、授权。

## 约束与限制

- 插件只接受制作区中的文件，不接收任意外部路径；已有不同内容的目标图片不会被覆盖。
- 角色立绘/Atlas 和前景/天气图层必须有有效透明像素；Atlas 宽高须被行列整除。
- 场景各层必须与地图逻辑 `viewport_size` 完全相同；不会从场景 PNG 猜测碰撞。
- 新角色动画 Profile 初始继承九动作模板的帧定义；不同网格须先通过有效帧检查。
  这只是导入框架，**不代表自动生成动作中间帧**。实际帧序列需要人工编辑和验收。
- 所有新素材均为 `candidate` / `owner_review_required`，绝不自动批准。
- 变更已有 `.tres` 前会将原文件备份到 `art-production/reviews/import-backups/`；
  导入失败时可能留下新复制的图像，需人工清理。P2 再考虑事务级撤销与批量替换。
- 预览中的地图几何是辅助检查叠层，不替代游戏内截图、脚点或遮挡验收。
- P1 只提供单项导入；批量处理、版本替换、完整回退属于 P2。

## 只读回归检查

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_art_importer.gd
```
