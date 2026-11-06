# PRO-00 · 荒山古道（候选美术）

**状态：待人工验收，不得覆盖正式资源。**

- 源母版：`雨中竹山古道与破车.png`；山道近正交俯视，左侧峭壁、远景江水、右侧断车。
- 1600×1000；北出口 (792,146) 通荒庙；南出口 (797,849) 通断桥。可走道路中央需要保持人物 170px 高时的相同尺度。
- 现有灰盒线索锚点 `CartTraces` 在 (822,667)，解读为车辙与刀痕而非车厢本体；右侧断车前景以右岸为主，需二次微调碰撞。
- 分层输出：`background.png`、`ground.png`、`foreground.png`；各 1600×1000 RGBA，合成像素与 `master.png` 一致。
- 构建工具：`art-production/tools/build_prologue_candidate_layers.py`，由候选艺术母版生成并校验。
- 编辑器预览：`res://scenes/prologue/prologue_road_art_review.tscn`。
- 必须验收：角色能从北端走到南端，左右崖壁与破车无法穿越，车辙线索可触发，画面上端道路不能显著缩短 170px 人物的视觉尺度。

无损 PNG 源文件仍由外部素材包交付；已提交的 WebP 能用于独立 QA，但不能将候选运行图误报为已批准的正式地图资源。

## 2026-11-06 GitHub 资产交付更新

PR #141 现已包含本场景的 `master.webp` 母版及 `background.webp`、`ground.webp`、`foreground.webp` 三层运行图，均为 **1600×1000、带透明通道的高质量 WebP**。原始无损 PNG 仍由独立素材 ZIP 保留；Godot 探索场景会优先选择完整的 PNG 三层，否则加载完整 WebP 三层。**图片已进入 PR，但人工角色遮挡／视觉透视／实机战斗验收仍未完成，状态依然是候选。**
