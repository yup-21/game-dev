# 角色动作原生化：GIF → SpriteFrames（分阶段接入）

该编辑器扩展接入 `wuxia_art_importer` 右下方的 **Native GIF** Dock。
每个动作对应一张透明 GIF；正式动作的帧序、FPS、循环和逐帧时长现在可保存在 Godot 原生 `SpriteFrames.tres`。
对旧的 6×4 / 5×5 / 任意 C×R Atlas 不作强制替换，现有 `WuxiaActorAnimationClip` 仍可继续播放。

## 导入操作

1. 先准备角色的正式 `res://data/native/characters/<id>.tres`，并完成候选工作单和来源审查。
2. 将 GIF 放到 `art-production/candidates/characters/<id>/` 下，例如 `actions/idle.gif`、`actions/walk.gif`、`actions/attack1.gif`。每个候选须有独立 `WuxiaArtCandidateDefinition`：可点 Dock「登记候选 GIF 的 .tres」自动建立，也能手动在 Inspector 设置 `asset_kind=sprite`、`owner_id`、`action_id`、实际 `source_pixel_size`、对应 `source_path`；GIF 不填写 C×R 图集网格。不会自动读取其他角色目录。
3. 编辑器使用的 Python 3 安装 Pillow：`python -m pip install pillow`。仅在 **导入时**调用，游戏运行和导出不依赖 Python。
4. 打开 Godot `demos/changfeng-battle/project.godot`，切到 `Native GIF` Dock，指定角色 Resource 和动作文件夹，扫描后核对 `action=/绝对路径/动作.gif` 映射。允许自由增删动作和改文件名，至少需要 `idle`。
5. 明确选择普通单帧画布 328×256 或高个画布 384×288。一个角色全套动作必须一致；透明边距至少 8px。GIF 只接受已有且完整的画布，不裁切、逐帧缩放或猜动作编号。
6. **预检 GIF 并预览原生动画**：可在 Dock 下方选择动作，按 GIF 内原始时长播放；确认提示会列出更新的角色和动作列表。
7. 确认后生成 `assets/imported/characters/<id>/sprites/<action>/atlas__<hash>.png`、`data/native/animations/<id>_frames.tres`，并更新 `data/native/animations/<id>.tres` 与角色 `.tres` 引用。图集以版本哈希命名，不覆盖旧图。
8. 在 Godot **SpriteFrames** 原生编辑器中检查、调整动作帧和时长；原生 `AnimatedSprite2D` 播放这些帧，原有 `AnimationPlayer` 可专门调整视觉根位移、判定框、VFX 触发（战斗规则仍由原 BattleModel 管理）。

## 关键边界

- 新 `SpriteFrames.tres` 是 GIF 路径的动作帧序唯一来源，不再同时维护一套 Clip 绝对帧号；Profile 继续保留视觉缩放、脚点等元数据。
- `SpriteFrames` 可以只导入当前需要的动作。战斗事件请求缺失动作时明确报错，不做九动作或十二动作的隐式替代。
- 旧角色的 `.tres` 与运行时图集保持兼容；新 GIF 必须经过人工视觉/权属批准后才应该绑定为正式 `in_use`，通过程序检查不等于获批准。此工具的“确认导入”仅是执行操作确认，**不等同于美术批准**。
- 旧图集和新版本 PNG 不自动删除。撤销采用既有 Art Transaction 日志恢复角色、Profile 和 SpriteFrames `.tres`；如果资源后来被手动修改，哈希保护会拒绝覆盖。
- GIF 不含碰撞/武器判定和世界移动元数据；这些应在原生 `AnimationPlayer` 与战斗时间线上显式编辑、测试。**不能把贴图内的局部移动重复写入世界控制器。**
- 当 PNG 刚写入但 Godot 尚未完成导入时，工具会将原图嵌入可编辑的原生 `SpriteFrames.tres`，确保不依赖未生成的 `.import` 缓存；之后的资源导出仍依照正式 `.tres` 收集依赖。

## 还需要的 GUI 验收

完整角色 GIF 尚需以候选素材逐动作做播放、脚点、Loop、武器连续性和 1600×1000/1440×900 画面验收。可以先导入一个单角色的 `idle/walk/attack1/guard` 候选验证整个编辑路径，未批准前不要切换原正式人物资源。
