# 沈长风 2D 精灵动画 v04 候选（2026-11-02）

状态：candidate（仅视觉验证，未替换游戏运行版）

## 问题与修复

- 旧 `aligned_v03` 图集为 6×4、256×256/格，待机偏正面、行走和出剑偏侧面，部分剑尖/衣摆跨格，动作关键帧不足。
- 重新绘制固定朝右的侧身／三分之二侧身四组动作：`idle`、`move`、`attack`、`guard`，每组 8 个不同姿势，共 32 帧。出剑动作单独以 **2 列×4 行宽格母图**重绘，保留完整的长剑轨迹。
- 新 Atlas：`sprite_shen_changfeng_atlas_8x6_v04.webp`，**3072×1536，8×6，384×256/格**。帧与帧之间增加透明空间，不改变引擎 1 战斗单位=80 世界像素／普通角色视觉高度200世界像素的规则。
- 程序化单格裁切和贴底后，新增 32 帧按 Alpha≥32 测得脚底基线全部为格内 y=226，最小不透明边界留白 **18px**；刀剑与衣袂不得跨格。
- 32–44 帧暂沿用旧 `aligned_v03` 的 hit / evade / skill / combo / defeat 13 帧作为候选预览兼容位；45–47 是不引用的透明空格。它们**尚未重绘，不计入新增动作**。

## 来源及绑定

- 角色身份参考：`art-production/candidates/2026-11-01/shen_changfeng/character_shen_changfeng_identity_sheet_v01.png` 与旧 `aligned_v03`。
- 核心动作 AI 源图：`sprite_shen_changfeng_core_8x4_source_v04.png`。生成提示词要点：墨青蓝外袍、米白里衣、束冠黑发、直剑；固定朝右侧身，同尺寸、同脚点，每行分别待机/行走/出剑/格挡各八帧，透明背景，无环境及格线，姿势连续、简化细节。
- 出剑 AI 源图：`sprite_shen_changfeng_attack_2x4_source_v04.png`。生成提示词要点：沿用同一角色身份；8 帧起手→收剑，只有 2 列、每格更宽，确保整柄长剑与服饰都位于自身格内，固定侧视、透明背景。均由内置图像生成工具生成，未使用公开 seed。
- 处理方式：Pillow RGBA 阈值轮廓测量、统一纵向基线、等比尺寸和安全边距修正，导出透明 WebP。
- 候选 Resource：`demos/changfeng-battle/data/art_previews/shen_changfeng_sprite_v04.tres`。预览 Atlas 同步到 `demos/changfeng-battle/assets/imported/candidates/2026-11-02/shen_changfeng/`，没有修改 `data/native/animations/shen_changfeng.tres` 或正式角色卡。
- 动态对照：`preview_shen_changfeng_core_v04.gif`（2×2 同步播放四组动作，底边参考线仅用于预览）。

## 帧索引 / 待验收

| 动作 | 新索引 | 帧数 | 播放 |
| --- | --- | --- | --- |
| idle | 0–7 | 8 | loop 12 FPS |
| move | 8–15 | 8 | loop 14 FPS |
| attack | 16–23 | 8 | 非循环，沿用 BattleActionTimeline 时长 |
| guard | 24–31 | 8 | 非循环，沿用 BattleActionTimeline 时长 |
| hit / evade / skill / combo / defeat | 32–44 | 2 / 3 / 3 / 3 / 2 | 旧帧兼容，待重绘 |

- [x] 静态图集整数格、Alpha、帧索引、脚底和透明安全边距检验
- [x] 四组核心动作逐帧静态视觉复查；出剑越格已修复
- [ ] Godot GUI 1600×1000 / 1440×900 实机播放、方向和跑动脚滑检查（当前工作区只读，未运行）
- [ ] 原有其余五组动作身份、动作帧、大小一致性重绘
- [ ] 检查红色边缘残影、透明边缘色块与全部帧的质量
- [ ] 负责人视觉批准及授权审查

**说明：** 本图集是可加载/预览候选，不代表已批准成品；旧版仍为唯一在用图集。
