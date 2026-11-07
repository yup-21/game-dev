# 实际图像生成提示词 · 沈长风 GIF v01

输入参考：`art-production/candidates/characters/shen_changfeng/baseline/character_shen_changfeng_identity_sheet_v01.png`。第 2、3 批还参考了最终第 1 批 `source/sprite_shen_changfeng_batch1_5x5_source_v01.png`；均启用 `transparent_background=true`。以下为**最终选用的实际提示词**，无补造模型编号或 seed。

第一次试生成三张母图时，多数格位贴近边缘（合计 70/75 个源格边距警告）；一次纯颜色编辑尝试也未能消除源图问题。上述试稿仅保留在生成会话工作区，未作为正式候选提交。随后使用下列更大格间留白提示词重新生成三批，最终 14/75 个源格仍需复核。

## 批次 1（最终选择）

```text
Generate a NEW hand-painted 2D wuxia game animation sheet with exactly 5 columns and 5 rows, 25 individual transparent panels, 25 different full-body action poses. Match attached Shen Changfeng design faithfully: young slim male swordsman, weathered muted blue-black robe, ivory layers, long black hair half-tied with jade hairpin, bronze sash, dark soft boots, ONE right-hand straight silver sword. Camera strictly right-facing 90-degree profile, stable proportions. IMPORTANT COMPOSITION: make each full figure SMALL, occupying only 65% of each cell height and at most 68% of cell width, centered in each cell, with visibly WIDE transparent gaps between all rows and columns; the complete hair, sword tip, feet, robe hem must NEVER reach any cell edge. Same ground baseline near 80% of cell height. No line separators, text or effects. Distinct poses in exact row-major order:
Row1 idle breath-in; idle breath-out; idle rear foot weight shift; idle reset; walk raise right heel.
Row2 walk right stride forward; walk right foot plant; walk left swing forward; walk left heel lift; walk left stride.
Row3 walk left foot plant; walk cycle reset; run low start; run drive right knee; run airborne extension.
Row4 run right landing; run left power push; run left knee high; run alternate airborne stride; run left landing.
Row5 attack1 prepare sword point forward; attack1 knees compress; attack1 right arm begins thrust; attack1 full forward straight sword thrust; attack1 hold thrust follow-through.
All frames on true transparent background, clean isolated silhouettes, no contact between neighboring figures.
```

## 批次 2（最终选择）

```text
NEW hand-painted Chinese wuxia 2D action sprite sheet, EXACTLY 5 COLUMNS x 5 ROWS, 25 equal transparent cells, 25 full-body distinct poses. Precisely match attached Shen Changfeng identity: slim young swordsman, muted weathered blue-black robe, ivory inner layers, long half-up black hair with jade hairpin, dark boots, bronze sash, ONE silver straight sword right-handed. RIGHT-FACING STRICT SIDE VIEW in all 25 cells, consistent figure size, fixed foot ground baseline. MANDATORY SPACING: each figure and its complete sword only uses central 65 percent of cell height and no more than 68 percent of cell width; leave wide clean alpha gutters around EACH cell, do not let hair, cloth, feet or sword reach cell boundaries. Separate each row by a visually wide transparent gap. No boxes, numbers, text, scene, shadows, light streaks, duplicates, or colors other than original costume. Row-major assignments:
Row1 attack1 sword retracts from straight thrust; attack1 restored neutral guard; attack2 relaxed start; attack2 lift blade to shoulder; attack2 blade raised overhead.
Row2 attack2 plant foot and start descending cut; attack2 direct vertical slash; attack2 sword low follow through; attack2 neutral guard recover; attack3 wind-up turn hip.
Row3 attack3 draw blade across waist; attack3 rear foot brace; attack3 begin horizontal slash; attack3 horizontal sword extension; attack3 follow through.
Row4 attack3 recover guard; attack4 low heavy charge start; attack4 sink hips; attack4 sword lifts diagonal; attack4 maximum compressed charge.
Row5 attack4 explosive lead step; attack4 heavy diagonal sword cut; attack4 wide follow-through; attack4 recover upright; skill begin sword-finger seal left hand and sword in right.
Preserve same face, single sword, proportions and clothing through all 25.
```

## 批次 3（最终选择）

```text
Produce a NEW 5 columns x 5 rows transparent 2D Chinese wuxia action animation sprite sheet for Shen Changfeng. Exactly 25 separate equally spaced cells, stable RIGHT-FACING STRICT SIDE PROFILE. Match two attached references: youthful slim swordsman in weathered blue-black layered robe, ivory underrobe, half-up dark hair with jade pin, bronze belt, dark shoes, ONE silver straight sword in right hand. Finely hand-painted RPG side-view character, original martial arts illustration. COMPOSITION IS CRITICAL: draw every complete figure SMALL at 65% of cell height and 68% max width, centered with exceptionally WIDE TRANSPARENT GUTTERS on all four sides of every individual frame, including hair, raised blade, cloak, soles and lying body. No cropped objects, no overlap, no floor, no shadows, no visual effects, no blood, no color streaks, no text, no borders. Keep foot baseline consistent for standing characters.
25 poses in row-major sequence:
Row1 skill left-hand sword-finger seal; skill focused crouch; skill lift blade diagonally; skill sword release gesture; skill sword extending in attack.
Row2 skill balanced recovery; evade bend knees preparing backward movement; evade push off forward foot; evade short backward airborne hop; evade opposite foot landing.
Row3 evade regain balance and neutral guard; guard diagonal blade across chest; guard front foot braces; guard high sword block; guard elbow compresses under impact.
Row4 guard return to neutral sword position; hit startled shoulder recoil; hit torso leans backward; hit back foot catches balance; hit recovery to sword guard.
Row5 defeat stumble and lose footing; defeat knees buckle; defeat kneel with hand on ground; defeat collapse on side with ONE sword by hand; defeat still prone body lying on ground.
One figure and one sword per panel with transparent spacing between all panels; all costume colors muted, no red or yellow sparks.
```
