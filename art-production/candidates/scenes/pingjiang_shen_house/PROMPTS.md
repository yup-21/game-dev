# PJ-04 沈家旧宅：实际生成提示词

生成工具：内置 imagegen。第一次为全新原创场景；第二次以第一次生成图为编辑目标。两次均为不透明背景；模型未提供 seed。本文件保留本轮实际英文提示词，便于后续针对性重绘。

## 1. 庭院母版 v01

- 生成目标：`environment_pingjiang_shen_house_master_v01.webp`。
- 输入：无附带图片；根据仓库已查看的 PJ-02 v02、PJ-03 中段风格进行文字约束。

```text
Use case: stylized-concept. A NEW original 16:10 horizontal game environment master for 《长风浮生录》, PJ-04 沈家旧宅, a modest aging Jiangnan wuxia family's private courtyard in late autumn. Match the established Pingjiang town visual identity: refined hand-painted Chinese watercolor/ink digital art, pale weathered plaster walls, dark curved tiles, warm wood joinery, blue-gray flagstones, sparse golden and crimson leaves, jade bamboo and soft misty daylight, amber lantern glow. CAMERA LOCK: fixed gently elevated oblique 2.5D near-orthographic action RPG viewpoint, readable human-scale facades with modest visible rooftops, no dramatic converging vanishing point, same architecture and paving scale across depth. Design a coherent playable single-screen house yard: a wide open, largely uncluttered flagstone training courtyard across the lower middle y≈550–900, about 300–400px usable depth, clear horizontal walkable axis; a distinct stone north approach lane enters through a humble opening in the back wall at the TOP CENTER x≈800 and descends, uniformly wide, to meet the courtyard, without tapering. At upper LEFT, show the Shen family's lived-in but slightly neglected old one-story hall with accessible timber entrance and modest steps; near its sheltered porch a low sword-case table with one CLOSED sheathed sword box. At upper RIGHT place 2–3 weathered wooden practice posts and a simple weapon rack; along a quiet side wall a covered old stone niche hints at a secret compartment. A small stone well and fallen leaves tucked away off the main walking lane. The house should feel intimate, worn but cared for, not a grand palace or ruined temple. A person if later composited would be 200 world pixels tall and door roughly 280px tall; DO NOT draw characters. Landscape one contiguous original map canvas, no inset panels, map framing, arrows, labels, words, UI, grid or watermark. Do not block the top center north exit with roof, wall, furniture or tree. No perspective shrinkage of the walking surface, no birds-eye city view, no 3D render or isometric toy look.
```

## 2. 北门与铺石透视修订 v02

- 生成目标：`environment_pingjiang_shen_house_master_v02.webp`；编辑目标：本轮 v01 原始 PNG。
- 修订理由：v01 北院门及门外巷道向远处收窄过快，对固定 200 世界 px 角色不友好。

```text
Use case: precise-object-edit. Edit the attached PJ-04 Shen family courtyard image as the target. Correct ONLY the upper-center NORTH EXIT spatial geometry. The rear wall gateway must have an actual wide 280-300 pixel clear opening appropriate to a 200-world-pixel player, and the cobbled access lane descending from it toward the central courtyard must remain a broadly SAME-WIDTH near-orthographic strip (approximately 300 pixels wide) rather than narrowing sharply into a vanishing point; make stone paving continuous, level and believable. The gate connects to the adjacent Pingjiang market lane at TOP CENTER x≈800. Keep everything else precisely recognizable and at original positions: left old house, entrance porch, low closed sword chest, right three training dummies, spear rack, secret niche, well, bamboo, foliage, brush technique, lighting, atmosphere, full canvas, no people and no text. Maintain fixed gently elevated 2.5D oblique painted game camera and the uncluttered courtyard. Avoid adding new buildings, characters, labels, arrows or scale overlays. Keep the two-dimensional house facade and door scales consistent with the existing image.
```

## 3. 图像归一

原始生图 v01 为 1586×992 RGB PNG、v02 为 1585×992 RGB PNG。仅把各整幅图归一成项目世界画布并编码为 WebP，没有对门洞或人物单独拉伸；v02 是重新生成的编辑结果，不是数值透视修正。机械操作：

```bash
magick v01-original.png -resize 1600x1000! -quality 93 environment_pingjiang_shen_house_master_v01.webp
magick v02-original.png -resize 1600x1000! -quality 93 environment_pingjiang_shen_house_master_v02.webp
```

其中 `v01-original.png`、`v02-original.png` 是记录用占位文件名，并非仓库内实际提交的原始 PNG。未完成像素级几何校准与真实分层，详见 `QA.md`。
