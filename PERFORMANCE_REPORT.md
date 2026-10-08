# Performance report: ECHOES BENEATH

Machine: NVIDIA RTX 2060 (driver 617.42), Windows 11, Godot 4.7.2.
Renderer: **GL Compatibility / OpenGL 3.3**, 1280x720 window. Measured with vsync off and FPS uncapped (`--uncapped`). Each level was loaded directly and the camera stayed static at the spawn point for 4 s. These are scene-load measurements, not gameplay.
Tool: `scripts/qa_reality_audit.gd --skip-menus --skip-play --uncapped --preset=N --levels=...`. Raw JSON is in `screenshots/reality_audit/perf_preset*/audit_results.json`.

## Preset definitions (systems/GraphicsSettings.gd)
| | Ultra Low | Low (default) | Medium | High | Ultra |
|---|---|---|---|---|---|
| Render scale | 50% | 67% (FSR1 on F+) | 77% (FSR1 on F+) | 100% | 100% |
| Shadows / atlas / distance | off | 2048 / 35 m | 2048 / 60 m | 4096 / 100 m | 8192 / 160 m |
| SSAO / SSIL / SSR / Vol. fog* | off | off | SSAO | SSAO, SSR, fog | all |
| Glow | off | off | on | on | on |
| LOD bias | 0.35 | 0.6 | 1.0 | 1.5 | 2.0 |
| AA | none | FXAA (F+) | FXAA (F+) | MSAA 2x | MSAA 4x + TAA |
| Vegetation density | 25% | 50% | 75% | 100% | 100% |
| Water quality | low | low | medium | high | high |
| FPS cap | 60 | 60 | none | none | none |

\*Screen-space effects and volumetric fog only work on Forward+. On Compatibility, which is the shipping default, they are forced off and the settings UI says so. The Prologue uses mist cards instead of volumetric fog. Systems receive the legacy tier through `set_graphics_quality(tier)` (Ultra Low/Low → 0, which hides the mist cards), and they can also read `GraphicsSettings.settings`, `vegetation_density` and `water_quality`, or listen to `quality_changed`.

## Results: average FPS, uncapped
| Level | Ultra Low FPS | worst frame | Low FPS | worst frame | VRAM (Low) | Static RAM (Low) | Draw calls (Low) |
|---|---|---|---|---|---|---|---|
| Prologue | 1240 | 10.9 ms | 702 | 4.7 ms | 401 MB | 105 MB | 426 |
| Chapter 1 | 623 | 5.1 ms | 496 | 7.7 ms | 605 MB | 133 MB | 459 |
| Chapter 2 | 771 | 4.2 ms | 1559 † | 2.1 ms | 497 MB | 102 MB | 35 |
| Chapter 3 | 1564 | 2.9 ms | 1640 | 1.8 ms | 461 MB | 102 MB | 26 |
| Chapter 4 | 1627 | 1.6 ms | 1603 | 1.3 ms | 448 MB | 102 MB | 29 |
| Chapter 5 | 1277 | 2.8 ms | 1384 | 8.0 ms | 513 MB | 106 MB | 34 |
| Chapter 6 | 1569 | 2.1 ms | 1563 | 2.1 ms | 513 MB | 109 MB | 31 |
| Chapter 7 | 1572 | 2.0 ms | 1565 | 2.4 ms | 510 MB | 103 MB | 34 |
| Chapter 8 | 1463 | 2.2 ms | 1434 | 2.9 ms | 522 MB | 103 MB | 28 |
| Chapter 9 | 1592 | 2.0 ms | 1576 | 2.2 ms | 510 MB | 103 MB | 30 |
| Chapter 10 | 1461 | 2.5 ms | 1526 | 2.9 ms | 510 MB | 103 MB | 30 |
| Finale | 1831 | 8.6 ms | n/a ‡ | | | | |
| Epilogue | 2252 | 4.1 ms | 2555 | 1.0 ms | 345 MB | 101 MB | 2 |
| Medium / High / Ultra | **not tested: hardware limitation** (the user's GPU crashes at high graphics settings) | | | | | | |

† Chapter 2 at Low was measured during a run in which Prologue.gd failed to compile because another agent was editing it. The Chapter 2 number may not match Ultra Low for that reason.
‡ The Finale did not load at Low because `LevelCave.gd` has a parse error, so the run measured the previous scene. This is not a valid result.

## Observations
- The only heavy scenes are the Prologue (about 0.9 M primitives, 426 draw calls) and Chapter 1 (3.2 M primitives, 459 draw calls). Chapters 2–10 are cheap because they contain very little content (see the audit).
- In normal play the frame rate is capped at 60 at Ultra Low and Low. Playthrough runs held 60.0–60.6 FPS with worst frames of about 17 ms.
- The Ultra Low vs Low difference is largest in the Prologue (1240 vs 702 FPS), which comes from the shadows and vegetation density settings.
- Process static RAM is 101–133 MB. VRAM is 330–615 MB, with the peak in Chapter 1.
- Before the hardware rule, on 2026-10-07, the old preset system was tested on Forward+ at 60 FPS capped: Chapter 1 at about 1.35 GB VRAM on D3D12 and 1.19 GB on Vulkan. That configuration is no longer used.
