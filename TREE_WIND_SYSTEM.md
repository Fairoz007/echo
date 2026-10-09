# Tree wind system

## Overview

| Part | File |
|---|---|
| Global wind, presets, blending, signal, player tracking, quality | `systems/nature/WindSystem.gd` |
| Shared shader uniforms and functions (gust front, turbulence noise, `wind_scalar`, `wind_player_push`) | `shaders/wind_common.gdshaderinc` |
| Trees, bushes, ferns and vines | `shaders/foliage_wind.gdshader` |
| Grass (base and Level B) | `shaders/grass_wind.gdshader`, `systems/levelb/grass_lb.gdshader` |
| Converts imported plants to the wind shader | `systems/FoliageWind.gd`, `systems/levelb/LBFoliageWind.gd` |
| Falling leaves | `systems/nature/FallingLeaves.gd` |
| Grass scattering | `systems/nature/GrassScatter.gd` (now also scaled by `foliage_density`) |
| Test bed and capture | `dev/nature/NatureTest.tscn`, `dev/nature/nature_capture.gd`, `dev/nature/nature_sheet.py` |
| QA | `scripts/qa_foliage_wind.gd` (headless; prints `FOLIAGE_WIND_PASS`) |

## Presets

`WindSystem.set_preset(WindSystem.Preset.X, blend_seconds := 3.0, dir := Vector2.ZERO)` blends every value over `blend_seconds` with smoothstep easing. `dir` of zero keeps the current direction; otherwise the direction is slerped. `set_wind()` still works and sets values instantly.

| Preset | strength | gust | gust freq | turbulence | storm_intensity |
|---|---|---|---|---|---|
| CALM | 0.25 | 0.25 | 0.12 | 0.05 | 0 |
| BREEZE | 0.7 | 0.5 | 0.22 | 0.2 | 0 |
| MODERATE | 1.1 | 0.6 | 0.3 | 0.35 | 0 |
| STRONG | 1.7 | 0.75 | 0.42 | 0.6 | 0.15 |
| STORM | 2.4 | 0.9 | 0.6 | 1.0 | 1.0 |
| CAVE | 0.12 | 0.35 | 0.08 | 0.05 | 0 |

**Signal for audio and rain:** `WindSystem.driver().wind_changed(strength, direction, turbulence, storm_intensity)`. It fires at most every 0.1 s, and only when a value changes. `WindSystem.driver()` creates the driver synchronously, so it is safe to connect from `_ready`.

**Uniforms pushed to every registered material:**

- `wind_direction`, `wind_strength`, `gust_amount`, `gust_frequency`, `wind_time`
- `wind_phase`: an integrated sway phase, so sway gets faster with strength without jumping
- `turbulence`, `storm_intensity`
- `wind_detail`
- `player_position`, `player_trail`, `player_velocity`

## Tree deformation (`foliage_wind.gdshader`)

- **Rooting.** Height weight is `hn² · smoothstep(0, root_lock, hn)`. The lowest 8% of a tree's height (`root_lock`) does not move at all, so roots never detach. Collision shapes are untouched, because only `MeshInstance3D` materials are swapped.
- **Primary sway.** Lean plus slow oscillation, with a slightly elliptical path. Amplitude is in metres and proportional to plant height.
- **Branch bend.** Scales with flexibility × height. Flexibility is vertex colour R when `use_vertex_color_mask` is set; otherwise it is a radial mask (distance from the trunk axis, `plant_origin` = AABB centre). The trunk core gets zero branch motion. Branches have a phase lag relative to the trunk.
- **Twig and leaf flutter.** Fast flutter (7–11 rad/s, faster in storms) along the normal, with a per-vertex hash phase. Amplitude is flex², so it is strongest on the outer canopy.
- **Desync.** Each plant's phase and flutter speed come from a hash of its world position, so neighbouring trees don't move in step (verified on the 8-tree forest row).
- **Normals.** Corrected analytically for the primary bend (`n -= (0, f'·(dir·n), 0)`). Flutter adds a small shimmer tilt.
- **Storm safety.** Wind magnitude is clamped to 3.5, and the total horizontal offset is clamped to 16% of plant height plus 0.25 m. A length-preservation drop keeps bent tips from stretching.

## Quality

| Level | `foliage_wind_detail` default | Behaviour |
|---|---|---|
| ULTRA LOW | 0 | Primary sway only. No branch/flutter, no player interaction, no falling leaves. |
| LOW | 1 | Full detail |
| MEDIUM/HIGH/ULTRA | 2 | Full detail plus spatial turbulence noise |

- **Settings keys:** the levels read `GraphicsSettings.settings.get("foliage_wind_detail", DETAIL_BY_LEVEL[level])` and `settings.get("foliage_density", 1.0)`. Both default safely if the optimization agent hasn't added the keys yet.
- **Live updates:** `quality_changed` is connected by the WindSystem driver, so changes apply live through uniforms.
- **Behaviour change:** FoliageWind used to restore the original static materials on legacy tier 0, which included LOW. Now every level animates and the detail is decided by the shader. `FoliageWind.set_graphics_quality()` ignores the legacy tier.
