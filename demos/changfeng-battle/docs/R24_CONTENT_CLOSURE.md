# R24 — Native Resource content-only vertical slice

This milestone is authored without new JSON files. The content-only commit adds `.tres` records to `data/content_manifest.tres`, and uses the extensible R18–R23 systems unchanged:

- Recruit: 岚尘 (`r24_lan_chen`) enters the party through the native character factory, equipped with 青芦短剑 and 2 × 凝雾养气散.
- School: 烟岚剑派 has 6 × 敛雾 and 6 × 破岚 in its starting deck. 敛雾 generates a physical 追雾 card; 雾起 / 云开 advance as separate technique stages.
- Buffs: 露凝护体 increases constitution; 雾刃暗锋 conditionally increases attack only while 露凝护体 is active. This status-only condition refreshes on status add, removal and expiry. Other volatile predicates are rejected by the status catalog.
- Chapter: 雾隘同行 has two independent NPC conversation triggers. The first returns to exploration; both conversation flags enable battle.
- Quest: four objectives (meet scout, meet elder, obtain clue, win encounter). Story flags and encounter facts remain the source of truth.
- Map: `r24_fog_pass_map.tres` uses polygon vertices and continuous FREE collision. The compatibility GRID index is generated, never authored.
- Presentation: portrait, 24-pose sheet, actor scene and `STATUS_APPLIED` VFX bind by character ID or event type. Existing previews are marked `candidate`, **not licensed/approved production art**.

Automated acceptance: `godot --headless --path demos/changfeng-battle --editor --import --quit` then `--script res://checks/test_r24_content_closure.gd`, plus modular, HUD and export workflows. The R24 content commit itself should touch only `data/**/*.tres`.

**Manual follow-up before shipping:** open the Godot project, enable the Wuxia Map Painter dock, save and reload a polygon; interact with both NPCs in either order; finish the chapter, trigger free-space pathfinding in battle and check scene, portrait, 24 poses and VFX at target resolution. Record provenance and verify usage rights before promoting any `candidate` artwork to `approved`. The automated CI does not substitute for editor GUI and art-rights review.
