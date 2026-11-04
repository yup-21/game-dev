# PJ-02 AI 原始生成提示词（2026-11-04）

以下按执行顺序记录完整请求。第一步 `imagegen` 使用了 `scene_scale_guide.py` 生成的透明尺寸引导图作为**构图参考**，第二、三步使用上一张母版作为**图层编辑目标**；三次均为内置图像生成工具。未记录不可获得的随机 seed。

## 1. 完整概念母版

- 输入参考：`/tmp/pj02_scale_reference.png`（使用仓库工具生成，非提交资产）
- 透明输出：否
- 原始输出：1586×992 RGB PNG
- 仓库候选：`environment_pingjiang_crossroads_master_v01.webp`（整体重采样 1600×1000）

```text
Use case: stylized-concept. Asset: original 2D hand-painted game environment concept master for 《长风浮生录》, PJ-02 平江四街十字路, Suzhou Jiangnan Song-era wuxia city. The attached transparent calibration image is ONLY A SPATIAL PLANNING GUIDE: retain its empty cross-shaped traversable road topology but DO NOT reproduce any colored guide rectangles, guide figures, grid lines, scale text, arrows, labels or overlays. Fixed 16:10 landscape 2.5D slightly elevated oblique gameplay camera, with NO dramatic vanishing-point perspective. Exact four-way connected stone-paved street crossing: broad horizontal walkable stone street in lower part of frame, approximately y=620–940, continuous to both left and right image edges; a visually clear north-south stone lane, approximately x=640–960, extends from the far top image edge down through the center of the horizontal road and to the near bottom image edge. Real unobstructed open ground where these corridors overlap, enough for a game character to move in X and Y. Chinese southern riverside city architecture all around the road: white lime-plastered walls, charcoal gray curved tiled roofs, weathered wood timber frames, compact old merchant buildings, a landmark elegant stone ceremonial archway overlooking but NOT blocking the lane, one small storyteller tea stall outside the path, one readable notice board without any writing, discreet traveling merchant stall, a clothier storefront and a pawnshop doorway at the road edges. Calm late autumn early evening with blue-gray stone, muted jade green and small warm amber lanterns; rich handcrafted textures, restrained ink-wash strokes, detailed but quiet background, crisp playable ground. An original production-quality painted wuxia videogame environment with DNF-like street density but wholly original architecture, not copying any game. Preserve large clear unobstructed ground planes and logical 200px humanoid door scale (doors about 280px tall). No humans, NPCs, test figures, UI, written words, signs with letters, floating names, scale bars, grid, compass, overlays, logos or watermark. Compose as a seamless whole scene master that will later inform separate background, ground and foreground layers.
```

## 2. Ground 透明分离草稿

- 输入参考：第 1 步完整母版
- 透明输出：是
- 原始输出：1585×992 RGBA PNG
- 仓库候选：`scene_pingjiang_crossroads_ground_draft_v01.webp`（1600×1000）

```text
Use case: background-extraction. EDIT TARGET: the attached PJ-02 Jiangnan four-way crossroads hand-painted map master. Create a transparent RGBA GROUND LAYER ONLY for this exact same map, with the precise same camera, perspective, stone paving arrangement and coordinate layout. Preserve the visible cobblestone / stone-slab walkable roads exactly as they appear in the original, including the central cross, the entire horizontal street from left edge to right edge in the lower half, the north-south lane down the central section from the top archway to bottom edge, worn joints, small natural leaves, and subtle original shadows on paving. Every pixel that represents architecture, sky, canal, shop, roof, lantern, tree, stall, vegetation, archway, doorway, railing, or any object above the walking plane must become truly transparent with alpha 0. Preserve clean antialiased road boundaries, transparent outside the road; do NOT fill with opaque white/black. Do not introduce new props or alter the road boundaries. No words, grid, markings, characters, watermark. This layer is a candidate for game-compositing registration; maintain identical camera and landmark positions to source.
```

## 3. Background 透明分离草稿

- 输入参考：第 1 步完整母版
- 透明输出：是
- 原始输出：1585×992 RGBA PNG
- 仓库候选：`scene_pingjiang_crossroads_background_draft_v01.webp`（1600×1000）

```text
Use case: background-extraction. EDIT TARGET: attached original PJ-02 four-way crossroads painted environment master. Create ONLY the BACKGROUND ENVIRONMENT LAYER as a candidate for compositing with a separate stone ground layer: preserve original architecture and distant environment at the exact same positions and camera as source — old Suzhou white plaster walls and gray tiled shop roofs, elegant north-side ceremonial archway, canal and stone bridge at upper left, orange maple and willows, tea stall left, notice board and wagon stall right, clothier and pawnshop storefronts; preserve all building proportions and lighting. The entire outdoor stone-paved playable road (horizontal strip from left to right in lower half and north-south center strip from archway to bottom edge) MUST BE REMOVED and replaced with truly transparent alpha 0, leaving the original building/landmark elements isolated against transparency. No opaque flat fill, no new roads, no shifts of perspective, no characters, no text, no guides or UI. Maintain pixel-registration to the reference so the separate ground and this scenery can be composited. Transparent background RGBA. Be especially careful to avoid colored fringe pixels on mask boundary.
```

## 输出审查提醒

AI 分离结果虽然提供真实 Alpha，**并不具备可接受的分层边缘质量**：两张 draft 的路缘有红、洋红和黄色伪影，背景与地面遮罩仍需修复和精确对位。生成模型中的“exact same coordinate”只是提示约束，不是像素级对齐证据。

## 4. 统一视角 v02 母版（用户参考图对比后）

- 输入参考图 1：第 1 步 PJ-02 v01 母版，**保留四向道路拓扑**
- 输入参考图 2：用户本轮上传的江南石街牌坊场景图，**只借鉴建筑立面、材质与色调，不能复制消失点通道和前景桥水**
- 透明输出：否
- 原始输出：1586×992 RGB PNG
- 仓库候选：`environment_pingjiang_crossroads_master_v02.webp`（整体重采样 1600×1000）

```text
Use case: stylized-concept. Generate a REVISED ORIGINAL game-environment master v02 for PJ-02 四街十字路, 16:10. Input image 1 is TOPOLOGY REFERENCE (our previously generated crossroads): keep its complete four-way connected walkable street layout and all four unblocked exits. Input image 2 is ARCHITECTURE/ATMOSPHERE REFERENCE ONLY (provided Jiangnan city street): take its more naturally proportioned facades, subtle handmade weathered stone, soft atmospheric haze and restrained autumn watercolor. Do not copy its vanishing-point road, foreground bridge or water barrier, and do not turn the actual crossroad into a distant photorealistic alley. Camera standard: fixed near-orthographic 2.5D landscape videogame view, gentle elevated oblique angle BETWEEN the two examples, showing more shop facades and a little less roof than input 1 while keeping the same readable stone-slab ground plane. Crucial physical rule: a 200-pixel-tall player sprite remains the SAME scale at any y coordinate, so the true north-south playable lane must remain approximately 320 pixels wide near both top and bottom; do not converge to a point. Horizontal east-west road remains around y=620..940, clear from LEFT EDGE to RIGHT EDGE. North-south walkway centered x=640..960, clear from TOP EDGE to BOTTOM EDGE; full actual four-way intersection unobstructed, no bridge/water/moat crossing the road. Frame outer edges with whitewashed Jiangnan walls, charcoal tile roofs, old timber storefronts, a carved stone arch over but not blocking the north lane, clothier door on left and pawnshop on right, quiet storyteller tea canopy, wood notice board and one small itinerant cart away from road. Blue gray muted green cool tones, a few amber lanterns, late autumn, original refined 2D painterly wuxia, ink wash, no 3D render, no miniature diorama feeling, no excessive geometric rooftop perspective. No people, no duplicate trees filling road, no text, no signage words, no UI, grid, axis, watermark. Canvas depicts one game world scene, not a cinematic cutscene.
```

早前尝试对 background draft 进行一次“清除红黄边缘污染”编辑，但结果仍有明显杂色，所以未保留为可交付文件。v02 是新的完整场景母版，尚无与其对应的独立图层。
