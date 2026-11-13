# 角色动作制作工作流

这是美术候选的离线生产工具。输出的 PNG 和预览可用于 [V3 导入工具](../FRAME_WORKBENCH_V3.md)，正式帧序和时长由 Godot 原生 `SpriteFrames` 保存。

| 入口 | 输入 | 输出 |
| --- | --- | --- |
| [Blender 2D 绑定](rig2d/README.md) | 正侧视拆件、关节锚点、动作清单 | 原生透明 PNG、GIF、可编辑 Blender 工程 |
| [ComfyUI](comfyui/README.md) | 角色原画、骨架模板或待提取的动作 | 角色动作候选和检查报告 |

[pose_templates](https://github.com/yup-21/pose_templates) 保存可下载的骨架数据、关节模板和拆件绘制指南。角色贴图、ComfyUI 模型、个人缓存及生成输出由本地项目管理。

验收遵循[角色美术 Skill](../../skills/wuxia-character-art/SKILL.md)、[精灵动画 QA](../../standards/SPRITE_ANIMATION_QA.md)和 [Godot 原生内容开发规范](../../../docs/GODOT_NATIVE_AUTHORING_STANDARD.md)。
