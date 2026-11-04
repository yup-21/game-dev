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

## 正交构图修订：v02

- 输入图 1：`environment_pingjiang_south_gate_master_v01.webp`（需要修订的画面及风格）。
- 输入图 2：`art-production/guides/pingjiang_south_gate_parallel_1600x2000.svg` 的 800×1000 PNG 渲染（几何布局约束）。
- 输出候选：`environment_pingjiang_south_gate_master_v02.webp`，源图 1122×1402 RGB，归一为 1600×2000 WebP，质量 90。

```text
Use case: precise-object-edit of the first reference image, combined with the second reference as STRICT geometry layout.
GOAL: repair the severe false perspective in PJ-01 vertical wuxia game map without sacrificing its polished painterly style. Input 1 is the existing beautiful Pingjiang South Gate illustrated level (STYLE and content to preserve); Input 2 is a FLAT schematic of the mandatory orthographic layout, with a truly rectangular no-taper north-south passage (GEOMETRY to follow). Final output must look like image 1's rich original handpainted late-autumn Jiangnan town, NOT like a flat diagram, but MUST follow image 2's uniform corridor geometry.

Canvas vertical 4:5 aspect, one continuous 1600x2000 world map, fixed 1600x1000 horizontal viewport scrolling vertically. Orthographic parallel-projection 2.5D camera, a high oblique strategy-game view that has 3D-looking building façades and roofs but NO distance shrink, NO vanishing point. All ground level elements equally sized regardless of vertical placement. The central gray stone road occupies x=620..980 (360px wide) FROM THE TOP EDGE to bottom edge, straight and parallel. Its two long curb edges should be vertical and parallel from top to bottom. Gray brick and pavement tiles same pixel scale at top y=100, middle y=900 and bottom y=1900, rows/horizontal mortar lines also same spacing at all depths. At Y=600..1030 massive Wengcheng blue-gray brick battlements and gatehouses on the left and right, connected visually by an arched gate overhead, with a raised portcullis but a FULL 360px-wide open walkable central gap. No walls, steps, railings, stalls or drawbridge obstructions encroach on x=620..980. At Y=1050..1570 wide blue-green moat to both sides, a uniform rectangular 360px-wide stone bridge over the water, with parallel straight stone parapets and chains (no bridge trapezoid, zero convergence). At Y>1570 road continues straight into the bottom edge, side notice board and guard checkpoint. At Y<600 road proceeds straight through compact white-plaster black-tile autumn Jiangnan inner city. Side buildings stay substantially the SAME SCALE from top to bottom and do not diminish into a foggy vanishing point. No blue horizon sky, no central infinite-depth road, no distant miniature architecture.

IMPORTANT: This is a 2D ACTION RPG WALKABLE MAP, not a front-facing cinematic scene and not a bird's eye city plan. Real-world lengths in X/Y correspond to fixed Godot screen/world pixels, 1 game unit=80px; player visible height fixed 200px independent of Y, collision foot radius 24px. Use image 2 only as exact coarse shape, align buildings and water to it; don't paint diagram's solid colors or lines, text, labels, guides, silhouettes or UI. Preserve the mood, carved architecture, autumn willow/maple, lighting, detailed cobblestone, wood guardhouse, winch, water gate and boat motif of image 1; redraw their placement and perspective to obey the fixed projection.
A clean master illustration, no characters, no watermark, no labels, no perspective road taper. BOTH road and bridge constant width 360px; absolutely NO converging edges.
```

## 正交构图修订：v03（首选继续精修）

- 输入图 1：与 v02 相同的固定几何参考（**主构图**）。
- 输入图 2：`environment_pingjiang_south_gate_master_v01.webp`（**仅画风、材质和色彩**）。
- 输出候选：`environment_pingjiang_south_gate_master_v03.webp`，源图 1122×1402 RGB，归一为 1600×2000 WebP，质量 90。
- 拒绝的中间尝试：将 v02 桥面局部放大，导致不同 Y 区域道路宽度进一步失配，未入库。

```text
Use case: sketch-to-render. DRAW a polished original wuxia game environment by rendering Input Image 1 (the EXACT layout blueprint) as a rich 2D painting using Input Image 2 ONLY as art-style/material/color reference, not as geometry reference.
LOCK THE PLAN of Input 1. The first picture is a flat schematic showing a 1600x2000 scrollable vertical playable map, fixed orthographic-parallel camera. Carefully keep its geometry: a straight centered vertical cobblestone road exactly 360px wide, with x=620 and x=980 edges PARALLEL and UNCHANGED from the upper edge of the canvas to the lower edge. The walled Jiangnan south gate at mid-height is two large gray castle masses left/right with 360px open gap, 2 watchtowers, guard booth and wooden winch. The central road goes freely through that gateway. The river is a horizontal 520px-high span across the canvas at Y≈1050–1570 on the left and right sides of the bridge. The bridge is a true RECTANGLE with parallel side railings at x=620 and 980, the same 360px width as the road and gate. The top city street from y=0 to gate and the bottom road from bridge to edge are precisely the same width. The buildings to left/right are the SAME sprite-compatible size at top and bottom, no diminishing small distant buildings. The ground paving stones and mortar joints are identical size along all Y rows. The schematic's color shapes are only geometry annotations to be replaced by natural detailed painted materials; don't retain or reproduce its flat color palette.
Now render in the established Pingjiang PJ-02/PJ-01 autumn Chinese handpainted style in image 2: artful gray ancient brick fortress and parapets, dark tiled curved roofs, pale plaster townhouses, aging wood, orange maples and willow leaves, mist-free soft daylight, subtle warm lanterns, moss and weeds, watery blue-green moat and wooden dock boat, autumn notice board and checkpoint. Detailed but legible 2.5D action RPG level art, no artifical perspective depth. Architectural orthographic projected oblique façades and roofs allowed, but no vanishing point, no taper, no triangular or trapezoidal road/bridge, no shrinking characters. Entire portrait 4:5 world map, not a top-down geographical plan; no text, no characters, no diagrams, no colored grid, no watermarks.
The core task is painting image 1 without ANY geometric change; visual style and texture come from image 2.
```

本次两次候选均通过内置 ImageGen 生成／编辑，**图像几何仍须按标注复核**。同尺寸重采样只完成文件尺寸归一，不保证物体投影比例。
