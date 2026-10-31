# R22 — 原生 AssetRegistry、导入规格与表现素材绑定

所有新素材使用 `WuxiaAssetDefinition` 的 `.tres`（Manifest 的 `assets`），资源字段直接拖拽 Godot 导入的 `Texture2D`、`PackedScene` 或 `AudioStream`。旧 `assets/production_manifest.json` 仅供历史资产 QA 兼容，新素材无需追加 JSON。

## 制作规范

- `content_id` 是全仓稳定 ID；`asset_kind` 区分头像、6x4 动作表、静态剧情姿态、背景、VFX、角色场景、音频和 UI。
- `source` 与 `rights` 必填；`status` 为 concept / preview / candidate / runtime / approved。未经使用权确认的素材不能设置 approved；技术通过也不是正式美术审核。
- 动作表配置 `columns=6`、`rows=4`、`faces_left`、`foot_anchor`；运行时校验可整除且正常导入。真正的动作清单、锚点逐帧一致性仍需人工审图。
- `owner_character_id` 为人物的 portrait / pose_sheet / static_pose / actor_scene 建立稳定绑定；`event_kind` 为 VFX/audio 建立效果事件绑定。重复绑定与非法资源路径直接失败。
- `AssetRegistry` 先校验导入资源与来源，再提供 `texture_for_character`、`scene_for_character`、`texture_for_event`、`audio_for_event`。
- `HD2DArtCatalog`、`CharacterFactory`、`BattleVFX2D` 先查询 AssetRegistry，未注册时保持旧 Resource/历史视觉回退，不改变战斗规则或事件序列。

演示：沈长风头像、信使 6×4 表、旧破庙背景和独立 VFX 测试事件 `r22_probe`。均是现有资产引用，不宣称新建高质量逐帧动画；特殊测试 VFX 不在正式战斗中触发。

## 验收

运行 `checks/test_native_assets.gd`：Manifest 校验、资源宽高与图集、人物绑定、角色工厂输出、纹理 VFX 注入、未经确认的版权禁止 approved。继续运行旧 `checks/test_asset_contracts.gd` 及 HUD/便携导出。

R24 新角色只需在 Manifest 增添角色与素材 Resource，不能为新人物再修改 `hd2d_art_catalog.gd` 或 HUD 核心。正式发布仍需要逐帧动画、音效和使用权的人工验收。
