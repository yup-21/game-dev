# 原创武侠角色立绘（阶段性素材）

本目录是下一轮非像素 HD-2D 美术改造的**原画参考**，不覆盖现有可运行的 SVG Sprite Sheet。

| 文件 | 角色 | 当前用途 |
| --- | --- | --- |
| `shen_changfeng_portrait.png` | 沈长风，青碧色江湖剑客 | 高清角色设计、后续对话立绘/出牌 UI 视觉锚点 |
| `escort_captain_portrait.png` | 受伤的老镖头，朱红/墨色外袍 | 序章角色设计、后续对话立绘视觉锚点 |

均为项目本轮原创生成的 1024×1536 PNG，尚未做逐像素透明度验收、动画拆层、atlas 排布或 Godot 实机测试。图中可能存在深色背景/边缘；**不要直接把它们作为透明 Sprite3D 战斗人物**。

待完成：
1. 验证 alpha，精修立绘背景、肩发丝和剑柄边缘。
2. 在固定角色设计下制作 Idle、Run、Draw、Slash、Guard、Hit、Combo 动作关键帧，检查身份、比例与武器方向一致。
3. 生成帧序列、统一裁切、足点与 hitbox，导入 Godot `SpriteFrames` / `AnimationPlayer`。
4. 独立多人 HD-2D 场景接入 `GameSession.encounter_options()`、`BattleModel`，并以卡牌 UI 重新组织动作。

这两幅原画是可复用的素材交付，并不意味着上述动画系统、剧情桥接与 UI 重构已经完成。
