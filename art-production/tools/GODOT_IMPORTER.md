# Godot Art Production 工具（P1 导入 + P2 导出/批次）

插件目录：`demos/changfeng-battle/addons/wuxia_art_importer/`。
Godot **4.7.2** 编辑器显示 **Art Production** Dock。
**运行时引用仍以 Godot 原生 .tres 为唯一配置来源。**
`art-production/inventory` 与 `art-production/reviews` 的 JSON 只用于离线审计、SHA-256 校验和回退。

## 未导入候选的原生 Resource

每个 `art-production/candidates/` 下的图片对应 `data/art_candidates/` 下同名、同类别、同角色的 `WuxiaArtCandidateDefinition.tres`。执行：

```bash
python3 art-production/tools/sync_candidate_resources.py
python3 art-production/tools/sync_candidate_resources.py --check
godot --headless --path demos/changfeng-battle --script res://checks/test_art_candidates.gd
```

生成器只创建缺少的候选 `.tres`，保留美术人员手动设置的 `columns/rows`、`feet_offset`、`reference_visible_height_px` 和 `display_scale_override`。0/空值表示**尚未测量**，不是默认通过。候选图片仍保存在仓库的 `art-production/candidates/`，候选 Resource 仅用于制作/验证，不注册 Manifest，也不会参与正式导出。Dock 选择候选图片后点击「读取当前候选 .tres 参数」，将已声明的 Atlas 网格、脚点或 VFX 帧序填入导入表单。**自由装配**可先在 Dock 逐图校准原始网格（包括无法整除的 AI 图片）；确认导入时把实际 `C×R`、单格尺寸、起点、格距、逐格偏移、逐帧独立矩形、蒙版轮廓和输出定位同步到候选 `.tres`，并为这一元数据变更做事务备份。历史单图/VFX 导入仍沿用原有声明校验。

候选 Resource 的参考可见高度来自一张已确认的待机姿势（不是整张图的高度或 Atlas 单格高度），建议显示倍数为 `200 / reference_visible_height_px`。运行时 `actor_visual_scale.gd` 基于待机姿势轮廓自动适配 200px，但其他 Clip 不会逐个缩放；跨动作比例仍需统一原画。场景仍要求同世界坐标同画布，无二次拉伸。
若候选 `display_scale_override > 0`，正式导入该角色 Atlas 时会显式设置 `WuxiaActorAnimationProfile.auto_fit_height=false` 和 `actor_scale`；否则保持原有自动适配策略。手动倍数只控制视觉显示，不得代替统一帧比例、透明边距和世界碰撞距离校验。

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
   - **角色 Atlas**：新素材勾选「自由装配」，通过自定义网格、独立帧矩形/手绘抠图及十二动作有序帧映射生成标准化 Atlas + 原生 `SpriteFrames.tres`，并将其绑定到 `WuxiaActorAnimationProfile.native_frames`。旧 Clip 输出仍可显式关闭“生成原生 SpriteFrames”进行兼容。原有单图路径只在显式选择已有 Profile 模板或勾选「兼容旧图：沿用已有帧配置」时使用，绝不默认拿旧动作帧套到新图上。
   - **分层场景**：选择 `data/maps/` 战斗地图或 `data/native/chapters/` 剧情章节；背景与必选地面、可选前景／天气／同画布剧情复合预览（`story_preview`）须匹配**当前场景 `WuxiaSceneArtProfile.reference_size` 与 Map/Chapter 声明的完整世界画布**（单屏 1600×1000，纵向长图可为 1600×2000／2400 等），不能把长图缩至 1600×1000。更新 `WuxiaSceneArtProfile` 并挂到 Map 或 ChapterScene；未配置的可选图层可为空，缺失的必需层直接报错，不借用单图回退。旧图片保留作为审计/回滚资产，已注册地图或角色以新 `.tres` 绑定为准。预览显示章节主角/NPC 脚点。
   - **UI Atlas / VFX**：填写唯一内容 ID，UI 创建/更新 `WuxiaAssetDefinition`；VFX 创建/更新继承它的 `WuxiaVFXDefinition`，并注册到 Manifest。当前导入 Dock 接收图像 VFX，必须具备真实 Alpha，可配置列/行及用逗号分隔的绝对播放帧索引；播放速度由事件表现时长决定，图集不要求固定 6×4。`event_kind` 优先填原始战斗事件（如 `ATTACK_DECLARED`、`HP_DAMAGED`、`COMBO_TRIGGERED`）；旧视觉键（如 `slash`）继续兼容。
3. 可直接单项“检查并导入”，或者“加入批次”逐项入队（最多 64 项）后统一检查。
4. 当固定目标图片路径已有不同内容时，勾选“版本化替换”，新图片保存在 SHA-256 前 12 位后缀的新路径，保留旧图片；预检列出旧/新绑定差异。
5. 确认前先对本批所有相关 .tres 建事务备份；随后复制图像、等待原生 Importer、逐项保存 Resource。失败时尝试统一恢复 .tres。
6. 事务日志：`art-production/reviews/import-transactions/<id>/import-log.json`。“撤销上次导入”恢复旧 .tres（如果文件后来没有被改动），新图片保留，新增 .tres 移至 `recovered-new/`。

导入并绑定后的当前素材属于 `in_use`（Asset Resource `status=runtime`），不会在 `assets/imported/` 下再建立候选状态；权属仍标记 `owner_review_required`。**导入通过不等于动作、脚点、遮挡及版权验收通过**。
如 Inspector 缓存未刷新，重新打开资源或编辑器。

### 新角色动作 Atlas：自由装配

1. 选择「角色动作 Atlas」及目标角色，勾选「自由装配」，从顶部源图列表逐一选取、点击「添加选中的源图集」。一个批次可以混排动作，多张图可以接续同一动作。源图按加入顺序编号 `0,1,2...`。
2. 在「已添加源图」选择当前图，旁边直接显示**切格与动作预览**。分别指定真实列数/行数、单格宽高、网格起点 X/Y、横纵格距；点击图上的格位即可加入当前动作。若格子偏移，选择格号并调整该格局部 X/Y。还可以逐帧输入绝对 `X/Y/W/H`，或将源图交互工具设为“拖拽矩形裁切”；选中格子后使用局部放大（1 为整图、最大 8 倍）与鼠标中键平移细调。源图不变。
   - 对两帧太近、矩形内带入相邻人物残影的情况，改选“自由手绘套索抠图”（按住左键沿人物外形画一圈）或“多边形点击描边”（逐点点击、右键或双击闭合）。轮廓外像素会在**导入副本**内被设置为全透明；原图保持原样。预览动作帧可以检查实际抠图效果，重置按钮清除当前格矩形、蒙版、偏移、缩放和脚点。
   - 轮廓必须在对应的矩形内，不能代替修复真正重叠的身体/武器像素。复杂发丝、衣袖及半透明边缘可以在 Krita/GIMP 中先人工修图，再回到导入器使用保留的透明度。
3. 动作选择器固定显示新十二动作 `idle/walk/run/attack1/attack2/attack3/attack4/skill/evade/guard/hit/defeat`。在「当前动作的有序帧映射」输入如 `0:0-7,1:4,0:9`，表示源图 0 的 0～7 格、源图 1 的第 4 格、源图 0 的第 9 格，**严格按填写顺序播放**。可手动乱序、非连续选择，也可以点击网格逐帧追加，跨图续帧不需额外 Clip。
4. 分别设置每个动作循环、FPS、可选的逗号分隔逐帧秒数；点击「播放动作」切换到当前动作逐帧播放，另有「暂停」「上一帧」「下一帧」「查看网格」。**即使其余动作尚未完成，也能先预览当前已映射动作**。非循环动作只播放一次，`defeat` 保持最后一帧。正式导入预检仍要求十二动作均已绑定，丢失动作直接报错，不使用 `move/attack/combo` 旧别名回退。
5. 选择输出普通档单格 328×256（默认）或高个档 384×288。「检查并导入」校验每帧内容非空、至少 8px 真透明留白、切格/描边不越界、合法的时间/帧序；不同源图/独立裁切矩形允许具有不同尺寸，默认使用共同的等比缩放因子，可为个别帧手工叠加倍率并点选脚点。所有帧使用共享画布及可编辑输出定位。合格后按动作顺序装配为 PNG，默认直接生成可编辑的原生 `SpriteFrames.tres`（含 FPS、循环和逐帧时长），Profile 的 `native_frames` 指向它且不再另外保留一套 Clip 帧序。取消“生成原生 SpriteFrames”才输出旧 Clip 兼容资源。`WuxiaCharacterDefinition`、Animation Profile、PNG、SpriteFrames 与候选 `.tres` 元数据通过原有事务备份、版本化路径和确认界面一起切换。**候选图的独立 `.tres` 与角色 ID 必须一致**。

注意：自由裁切和多边形/套索蒙版可以人工排除相邻帧的残留像素，但不会自动猜测人物/武器轮廓、补出被别帧遮住的细节或修复真正重叠的原画；必要时请在外部绘图软件返工。输出使用固定两档画布，单帧仍需 8px 透明边距。源图文件始终保留。为避免覆盖 Godot 内已经人工编辑的动画，原生输出使用内容与帧参数共同决定的版本化 `_frames__<hash>.tres`，同版本已存在时拒绝覆写；可在 Godot 原生 SpriteFrames 编辑器继续修改。新动作集为十二动作，历史九动作 Resource 仍可正常读取和播放。

逐帧手工缩放和点选脚点的用法见 [逐帧缩放与脚点对齐](SPRITE_FRAME_ALIGNMENT.md)。未设置逐帧参数的来源沿用上述共同缩放和定位。

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
godot --headless --path demos/changfeng-battle --script res://checks/test_sprite_assembly.gd
python3 art-production/tools/inventory_assets.py --check
```
