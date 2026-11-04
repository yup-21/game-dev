# PJ-01 南门 v01 生成提示记录

- 生成模式：内置 ImageGen，`stylized-concept`，新图生成。
- 视觉参考：PJ-02 `environment_pingjiang_crossroads_master_v02.webp`；仅用作江南深秋手绘色彩、材质、镜头参考，不复用十字路口建筑结构。
- 生成源画幅：1122×1402 RGB；按整图等比例近似重采样到正式候选 1600×2000，导出 WebP（质量 88）。源比例与目标 4:5 的差异低于 0.04%。

## 母版生成提示词（内容留档）

```text
Use case: stylized-concept. Asset type: game environment candidate MASTER painting, PJ-01 平江瓮城正南门, for original 2D wuxia RPG 长风浮生录. Create a NEW distinct environment, not an edit of the attached reference.

REFERENCE IMAGE: The attached image is the established PJ-02 city crossroads art direction only: hand-painted detailed Jiangnan late-autumn background, pearl white plaster, dark blue-gray curved tile roofs, misty trees, old gray stone pavement, muted faded colors, warm lanterns; same camera angle/scale/material rendering, same season, and legible 2.5D game walkable ground. Do not copy its shops or large ornamental crossing arch.

CANVAS: Vertical long level world canvas 4:5 aspect ratio, target 1600 px wide x 2000 px high, representing two vertically adjacent 1600x1000 gameplay viewports with scrolling. One coherent long environment, not two screenshots, not a map overview, no borders/seam. Top edge is NORTH toward city crossroads; bottom edge is SOUTH toward countryside. The player's north-south walking axis is a straight, genuinely connected paved corridor centered at x=800, around 360 px wide, constant visual and physical width all the way through both top and bottom edges; preserve a clear walkable central band, with enough room to walk in both directions. Fixed gently elevated oblique orthographic 2.5D game camera, shallow perspective and parallel ground axes; no vanishing point or dramatic road taper, no flying bird's-eye floor plan, no cinematic horizon, no fish-eye, no 3D render.

LAYOUT along vertical Y axis from top to bottom: (top 0-500) enclosed inner Pingjiang city approach with distant low houses and traditional streets, straight pale gray paving leading down; (500-1100) monumental heavy blue-gray brick outer walls of an historic Jiangnan Wengcheng barbican and tall central open arch gateway with raised iron portcullis, flanking watchtowers, battlements, wood-and-iron winch and chain near the side, guardhouse to the right; main PASSAGE CLEAR and traversable through open gateway, no sealed doors; (1100-1650) stone-pier drawbridge over a broad blue-green moat/canal on both sides, long vertical gray cobblestone bridge aligned with gateway and visibly walkable from end to end, old iron chains anchored at sides, a secondary water-control sluice and wooden river patrol jetty to the side, not crossing central path; (1650-bottom) compact outer approach of the bridge with rural stone road continuing straight out of bottom edge, sparse orange reeds and autumn trees, isolated notice board for wanted posters and guarded checkpoint placed OFF the road to the sides. Sculptural historical gray bricks, subtle autumn gold/red foliage, shaded water with reflections, ropes, lantern glow. No people painted onto background: guards/NPC to be game sprites.

CRITICAL SCALE CONTRACT: Consistent image-plane scale 1 game unit = 80 world pixels; player should appear approximately 200 px tall everywhere, without any depth-based shrinking. Stone gate usable opening on gameplay ground visually ~260-304 px high and sufficiently wide, road corridor 360 px across at near AND far ends. Symmetric architecture but not identical mirrored details. Only one coherent continuous central path from upper to lower edge, not a courtyard that stops at the city gate. Space for collision and scenery layers and separately overlaid characters.

OUTPUT: Beautifully finished, detailed hand-painted 2D background painting, no text, no labels, no UI, no coordinate grid, no direction arrows, no logos, no watermark. Avoid photorealism, high camera pitch, giant top-down miniature, exaggerated perspective, architecture blocking walking, characters/guards baked into image. Make this a vertical 4:5 illustration, not horizontal 16:10.
```

注意：提示词中的固定比例与像素精度并不等于模型实际满足；见 [QA.md](QA.md) 逐项验收。
