# AAA Visual Baseline Audit (2026-10-11)

These findings come from rendered captures (Xvfb, Compatibility/OpenGL, LOW). The renderer is software-only here, so they say nothing about performance or Forward+.

## Mara (verified)
- **Model:** `CHR_Mara_Game_LOD0.glb`, one mesh, 39,844 vertices, PBR set (Color, NormalGL, ORM).
- **Rig:** 41 bones, Tripo-style naming (`Root`, `Hip`, `Pelvis`, twist bones, `L_Hand`/`R_Hand`). **No finger bones.**
- **Clips:** idle, walk, run, jump, fall, climb, dive, swim (8).
- **Missing clips:** strafe, slide, ledge hang/shimmy, aim/fire/reload, melee, push, and interactions.
- **Implication:** hand poses for gripping and weapons need either a finger rig (Blender re-skin of the hand region, then re-export with all 8 clips migrated) or baked fist and grip poses on the hand bone. Nothing has been changed yet.

## Environment priorities (from captures)
| # | Area | Problem | Status |
|---|---|---|---|
| 1 | Ch1 camp ground | Flat cartoon grass, brown-noise path | **Improved:** CC0 photo-scanned forest floor and rock layers (`docs/visual_benchmark/camp_before` vs `camp_after`, same camera) |
| 2 | Ch1 distant hills | Smooth green blobs, pale under fog | Open: needs terrain relief, scattered rocks and vegetation |
| 3 | Ch5→Ch6 aqueduct | Stretched tan cave models | **Improved:** Poly Haven rock_wall_08 PBR (previous commit) |
| 4 | Ch6 doorway | Plain box infill | Open |
| 5 | Tents and props | Saturated lime canvas, plastic look | Open: re-tint, roughness |
| 6 | Mara hands | No fingers | Open (see above) |
| 7 | Chapters 2–4, 7, 9, 10 and Finale | Blockout dressing only, no LevelB dressing script | Open: largest visual gap |

## Benchmark verdict
The Ch1 camp ground is a visible step forward. **The benchmark as a whole isn't passed:** hills, props, Mara and lighting remain at their previous level.
