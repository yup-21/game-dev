# 沈长风·武学技能特效（首批）

此次仅为主角当前装备/习得的 **wind_sword、tingfeng、step** 及 `tf_change_stage` 绑定特效；烟岚剑属于其他角色，不在本批。普通技能、听风原生 RuleUsage 与武学节点均直接修改原有 `.tres`，不创建第二套映射表。

## 美术
- 资源：`res://assets/imported/in-use/vfx/shen_changfeng/martial-forms/vfx_shen_martial_5x4.svg`（透明 SVG，Godot 导入为 Texture2D）。
- 5 行 × 4 列，每格 256px，左至右依次为蓄势、出现、峰值、消散；整图 1024×1280，无背景，无文字、人物或跨格内容。
- 行 0 剑刺（冰蓝凝光），行 1 横斩（浅青弧光），行 2 断岳重击（白金剑气），行 3 护体（青碧环刃），行 4 身法（雾白残影）。
- 同源素材镜像：`art-production/in-use/vfx/shen_changfeng/martial-forms/`。此版本是原创可编辑矢量表现；正式美术可替换成透明 PNG/WebP，保持帧顺序、单格尺寸及 Asset ID 即可，无需修改技能逻辑。
- 使用状态：runtime；并非人工视觉验收通过的最终手绘特效。

## 绑定资源
| 资源 ID | 逐帧序列 | 用途 |
| --- | --- | --- |
| `shen_sword_thrust` | 0–3 | 折柳探锋、青岚寻隙/破晓、听风探锋、风系直刺 |
| `shen_sword_sweep` | 4–7 | 折柳追风、听风探锋追风、变锋攻势 |
| `shen_sword_heavy` | 8–11 | 听风断岳重斩、照胆 |
| `shen_wind_guard` | 12–15 | 化劲护元/卸劲/迎锋、变锋守势 |
| `shen_wind_step` | 16–19 | 踏雪游影/避锋、雁回折身、游身 |
 
## 运行时
- `animation_action` 每个用法只选择一组动作：直刺 `attack1`，下劈 `attack2`，横斩 `attack3`，重击 `attack4`，护体 `guard`，身法 `evade`，变锋 `skill`。
- `vfx_slot` 直接引用 Asset Manifest 内的 5 个 VFX Resource ID。
- `vfx_trigger` 与语义 cue 一致：攻击 `strike_active`、护体 `guard_active`、身法 `evade_visual_start`、变锋 `skill_visual_active`。
- 消费 `ATTACK_DECLARED` 时**不会立即生成剑气**；播放器执行至 cue 时产生 VFX。全部特效只更改可视节点，绝不变动规则伤害、判定范围、无敌时间及实际坐标。
- 受击等公共反应仍保持原有特效。由主角与 NPC 共享的 RuleUsage 也会复用同套学派特效，后续可为敌方角色添加资源覆盖层。
 
## 验证
`checks/test_shen_martial_vfx.gd` 核查资源注册、图集网格/逐帧播放、非即时触发、主角学派 RuleUsage、武学节点绑定和 Resource 转换。本批没有替换任何角色动作帧。
