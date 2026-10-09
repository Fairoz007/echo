# Performance report: ECHOES BENEATH

## 2026-10-09: all-preset optimization pass (graphics agent)

Machine: RTX 2060, Godot 4.7.2, **GL Compatibility / OpenGL 3.3**, 1280x720. No Forward+ runs.
Tool: `dev/perf/preset_sweep.gd`, run one preset per process by `dev/perf/run_sweep.sh <tag> [presets]` under the shared lock. Logs are in `dev/perf/logs/{before,after}_q*.log` and screenshots in `screenshots/perf/q<N>_<Level>.png`.
Method: load each level and add it, then use two windows. The **spike window** is the first 6 s after `add_child` and gives the max frame and the count of frames over 100 ms. The **steady window** is the next 6 s at spawn and gives the average and the 1% low. FPS is capped at 240 with vsync off, so 4.17 ms is the cap. Each level also runs a live `quality_changed` round-trip (preset to (preset+2)%5 and back). `live=true` on all 30 runs.

### Load spikes: Ch7 / Ch9 (`dev/perf/spike_trace.gd --profile-build`)

| Source | Before | After | Fix |
|---|---|---|---|
| `EnvironmentCollision` pass (spawned by `CampaignEnvironmentArt`) | **606 ms in one frame** (Ch7) | ≤61 ms per frame, 124–217 ms total spread over about 5 frames | Frame-budgeted `build_async()` (6 ms/frame). Per-mesh shape cache. Convex hulls use `simplify=false`, which turned one 196 ms hull into 17 ms. Sync `build()` is kept for QA. |
| CaveBuilder shell stage | 154 ms main thread | 25 ms main thread (300 ms of work on a `WorkerThreadPool` thread) | `_shell_arrays()` runs on a worker. The concave faces are built on the worker, so there's no `get_faces()` GL readback. |
| CaveBuilder ground stage | 159–183 ms main thread | Worker thread, spread over about 20 frames | Same as the shell. |
| CampaignEnvironmentArt ground GLB / Ch1-style foliage | Sync `load()` + instantiate in `_ready` | Threaded `ResourceLoader` request; foliage placed under a 4 ms/frame budget | Falls back to a blocking get if `set_graphics_quality()` is called first, which keeps `qa_ground_instances.gd` valid. |

**Ch7 worst frame: 628 → about 285 ms. Ch9: 375–458 → about 255–290 ms.** What's left is frames 1–2 after the first draw (about 190 + 310 ms). Those frames have no script work in them; the profile shows that. They are GL shader/pipeline compilation on first use and appear on every level, Finale included (243–313 ms). The next step would be a shader warm-up during the loading fade, in the scene-flow/UI code, which this agent doesn't own. `BlockoutDresser.materials()` (about 210 ms) still runs inside the load frame (`add_child`), not during gameplay.

### Per-preset before → after

The "before" numbers were taken while other agents had mid-edit parse errors (6.6k HUD errors per frame on the q1 run), which inflated q1 frame times and Ch1. The Ch1 spike drop from 9 s to about 0.6–1.1 s comes mostly from parallel Level B/nature work, not from this pass. The Ch7/Ch9 numbers are attributable to this pass; see the trace above.

| Preset | Level | Max spike ms | Frames >100 ms | Avg ms | 1% low ms | Draw calls | Static mem MB | VRAM MB |
|---|---|---|---|---|---|---|---|---|
| 0 Ultra Low | Prologue | 1461 → **548** | 5 → 4 | 4.17 → 4.17 | 5.21 → 5.02 | 218 → 218 | 111 → 94 | 523 → 523 |
| 0 Ultra Low | Chapter1 | 10189 → **562** | 3 → 2 | 4.20 → 4.17 | 6.27 → 5.03 | 331 → 304 | 162 → 122 | 907 → 907 |
| 0 Ultra Low | Chapter6 | 2101 → **267** | 3 → 1 | 4.17 → 4.17 | 5.50 → 4.95 | 162 → 204 | 170 → 123 | 1042 → 1042 |
| 0 Ultra Low | Chapter7 | 628 → **286** | 4 → 2 | 4.21 → 4.17 | 6.79 → 5.18 | 223 → 264 | 169 → 126 | 1335 → 1335 |
| 0 Ultra Low | Chapter9 | 427 → **267** | 4 → 1 | 4.17 → 4.17 | 5.79 → 5.18 | 85 → 286 | 168 → 125 | 1260 → 1260 |
| 0 Ultra Low | Finale | 252 → **313** | 3 → 1 | 4.17 → 4.17 | 5.69 → 4.78 | 58 → 217 | 160 → 121 | 1204 → 1204 |
| 1 Low | Prologue | 1911 → **542** | 7 → 4 | 7.65 → 4.17 | 10.78 → 4.92 | 211 → 413 | 110 → 95 | 411 → 538 |
| 1 Low | Chapter1 | 9240 → **648** | 3 → 1 | 8.74 → 4.17 | 29.37 → 4.83 | 517 → 557 | 162 → 125 | 870 → 905 |
| 1 Low | Chapter6 | 1937 → **263** | 2 → 1 | 7.83 → 4.17 | 9.76 → 4.92 | 76 → 459 | 169 → 124 | 1007 → 1041 |
| 1 Low | Chapter7 | 612 → **299** | 4 → 2 | 8.54 → 4.17 | 11.50 → 4.88 | 291 → 264 | 169 → 127 | 1290 → 1334 |
| 1 Low | Chapter9 | 414 → **279** | 4 → 1 | 8.32 → 4.17 | 11.44 → 4.85 | 295 → 286 | 167 → 126 | 1213 → 1258 |
| 1 Low | Finale | 323 → **277** | 4 → 1 | 8.44 → 4.17 | 10.82 → 4.77 | 228 → 217 | 159 → 122 | 1157 → 1201 |
| 2 Medium | Prologue | 1279 → **515** | 5 → 4 | 4.17 → 4.17 | 4.95 → 4.87 | 465 → 418 | 112 → 95 | 529 → 544 |
| 2 Medium | Chapter1 | 9159 → **742** | 2 → 1 | 4.34 → 4.17 | 22.32 → 4.75 | 732 → 732 | 166 → 128 | 915 → 911 |
| 2 Medium | Chapter6 | 1925 → **244** | 2 → 1 | 4.17 → 4.17 | 4.90 → 4.91 | 602 → 602 | 171 → 124 | 1047 → 1043 |
| 2 Medium | Chapter7 | 609 → **284** | 5 → 1 | 4.17 → 4.17 | 4.93 → 4.83 | 264 → 264 | 170 → 127 | 1341 → 1337 |
| 2 Medium | Chapter9 | 458 → **271** | 4 → 1 | 4.17 → 4.17 | 4.84 → 4.90 | 286 → 286 | 169 → 126 | 1267 → 1263 |
| 2 Medium | Finale | 223 → **250** | 3 → 1 | 4.17 → 4.17 | 4.84 → 4.82 | 217 → 217 | 161 → 122 | 1207 → 1202 |
| 3 High | Prologue | 1280 → **514** | 5 → 4 | 4.17 → 4.17 | 4.95 → 4.81 | 546 → 418 | 112 → 95 | 543 → 557 |
| 3 High | Chapter1 | 9199 → **1117** | 3 → 2 | 5.35 → 5.17 | 19.39 → 6.16 | 844 → 844 | 168 → 130 | 929 → 925 |
| 3 High | Chapter6 | 2203 → **369** | 2 → 1 | 4.17 → 4.17 | 5.13 → 4.86 | 682 → 682 | 171 → 124 | 1060 → 1056 |
| 3 High | Chapter7 | 604 → **298** | 5 → 1 | 4.17 → 4.17 | 4.99 → 4.90 | 264 → 264 | 171 → 127 | 1359 → 1355 |
| 3 High | Chapter9 | 380 → **255** | 4 → 1 | 4.17 → 4.17 | 5.10 → 4.79 | 286 → 286 | 169 → 126 | 1280 → 1276 |
| 3 High | Finale | 386 → **252** | 4 → 1 | 4.17 → 4.17 | 4.83 → 4.75 | 217 → 217 | 161 → 122 | 1216 → 1212 |
| 4 Ultra | Prologue | 1273 → **602** | 5 → 5 | 4.17 → 4.17 | 5.07 → 6.32 | 414 → 405 | 112 → 95 | 557 → 547 |
| 4 Ultra | Chapter1 | 9087 → **927** | 2 → 1 | 6.95 → 6.75 | 43.28 → 8.53 | 844 → 844 | 168 → 131 | 943 → 945 |
| 4 Ultra | Chapter6 | 1907 → **258** | 2 → 1 | 4.17 → 4.17 | 5.20 → 5.08 | 682 → 682 | 171 → 124 | 1074 → 1076 |
| 4 Ultra | Chapter7 | 601 → **285** | 4 → 2 | 4.17 → 4.17 | 4.90 → 5.05 | 264 → 264 | 170 → 128 | 1373 → 1375 |
| 4 Ultra | Chapter9 | 375 → **289** | 4 → 1 | 4.17 → 4.17 | 4.85 → 5.54 | 286 → 286 | 169 → 126 | 1294 → 1296 |
| 4 Ultra | Finale | 205 → **243** | 2 → 1 | 4.17 → 4.17 | 4.82 → 4.79 | 217 → 217 | 161 → 123 | 1230 → 1233 |

Errors in the "after" logs: 0 SCRIPT ERROR / ERROR on q0–q4. q4 timed out once with no output after Prologue loaded (`dev/perf/logs/after_q4_hung.log`). The rerun was clean, so q4 should be watched. The Ch6 spawn screenshot shows the camera inside reeds on every preset (q0 to q4 identical). That is not caused by a preset; it belongs to the Ch6/camera owner.

### New GraphicsSettings keys (`GraphicsSettings.get_setting(key, default)`)

| Key | 0 Ultra Low | 1 Low | 2 Medium | 3 High | 4 Ultra |
|---|---|---|---|---|---|
| foliage_density | 0.35 | 0.6 | 0.8 | 1.0 | 1.0 |
| foliage_wind_detail (0 primary, 1 +leaf flutter, 2 +secondary branch) | 0 | 1 | 1 | 2 | 2 |
| leaf_particles | 0 | 0 | 1 | 1 | 1 |
| vegetation_interaction | 0 | 1 | 1 | 1 | 1 |
| character_ik_quality | 0 | 0 | 1 | 2 | 2 |

`foliage_density` now drives the scene-wide jungle tree/fern thinning; `vegetation_density` still drives grass. `_ready` push_errors if any TABLE row isn't 5 entries long. `apply_quality()` emits `quality_changed(level, settings)` live, and nodes with `set_quality_settings(settings)` receive the full dictionary.

---

## Earlier measurements


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
