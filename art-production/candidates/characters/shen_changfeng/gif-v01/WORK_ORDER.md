# 沈长风：12 组战斗动作 GIF 工作单

- `asset_id`: `shen_changfeng`；`asset_type`: `sprite`；`target_usage`: `story / battle`
- 资产状态：`candidate`；生成日期：2026-11-07；来源：OpenAI 图像生成（底层版本/seed 未提供）
- 身份参考：`../baseline/character_shen_changfeng_identity_sheet_v01.png`（原工作单尚待负责人冻结）
- 身份锁：青年游侠、旧墨青蓝袍、米白内衫、束发玉簪、暗靴、褐铜腰带、**右手一柄直剑**；不增加第二把剑
- 制作身高：暂以 **1.78m / 178 源像素**控制自然站姿（等待角色正式身高确认）
- 固定格：328×256；5×5 原始 AI Sheet 共三批，标准单格 GIF；朝右侧视基准、同一地面逻辑根点
- 动作规格：12 组 / 75 帧，独立 GIF；实速时间以 `MANIFEST.json.actions[].durations_ms` 为准
- 候选 Resource：`res://data/art_candidates/characters/shen_changfeng/gif-v01/actions/<action>/sprite_shen_changfeng_<action>_v01.tres`
- 目标正式 Resource：`res://data/native/characters/shen_changfeng.tres` → 现有 AnimationProfile；**本轮未替换**
- 计划正式导入：经批准后 Native GIF Dock 自动产生 `res://data/native/animations/shen_changfeng_frames.tres` 或使用既有已绑定 `SpriteFrames`（不得重复双写）
- 原图及生成提示词：`source/`、`PROMPTS.md`；生成脚本：`art-production/tools/build_shen_gif_v01.py`
- 几何与帧 QA：`quality_report.json`；25 格来源与逐帧时间表：`MANIFEST.json`

## 验收记录

- [x] 12 张 GIF、75 帧和 15 份独立候选 `.tres` 已生成；格式/尺寸/映射自动校验。
- [x] 标准单格 Alpha 安全边距 ≥8px，等比处理且没有逐帧单独缩放。
- [ ] 原始 Sheet **14 帧**安全边距不足，需对源姿势完整性、格线污染做人工核对或重新生成；不能只根据最终 GIF 留白当成修复。
- [ ] 按 12 动作逐帧审查循环闭合、剑路、衣服、脚点、根运动与站姿身份一致。
- [ ] 角色设计/身高、授权与相似性审核。
- [ ] Godot SpriteFrames 原生预览、时间轴和 1600×1000／1440×900 GUI 实测。
- [ ] 负责人明确批准后才允许正式导入替换。

**结论：待修正的 12 组候选 GIF，不能标记为美术通过或已接入游戏。**
