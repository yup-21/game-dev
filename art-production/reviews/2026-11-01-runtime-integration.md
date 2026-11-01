# Pilot runtime integration (review branch only)

- Source batch: `art-production/candidates/2026-11-01/` (originals preserved).
- Runtime copies: `demos/changfeng-battle/assets/imported/candidates/2026-11-01/` (byte-for-byte copies).
- Native character bindings: `data/native/characters/shen_changfeng.tres`, `pursuer_captain.tres`, with individual nine-action `data/native/animations/*.tres`.
- Portrait registry bindings: `r22_shen_portrait.tres`, `r27_pursuer_study.tres` (otherwise existing registry resources would mask the new portraits).
- Layered map binding: `data/native/scene_art/rainy_bridge.tres` and `data/maps/rainy_bridge.tres`. The old 15×10 terrain, cell centers, collision and encounter roster are unchanged; background transform changed from the old rotated image to a native 1600×1000, 0°/1× canvas.
- The story scenery registry points to the same pilot's composited preview. The battle uses separate background/ground/foreground/weather layers, not a pre-flattened screenshot.
- `checks/test_art_runtime_integration.gd` checks actual battle nodes, portraits, atlas profiles and independent weather layer.

**Review state: `candidate / owner_review_required`, not `approved`.** These files are deliberately integrated on a review-only branch and should not be merged into `main` as final production art until the human review in `2026-11-01-pilot-review.md` is complete.

Known limitations: weapon tips and some movement in-betweens need repainting; only horizontal-facing frames are present; source illustration does not precisely match the old six-person positions and bridge terrain; static baked rain marks remain in the background. Godot CI tests technical wiring, not art direction, rights or perceptual occlusion.
