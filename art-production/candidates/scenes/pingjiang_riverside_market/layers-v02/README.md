# PJ-03 原图分层 v02

原图：上级 environment_pingjiang_riverside_market_master_v01.webp，4800×1000。

- background.webp：原图上方 580px，保持店铺、水岸原像素；其余透明。
- ground.webp：移除近景后的 clean_plate.webp，取 y=580..1000，其余透明。
- foreground.webp：imagegen 提取近景，移除模型输出留白后校准到 y=680..1000；保留 Alpha。
- composite.webp：按 background → ground → foreground 合成的审核预览。
- source_foreground.png：模型原始输出；clean_plate.webp 为模型补绘输出移除白色留边并归一至世界画布后的制作母版。

三层为同原点 4800×1000，导入副本位于 assets/imported/scenes/pingjiang_riverside_market/*_v02.webp。原 SVG 保留供回归。当前为独立 QA 入口使用版本，未修改主线章节绑定；视觉审核待完成。

早期示意 SVG 的源稿保存在 `../legacy-vector/`；旧 `assets/imported/` 版本暂保留供回归比较。向量生成器只更新候选源稿，不再覆盖已绑定的 WebP 图层。

**PR #123–#128 集成修复**：上传的 `background.webp`、`clean_plate.webp`、`composite.webp` 曾被截断到约 768 KiB，无法完整解码。`build_pj03_raster_layers.sh` 现从有效原始母图的前 580px 重建透明背景，并使用完好的 `ground.webp` 及 `foreground.webp` 合成新的 `clean_plate.webp` 和预览；同步修复 QA 用背景镜像。保留前景及地面的原始像素/Alpha，不再从损坏的 `clean_plate.webp` 重新裁切。重建后的预览不是历史 AI clean plate 的逐像素复原，须重新进行画面及接缝验收。

## 实际生成提示词（内置 imagegen）

Foreground: Extract ONLY the near foreground houses, roofs, and autumn trees along the BOTTOM EDGE of the supplied riverside street panorama. Keep their original precise silhouettes, handpainted textures, positions and full panoramic framing (4800x1000 reference coordinates). Everything else including sky, shops in upper half, river, and all street paving must be fully transparent alpha. Do not recenter or enlarge isolated objects. Preserve empty gaps between bottom foreground buildings, preserve bottom-edge clipping. Output a full-width panorama foreground layer, no text.

Clean plate: Create a clean background plate of this EXACT panorama for a layered 2D game. Preserve full panorama framing, all upper storefronts, canals, boats, trees and original painterly brush textures and colors in their exact places. Remove ONLY all near foreground houses/roofs/trees intruding upward from the bottom edge, replacing their pixels with seamlessly continued blue gray street paving. The broad horizontal road should continue cleanly to bottom edge. Preserve top half unchanged and the left/middle/right scene order, no added buildings, no people, text, labels or UI. Reference world frame 4800x1000.

## 验证

Godot 4.6.3 headless test_pingjiang_riverside_market.gd PASS：尺寸、原生加载、连续主路、近景建筑禁入、南向通道、出口和 QA 场景实例化。

主路脚点限制 y=612..780，南巷 x=2260..2540 延伸至925；24px 占位。前景固定绘制在角色上方。规划跨区目标仍未全部接入。

未执行 GUI 双分辨率实机验收。生成后的前景边缘、背景/地面 y=580 接线以及原三段接缝仍需视觉验收；不宣称逐像素还原或无缝。
