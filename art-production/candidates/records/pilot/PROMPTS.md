# 2026-11-01 生产提示词与来源记录

- 生产工具：内置图像生成；模型具体代号与 seed 未返回，记为 unknown，不编造。
- 全部图像按照 `ART_STYLE_AI_PROMPTS_V1` 的原创国风精细手绘和 HD-2D 构图约束生成。
- 透明立绘/图集使用同批设定板与立绘作身份参考；机器拆层/装配步骤由 `tools/prepare_pilot_assets.py` 复现。
- 以下是生成时提交的提示词全文。非自动权属证明。

## 沈长风设定板

```
Use case: stylized-concept. Asset type: production character identity sheet, candidate, for original Chinese wuxia 2D HD-2D RPG "长风浮生录". Character Shen Changfeng (沈长风): young adult male wandering swordsman, cautious, trustworthy, former martial hall disciple, long straight steel jian. Muted ink-teal and storm-blue layered short travel robe over natural linen, worn leather belt, dark hair tied in a simple topknot with narrow jade-colored pin, modest cloth boots, one subtle copper/amber cord at scabbard. Distinct understated silhouette and realistic fabric/steel. Display consistent front, 3/4, back, side full-body turnaround silhouettes, weapon closeup and fabric/palette swatches, on warm neutral matte studio design board, same head/body proportions and costume across all views. Premium hand-painted Chinese wuxia painterly illustration with restrained ink wash, not pixel art, natural brush texture, clear silhouette, faithful anatomy. Full bodies all visible and complete, no cut-off toes or swords, no backgrounds, no labels or characters/text/logos/watermarks, no 3D, no anime/chibi. The identity must be reusable as immutable reference for portrait and sprites. Landscape board.
```

## 追镖首领设定板

```
Use case: stylized-concept. Asset type: production enemy design identity sheet, candidate, for same original Chinese wuxia HD-2D RPG. Enemy "Pursuer Captain" (追镖首领): imposing battle-hardened middle-aged male leader of mysterious pursuit, stern cold obsessive bearing, wields heavy single-edged broad dao saber, not a straight sword. Dark charcoal and subdued cinnabar garments, weather-worn leather lamellar vest, crimson binding around right forearm, utilitarian dark cap/knotted hair, robust broad-shouldered silhouette, old scar along jaw, iron belt plates, black boots. Show consistent front, 3/4, back, side full-body turnaround, heavy saber close-up, small color/material swatches. Restrained original Chinese wuxia premium 2D painterly art with subtle ink wash, natural wet steel, leather, cloth, not anime, no pixel art. Flat warm neutral studio background design sheet, all feet and weapons fully within frame. No text, labels, logo, UI, watermarks, extra characters, 3D render.
```

## 断桥场景母版

```
Use case: stylized-concept. Asset type: master environment concept for a 1600x1000 canvas, 16:10 fixed HD-2D camera for Chinese wuxia tactics RPG. Rainy broken bridge over southern mountain ravine at autumn dusk/night. Precise playable composition: a broad horizontal old-stone bridge traverses left-to-right across the center around y 45-55% of the canvas, six characters can stand in evenly spaced positions across it. River flows vertically from top center to bottom center under the bridge; blue-black rapids, mossy cliffs, bamboo banks on both sides, damaged bridge parapet and hanging amber lantern on far right bank. Left and right stone paths connect to bridge. Wide low-contrast empty playable central bridge deck, visible ground contact plane, no split decks, camera is fixed gently elevated 2.5D orthographic oblique, no extreme perspective. Distant blue mountains and wet bamboo silhouettes in top third; nearest dangling bamboo and cracked railing can act as independent foreground masks later. Premium original Chinese wuxia painterly 2D environmental illustration, refined stone, wood, wet foliage, restrained ink wash, muted storm blue, teal greens and one warm lantern. Cohesive with heroic Shen Changfeng and Pursuer Captain identity sheets, but NO characters. No UI, text, grid, chessboard, bright effects, watermark, 3D.
```

## 沈长风透明立绘

```
Use case: stylized-concept. Asset type: game-ready transparent RGBA full-body character portrait. Use the Shen Changfeng character identity sheet among the three recently generated images as IMMUTABLE reference (the young slim straight-sword traveler, blue-gray robe, pale inner linen, long tied black hair, jade hair pin, worn dark boots). Ignore the other images. Create one original Chinese wuxia swordsman in balanced vigilant stance, full straight jian sword visible, precise face likeness, costume folds, sword fittings, dark boots and scabbard cord consistent with Shen identity sheet. Polished premium 2D hand-painted art, refined fabric and steel, subtle watercolor and ink accents, clean contour for game cutout, no photo or 3D. Single fully visible full-body subject on genuinely transparent background, no shadow or ground, no text, no labels, no decorative board, no panels, 10% safety margin around hands sword feet and hair.
```

## 追镖首领透明立绘

```
Use case: stylized-concept. Asset type: transparent RGBA full-body enemy portrait. Use the Pursuer Captain identity board among the three recent images as exact character reference (older broad-shouldered scarred bearded captain with dark charcoal armor, red worn scarf and right forearm red bindings, heavy single-edged dao blade). Ignore other characters and landscape. Draw a single intimidating but realistic original Chinese wuxia villain in guarded heavy saber stance, full weapon and boots in frame, detailed weathered iron, cloth and leather. Same facial features and silhouette as sheet, crimson black palette restrained. Premium hand-painted 2D illustration with subtle ink washes, no 3D, no photorealism, no anime. Genuine transparent RGBA background, no scenery, ground plane or drop shadow, no text, logo, UI, labels, or frames.
```

## 沈长风 V1 初稿

```
Use case: stylized-concept. Asset type: production animation sprite sheet candidate for 2D wuxia RPG in a single transparent RGBA PNG. MUST reference Shen Changfeng's identity board among the three recent generated images, keep identical young face, dark tied hair, ink-blue worn robe, cream underlayer, scabbard and long straight jian in all panels. Exactly 6 equal columns by 4 equal rows (24 chronological panels total) in a strict edge-to-edge uniform orthographic 2.5D game sprite layout, no lines or gutters. Each panel must contain only ONE complete full-body same-scale character with ground contact at identical location and feet clear. Reading left-to-right, top-to-bottom 24 poses: 0-1 idle subtle breathing, 2-5 four distinct stepping run phases with weight shift, 6-8 sword attack startup/active slash/recovery, 9-10 guard raise/hold, 11-12 hit stagger/recover, 13-15 dodge crouch/slide/recover, 16-18 skill preparation/sword thrust/followthrough, 19-21 combo winding/double-slash/final landing, 22-23 defeat collapse/lying. Genuine transparent background in every tile; no cast shadow, no environment, no white matte, no text, numbers, panel border, title, UI. Uniform size and camera, coherent weapon and cloth trajectory from panel to panel. Illustration style: original hand-painted painterly martial arts 2D game sprite, sharp silhouette and simplified textures for small scale, muted blue-gray and natural steel. NOT a poster or nine unrelated character poses.
```

## 追镖首领 V1 初稿

```
Use case: stylized-concept. Asset type: production animation sprite atlas candidate for 2D wuxia RPG, transparent RGBA PNG. MUST copy Pursuer Captain character identity from the dark charcoal and muted crimson armor/cape heavy saber character sheet among three recent images. Older scarred bearded broad-shouldered man with same outfit, same broad single-edged heavy dao in ALL frames. Exactly 6 equally spaced columns x 4 rows = 24 frames, consistent center, scale, baseline, 2.5D orthographic camera, no dividers or gutter. Reading row major: 0-1 idle subtle breathing; 2-5 four unique heavy jogging phases; 6-8 heavy saber attack windup/swing/followthrough; 9-10 guard brace/hold; 11-12 hit recoil/recover; 13-15 evade crouch/backstep/recover; 16-18 skill overhead charge/chop/recovery; 19-21 combo two broad saber arcs/final slash; 22-23 defeat kneel/fall. Motion progression must read as animation, not random illustrations. Original Chinese wuxia hand-painted 2D sprite with restrained ink wash, clear silhouettes and natural armor/leather/fabric. Every character and sword fully contained in its own frame, common feet anchor. True transparent pixels behind figures, no floor shadows, no grid lines, no titles, captions, labels, text, UI, background, additional props.
```

## 沈长风 V2 修订

```
Use case: precise-object-edit. Edit the recently generated SHEN CHANGFENG blue-robed 6x4 transparent animation atlas, not the red armored enemy. Use the Shen Changfeng transparent portrait in recent images as strict identity reference. FIX ONLY sprite layout and scale/crop issues. Preserve same 24 chronological actions and same blue clothes/long straight sword, hairstyles and facial details. Exactly six columns and four rows, 24 independent equally sized square sprite CELLS. Reduce EVERY full-body character AND weapon uniformly to about 65% of previous apparent scale, ensuring a MINIMUM 12% completely empty transparent safety margin on ALL FOUR EDGES of EVERY cell, even at maximum sword thrust. Feet contact point must be stable near 82% cell height (for upright frames), body scale fixed. No silhouette, sword, scarf or hair from any frame may reach or cross into its neighbor cell. Keep dynamic distinct movement phases with 0-1 idle,2-5 run,6-8 attack,9-10 guard,11-12 hit,13-15 dodge,16-18 skill,19-21 combo,22-23 defeat. Truly transparent RGBA not gray background; no shadows, dividing lines, labels, grid text, UI. Original premium Chinese wuxia painterly 2D game sprites. This is a technical atlas layout correction, do not re-design the character.
```

## 追镖首领 V2 修订

```
Use case: precise-object-edit. Edit the recently generated PURSUER CAPTAIN dark-red-armored heavy-dao 6x4 transparent sprite atlas (not the blue hero). Use the red armored Pursuer Captain transparent portrait as strict identity reference. FIX overflowing silhouettes, unsafe blade cropping and inconsistent feet baseline. Exactly SIX columns and FOUR rows (24 equal square tiles). Every frame contains complete single character with the whole heavy curved dao and flowing red cloth, at approximately 60% of previous apparent size; minimum 12% empty transparent margin to all tile edges. Same character scale and feet contact at 82% cell height when standing, no elements touch cell boundaries, no overlap between tiles. Maintain 24 row-major distinct action phases: 0-1 idle, 2-5 run, 6-8 heavy slash, 9-10 guard, 11-12 hit, 13-15 evade, 16-18 overhead skill, 19-21 double combo, 22-23 defeat. Same dark charcoal iron armor and dark crimson scarf, jaw scar and broad dao all frames. Genuine alpha without background, matte, border, words, icons, UI, captions. Premium original wuxia hand-painted 2D sprite style.
```

