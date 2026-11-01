# 沈长风：角色/立绘/动画制作工作单

## 身份和用途
- asset_id: `shen_changfeng`，现有 `WuxiaCharacterDefinition` 中的正式主角 ID；目标 story / battle
- 身份锁：年轻游侠，重诺谨慎，墨青蓝外袍、米白里衣、黑发束冠和玉色发簪、直剑、暗色布靴、旧铜色剑穗
- 造型参考：`character_shen_changfeng_identity_sheet_v01.png`（**待负责人确认的设定板**）
- 材质/光照：自然旧布料、皮革和精钢，雨夜冷光、局部暖金反射
- 生产日期：2026-11-01
- 生成工具：内置图像生成工具；底层模型 ID 未公开；seed 不可获取
- 风格基准：`art-production/standards/ART_PRODUCTION_STANDARD.md` 与 `prompts/ART_STYLE_AI_PROMPTS_V1.md`
- 来源/权属：本项目定向原创 AI 生成，未使用外部商业角色图；仍须由负责人完成可商用权属、相似性与最终视觉审核
- 状态：**candidate / owner_review_required**；可在技术审核分支绑定原生 `.tres` 试玩，但不等同 approved
- 全量提示词见同批 `PROMPTS.md`；SHA-256 与版本源流见 `PILOT_MANIFEST.json`。

## 产物
- 1536×1024 身份设定板（正/侧/背及武器细节）
- 1024×1536 透明全身立绘 `portrait_shen_changfeng_fullbody_v01.png`
- V1 原始 24 姿势稿；V2 修订母图 `sprite_shen_changfeng_atlas_source_v02.png`
- 技术装配图 `sprite_shen_changfeng_atlas_normalized_v02.png`：1536×1024，6×4，256×256/格
- 动作帧映射：`idle` 0–1；`move` 2–5；`attack` 6–8；`guard` 9–10；`hit` 11–12；`evade` 13–15；`skill` 16–18；`combo` 19–21；`defeat` 22–23。
- 统一脚点验测：第 227–228 像素；16 像素以上透明边距通过（阈值 Alpha≥32）；需 Godot 运行时再校准 `feet_offset`、`actor_scale`、朝向
- `WuxiaActorAnimationProfile` 通过 P1/P2 EditorPlugin 导入后生成；此候选包内不冒充已正式写入的 `.tres`

## 验收现状
- [x] PNG 解码；立绘真实 RGBA Alpha
- [x] Atlas 24 格、九动作索引存在、格尺寸可整除
- [x] 标准化 Atlas 格边留空与脚点纵坐标一致（技术阈值）
- [ ] 设定板身份/材质人工冻结，立绘授权审查
- [ ] V2 原图已越格或已断开的剑尖与衣袂补绘，帧间过渡/前后方向补全
- [ ] Godot 原生导入、逐动作播放、脚点/朝向、1600×1000 与 1440×900 截图
- [ ] 负责人批准、记录签名和日期

**结论：技术装配候选，当前审核分支已绑定导入资源；旧纹理保留用于事务回退，人工视觉与授权批准仍是发布门槛。**


## 统一原生合同与过渡策略

本工作单保留所有原稿、提示词、母版和 SHA 证据。审核分支仅把候选素材绑定至现有 `.tres`，不复制历史 JSON 加载器，也不删除仍可能需要回退的旧贴图。动作质量、四向站姿、角色身份、地图对位与商业权属均待负责人验收后逐步淘汰旧图。
