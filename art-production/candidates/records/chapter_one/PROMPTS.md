# 第一幕扩展美术 · 图像生成记录 (2026-11-01)

## 来源与限制

- 生成工具：ChatGPT 内置 image generation，实际模型号与 seed 未暴露，无法补造。
- 仅用于 `concept / needs cleanup`。图像生成的 6×4 帧稿**不等于**可直接使用的逐帧 Alpha 动画。
- 参考：`ART_PRODUCTION_STANDARD.md`、`ART_STYLE_AI_PROMPTS_V1.md`，人物身份取自 `data/native/characters/*.tres`。未使用已批准身份板作为工具图像输入，需后续锁定身份。
- 除老镖头负伤姿态、动作图集参考当前会话新立绘外，其余均为文本提示；请勿写成“已有人工审核参考图”。

## 通用角色立绘提示词（各角色身份段附后）

```text
Use case: stylized-concept. Asset type: formal game character fullbody portrait candidate.
[IDENTITY AND COSTUME LOCK]
Premium original hand-painted Chinese wuxia 2D illustration consistent with a blue-gray rain-night HD-2D RPG.
Silk/cotton/leather/steel material realism with subtle ink-wash brush texture, expressive natural anatomy,
elegant clear silhouette and restrained lighting. One full body character seen in slightly elevated game illustration view,
head-to-toe shoes and complete weapon visible, ample 10% transparent safety margin. Identity must be stable for
later matching battle sprites. No environment, no floor, no text, no labels, no UI, no extra character, no frame border,
no watermark, no pixelated texture, no 3D, no anime. Transparent RGBA true alpha background.
```

| id | Prompt 身份段及造型锁定 |
| --- | --- |
| `gu_qingshuang` | Original wuxia heroine Gu Qingshuang, late 20s, quiet female guardian, pale frost-blue and blue-gray silk fighting robes, dark belt, high tied black hair, silver ornament, slim straight sword, measured defensive stance. |
| `green_wanderer` | Original male Qing Shan Ke, 30s, mysterious wanderer in old worn jade-green travel robe, dark inner layer, wrapped arms, boots, black hair knot, straight sword, plain satchel, lean agility. |
| `black_blade` | Original male Black Blade fighter, broad shoulders, charcoal-black and rust layered cloth armor, wrapped forearms, broad dark steel saber, muted flame-red waist cord, frontal strength. |
| `night_assassin` | Original female/androgynous night assassin, violet-black close-fit cloth layers, indigo hood-collar, tied black hair, twin short blades, sleeve needles, eyes visible, slim stealth silhouette. |
| `escort_elder` | Original 60-year-old wounded escort elder, gray hair/beard, weathered face, ink-blue aged cotton coat with faded ochre trim, bandaged bloody shoulder, rolled silk scroll and sheathed saber. |

## 通用动作图集提示词

```text
Use case: stylized-concept. Asset type: transparent 2D wuxia RPG sprite animation atlas source candidate.
Use the same character portrait identity. Precisely align 24 different frames in 6 columns x 4 rows,
256x256 cells, 1536x1024 atlas; no gutters, captions, grid strokes or outside background.
All frames share a slightly elevated three-quarter game camera, scale, foot contact baseline and material palette.
Frame order: idle 2; move 4; attack 3; guard 2; hit 2; evade 3; skill 3; combo 3; defeat 2.
Distinct startup, active, recovery gestures; all weapons stay within cell margins; true RGBA transparency.
Do not add text, label, watermark, floor, environment, matte, UI, extra figures or 3D render.
```

- 顾清霜：细剑试探/横斩、霜蓝剑光、化劲格挡。
- 青衫客：直剑突刺、快速踏步、青绿色风痕；布带与挎包不得漂移。
- 黑衣刀客：重刀劈砍、离火红橙劲、厚重身形、近身格挡。
- 夜行刺客：双短刃交错、袖针发射、紫色急速残影。

以上源稿的实际动作可能越出单格、存在底色/脚点漂移，因此不得将模板约束误记为已通过的技术结果。

## 破庙场景母版生成提示词

```text
Use case: stylized-concept. Asset type: game environment master for 1600x1000 logical 16:10 scene.
Late autumn rainy Jiangnan night, muddy mountain road ending at abandoned mountain-spirit temple,
blue-gray stones, wet bamboo, a small amber oil lamp, old grey roof tiles and ruined walls.
Broken escort cart with snapped shaft, cloth canopy, crates and rope to right-middle but not blocking road.
Fixed elevated 2.5D camera with wide clear road in lower middle, playable feet near (350,705) and (1050,560),
walkable bounds approximately x155-1415/y345-755. Natural materials, premium original hand-painted wuxia
HD-2D scene, restrained ink texture and muted blue gray/green palette. No characters/UI/text/grid/3D/watermark.
No baked rain streaks; weather to be independent.
```

## 老镖头负伤姿态修订提示词

参考同批 `portrait_escort_elder_fullbody_v01.png` 的身份，在同衣着、灰发、绢帛与伤口位置基础上制作三分之四视角的坐姿：靠近想象中的镖车、肩背疲惫、卷轴握在手中、腿脚完整、真正透明，不包含镖车或地面。生成过程中没有暴露 seed。

## 后处理与审核

- `prepare_chapter_one_assets.py` 审计尺寸、Alpha 与单格四角；生成破庙同源分层和独立天气，但不把自动切片说成手工绘制图层。
- 正式动作 atlas 应由每一格真实透明且补绘完整武器的关键帧再装配，当前未达到最终批准条件。
