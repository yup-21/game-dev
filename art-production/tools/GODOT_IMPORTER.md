# Godot Art Production 工具（P1 导入 + P2 导出/批次）

插件目录：`demos/changfeng-battle/addons/wuxia_art_importer/`。
Godot **4.7.2** 编辑器显示 **Art Production** Dock。
**运行时引用仍以 Godot 原生 .tres 为唯一配置来源。**
`art-production/inventory` 与 `art-production/reviews` 的 JSON 只用于离线审计、SHA-256 校验和回退。

## 导出：当前 Godot → art-production

1. 选择“全部实际使用图片 / 单个角色依赖 / 单个地图依赖 / 指定 .tres 依赖”。
2. 按角色、地图或剧情章节导出时选择已有 Resource；指定资源输入 `res://data/...`。
3. 点击“预检导出差异”，检查新建、相同、不同的副本。
4. 如生产区已有不同内容副本，必须手动勾选“允许覆盖”并重新检查。
5. 确认后按类型与资产 ID 原字节复制到 `art-production/in-use/`；单个资源范围还会将 .tres 依赖副本保存于 `in-use/resources/`，仅供离线审计。
6. 日志保存在 `art-production/reviews/export-transactions/<id>/export-log.json`，替换前的副本存于 `before/`。可以点“撤销上次导出”；新增副本移到 `recovered-new/`，不会直接删除。

“全部实际使用”汇总正式脚本、场景、原生 Resource 的显式纹理引用及 `ContentRegistry` 已解析的文件名默认绑定；额外涵盖角色动画 Profile、独立 Clip Atlas、场景分层与 VFX。按单个 Resource 导出时也执行相同默认绑定校验；手动纹理优先。模板、测试、仅编辑器预览及未注册候选不进入运行图片清单。
任意必需图片缺失、配置引用错误或注册校验失败，导出预检报错；不会猜测旧路径或自动选用占位。脚本内复杂动态加载和版权仍需人工核查；使用中不等于视觉审核通过。

## 导入：art-production → 当前 Godot

1. 选择 `in-use/` 或 `candidates/` 下的图片，预览尺寸、Alpha 与 SHA-256。
2. 选择素材类型，并明确设置角色、地图或内容 ID：
   - **角色立绘**：更新 `WuxiaCharacterDefinition.portrait`。
   - **角色 Atlas**：设置列数、行数、脚点与朝向；可选已有原生动作 Profile 模板以保留显式 Clip 动作映射（支持新 12 组动作及逐 Clip Atlas），更新 `sprite_sheet` 和 `WuxiaActorAnimationProfile`。
   - **分层场景**：选择 `data/maps/` 战斗地图或 `data/native/chapters/` 剧情章节；背景与必选地面、可选前景/天气/同画布剧情复合预览（`story_preview`）统一为 1600×1000，更新 `WuxiaSceneArtProfile`，挂到 Map 或 ChapterScene。未配置的可选图层可为空，缺失的必需层直接报错，不借用单图回退。旧图片保留作为审计/回滚资产，但已注册地图或角色卡以新 `.tres` 绑定为准。预览显示章节主角/NPC 脚点。
   - **UI Atlas / VFX**：填写唯一内容 ID，创建/更新 `WuxiaAssetDefinition` 并注册到 Manifest。VFX 必须具备真实 Alpha，可配置列/行及用逗号分隔的绝对播放帧索引；播放速度由事件表现时长决定，图集不要求固定 6×4。`event_kind` 优先填原始战斗事件（如 `ATTACK_DECLARED`、`HP_DAMAGED`、`COMBO_TRIGGERED`）；旧视觉键（如 `slash`）继续兼容。
3. 可直接单项“检查并导入”，或者“加入批次”逐项入队（最多 64 项）后统一检查。
4. 当固定目标图片路径已有不同内容时，勾选“版本化替换”，新图片保存在 SHA-256 前 12 位后缀的新路径，保留旧图片；预检列出旧/新绑定差异。
5. 确认前先对本批所有相关 .tres 建事务备份；随后复制图像、等待原生 Importer、逐项保存 Resource。失败时尝试统一恢复 .tres。
6. 事务日志：`art-production/reviews/import-transactions/<id>/import-log.json`。“撤销上次导入”恢复旧 .tres（如果文件后来没有被改动），新图片保留，新增 .tres 移至 `recovered-new/`。

导入并绑定后的当前素材属于 `in_use`（Asset Resource `status=runtime`），不会在 `assets/imported/` 下再建立候选状态；权属仍标记 `owner_review_required`。**导入通过不等于动作、脚点、遮挡及版权验收通过**。
如 Inspector 缓存未刷新，重新打开资源或编辑器。

## 数据保护与限制

- 导出不修改 `res://assets/`；导入不覆盖旧图片。不论素材原稿来自 `art-production/candidates/` 还是 `art-production/in-use/`，Godot 均只写入 `assets/imported/characters/<actor-id>/portraits|sprites/`、`scenes/<scene-id>/`、`vfx/<actor-id>/<skill-id>/`、`ui/<component-id>/` 等分类路径；不在导入目录保留 candidate/in-use 或 `baseline`、`sprite-vNN` 制作批次层级。名称冲突仍需显式版本化替换。
- `in-use/` 导出副本不再包含 `imported/` 或日期层级。导入撤销只恢复 .tres，保留新图片供检查。Godot 自动生成的 `.godot/imported/` 是缓存，不应手动整理或提交。
- 导出有 SHA 核验与备份；失败时尽量自动回退，若已有后续改动则拒绝静默覆盖。
- 导入时校验候选目录中的角色／场景 ID 与目标 Resource 一致；VFX 从 `vfx/<actor-id>/<skill-id>/` 自动记录拥有者 ID，已有 VFX 若归属另一角色则拒绝静默转移。
- 角色与 VFX 必须有真实 Alpha；VFX 帧号、Atlas 网格/帧号、地图必需透明 ground 的同尺寸画布做技术预检；美术连续性和授权仍需人工验收。
- 编辑器工具不做持续双向同步。调整 Resource 后先在 Dock 执行「全部实际使用图片」导出预检并同步镜像；`python3 art-production/tools/inventory_assets.py --write` 仅更新静态引用库存，不能替代 Godot 默认绑定预检；该脚本对不同 SHA 的旧副本会拒绝覆盖。
- 编辑器仅保留“上次导入/导出”的撤销按钮。关闭编辑器后旧日志仍保留在磁盘，可以依日志人工恢复。

## 回归测试

```bash
godot --headless --path demos/changfeng-battle --editor --import --quit
godot --headless --path demos/changfeng-battle --script res://checks/test_art_importer.gd
godot --headless --path demos/changfeng-battle --script res://checks/test_art_workflow.gd
python3 art-production/tools/inventory_assets.py --check
```
