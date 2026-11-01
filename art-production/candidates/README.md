# 候选素材

同一素材槽位可以保留多个候选版本，图片本身不需要复杂的管理状态。

- 把候选图片放到 `YYYY-MM-DD/<asset-id>/`，新版本使用不同文件名，不覆盖旧文件。
- **素材来源只需保存生成提示词与对应的 Godot Resource 路径**；可以直接使用已有 `PROMPTS.md`、`WORK_ORDER.md`，无需增加 seed、模型、逐轮审批等必填台账。
- 符合既有角色/场景/VFX/UI 的原生合同，并能正常导入使用时，切换相应 `.tres` 绑定即可；旧版本仍可留作候选或过渡回退。
- 每个 Resource 属性（例如角色 portrait、animation_profile 或地图 scene_art）只绑定一个使用中版本；`inventory/` 只列当前使用中的素材。

**本文件只定义管理方式。** 生成、动画、尺寸、脚点与游戏表现规范继续采用 `art-production/standards/` 和对应的专业 Skill。
