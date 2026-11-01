# 沈长风 · 身份、立绘与九动作试点 WORK_ORDER

## 基本信息

- asset_id: `shen_changfeng`
- asset_type: `character_design | portrait | sprite`
- target_usage: `story | battle | hud`
- status: `concept`（工作单创建，不代表素材已经完成或批准）
- owner/reviewer: **待美术负责人指派**
- source / rights: **需核实既有概念图生成记录与商用权属**
- prompt_template_version: `ART_STYLE_AI_PROMPTS_V1`
- model/version/seed: **尚未开始新一轮生成**

## 参考与身份锁定

- 已批准的身份设定板：**暂无，禁止假定已冻结**。
- 当前运行时立绘：`demos/changfeng-battle/assets/characters/concepts/shen_changfeng_portrait.png`。
- 候选全身方向：`demos/changfeng-battle/assets/concepts/2026-11-01/shen_changfeng_fullbody_candidate.png`，身份、材质、边缘尚待审查。
- 历史动作占位：`demos/changfeng-battle/assets/concepts/2026-10-30/character_style/blue_swordfighter_pixel_study.jpg`，JPEG 不可直接当透明动画图集。
- 待冻结要素：脸型、发冠、蓝灰行衣层次、剑与剑鞘、左/右持剑关系、冷暖色板、故事比例与战斗比例。
- 实际输入 AI 的参考图：**待人工选择批准后逐张记录**。

## 输出与验收

- 最终尺寸：立绘尺寸/Atlas 格子尺寸由设定验收确定；各帧尺寸一致、Atlas 宽高能被 `columns` / `rows` 整除。
- 文件格式：透明 RGBA PNG/WebP；不得以白底 JPG 充数。
- 动作：`idle`、`move`、`attack`、`guard`、`hit`、`evade`、`skill`、`combo`、`defeat`；每种动作给定真实帧索引与循环、FPS、起手/命中/收招检查。
- 脚点/方向：同一 `feet_offset`、`actor_scale`，目前左右镜像回退；真正四方向批准前必须补足上下方向表现。
- Godot 目标：`res://data/native/characters/shen_changfeng.tres` 和 `res://data/native/animations/shen_changfeng.tres`。
- 输入提示词全文、修订日志、编辑母版、生成源图、帧序表：**待制作后归档**。
- 禁止覆盖当前运行图；经过独立视觉及授权批准后，再在编辑器中更换 `.tres`。

## 审核清单

- [ ] 人工锁定身份与商业授权
- [ ] 立绘和动作小人保持脸、服饰、剑与配色一致
- [ ] 透明通道、统一帧格、全部九动作与脚点通过技术预检
- [ ] 攻击、受击、连携、死亡时序在剧情和战斗复测
- [ ] 两套分辨率 GUI 截图 + 授权核验
- [ ] Owner 批准版本及 SHA

## 结论

- 审核状态：`pending`
- 阻塞：批准设定板、分帧原图、可编辑母版、授权与视觉测试证据尚缺。
