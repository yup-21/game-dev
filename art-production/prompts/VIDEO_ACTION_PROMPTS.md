# 图生视频动作描述（候选母提示词）

先上传由负责人确定身份的角色设定图。同一角色的所有动作都复用此图，不得把未批准的新侧面参考直接作为正式在用美术。每次单独生成一个动作 MP4。

## 所有动作统一约束

~~~text
Original hand-painted 2D Chinese wuxia action game animation. Use the attached
approved character sheet as the strict identity reference. Fixed 90-degree
orthographic side-view camera facing right, same scale and character identity
throughout, complete body and one complete straight jian in the right hand,
left hand empty. Exact same hairstyle, layers of clothing, shoes and palette.
Natural weight transfer and planted support foot. Fixed ground line.
No camera movement or zoom, no morphing, no extra limbs or second sword,
no motion blur, no lighting flicker, no cuts, no baked-in combat VFX.
Plain uniform background for clean background removal.
~~~

## 先验证四个动作

| Godot action | 时长建议 | 起手—有效—收势 | 力学 |
| --- | --- | --- | --- |
| idle | 2 秒 | 轻微呼吸→衣摆发尾延迟→回初姿 | 后脚锁定、零根位移、无循环接缝 |
| move | 1 秒 | 左右脚交替着地→离地→摆腿→首尾衔接 | 建议原地走路循环，游戏控制世界移动 |
| attack | 1.2 秒 | 0–0.3 蓄力→0.3–0.65 向前直刺→0.65–0.8 有效定势→0.8–1.2 收势 | 后脚蹬地、前脚承重、单手剑、无后退瞬跳 |
| guard | 1.2 秒 | 屈膝架剑→缓冲→短暂定势→收剑 | 防御承重阶段前脚锁定、剑不换手 |

其余动作按角色技能制作：hit 受击→退让→恢复；evade 蹬地→位移→落脚；skill 独立技能前摇→有效→收招；combo 连续剑招需明确每次承重转换；defeat 失衡→倒地→躯干着地（末帧不强求鞋底作为支点）。

建议先以 24 FPS 生成高质量原视频，提取时可选择 12、16 或 24 FPS；模型不能可靠保证帧间脚点和精确尺寸，必须按 ../tools/VIDEO_TO_SPRITE.md 实施技术与人工验收。
