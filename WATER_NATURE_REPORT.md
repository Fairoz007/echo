# Water / Water VFX / Nature-Wind Report

Engine: Godot 4.7.2 (Steam build, `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`), **Compatibility renderer** (the project setting), RTX 2060, 1280x720.
Test bed: `dev/WaterTest.tscn` (dev only). Automated run:

```
godot --path D:/new-dev res://dev/WaterTest.tscn -- --capture
```

This writes `screenshots/water/*.png` and `screenshots/water/results.txt`. Interactive keys: 1-8 switch cameras, L toggles low/high water, R raises the pool, F drains it, C drops a crate, W changes wind strength.

## Status: tested vs only implemented

| Feature | Status |
|---|---|
| Water shader, high quality (2 scrolling normal layers, Fresnel, depth absorption (Beer-Lambert), screen refraction with a fallback for objects in front of the water, roughness variation, specular, shoreline foam from depth, crest foam, sine-sum vertex waves) | **Visually verified** (`pool_close`, `markers_side`, `river`, `waterfall_close`). You can see the floor through the water, crate shadows on the pool floor, and refraction at the waterline. |
| Low-quality variant (no screen or depth textures, 1 normal layer, 2 waves, fewer subdivisions), switchable at runtime | **Visually verified** (`pool_close_LOW`, `waterfall_LOW`). The GPU cost difference is small in this scene (see Perf). |
| 6 presets as resources | **Implemented and generated:** `systems/water/presets/*.tres`. Visually checked: RISING_PUZZLE_WATER, WATERFALL_BASIN, RIVER, UNDERGROUND_STREAM (waterfall source channel). CALM_CAVE_POOL and FLOODED_TEMPLE were not looked at on screen. |
| `get_surface_height` matches the rendered waves | **Visually verified:** 7 orange marker spheres are placed every frame at `get_surface_height()`. In `markers_side.png` they ride exactly on the surface. GDScript and the shader use the same formula and share a `water_time` uniform that the WaterBody drives. |
| `is_point_underwater`, `get_flow_velocity` | **Tested:** results.txt, `contract` line. |
| Buoyancy (8 probe points, drag, angular drag, flow push) | **Tested:** 4 crates settle with a draft of 0.19-0.32 m against a theoretical ~0.25 m and keep bobbing slightly (velocity < 0.4 m/s). A crate in the 1.8 m/s river drifted about 3.9 m in about 4 s. When the pool drains the crates sink with the water, and when it refills they pop back up. |
| Splash on entry/exit and ripples | **Visually verified** (`splash.png`). The splash mist is still a bit heavy and blob-like. Ripples are implemented, but no screenshot isolates them. |
| `set_level` rise/drain, signals, moving volume, audio pitch/volume hook | **Tested:** results show `rise_started`, `drain_started` and `level_target_reached` each firing exactly once, and `level_changed` firing every physics tick. The audio hook is implemented but was not listened to. |
| Wetness after draining | **Tested by pixel diff** (`pool_drained_wet` vs `pool_drained_wet_OFF`, plus `wet_diff.png`): the pit walls get about 35% darker below the old water line, with a dry band above it and drip streaks. Drying over time (`wet_dry_time`, 25 s) is implemented but was not captured over time. |
| Waterfall (lip, ballistic sheet, impact foam, mist, wet rock, audio, source channel, downstream river) | **Visually verified** (`waterfall_close`, `waterfall`, `river`). |
| Wind (global values, gusts, tiered foliage) | **Visually verified in still frames** (`grass_trees` vs `grass_trees_strong_wind`). The motion over time was not recorded. Tree trunk stiffness versus branch sway was checked only by reading the shader, not visually. |
| Grass MultiMesh (4 variations, per-instance phase and tint, chunked, distance culling) and scatter rejection | **Tested:** results show `slope 147, underwater 294, overlap 36, dynamic 12` rejections out of 6000 candidates. A bug where grass was planted on falling crates was found and fixed: dynamic bodies are now rejected. |
| Legacy `scripts/qa_water_presentation.gd` and `qa_foliage_wind.gd` | **Pass** after my changes. |

### Honest quality notes
- The water looks good for the Compatibility renderer, but it is not AAA. There are no planar or SSR reflections, only the sky/environment specular, and no caustics. Shoreline foam is soft noise, not detailed bubbles.
- Waves are a vertical sine sum, not true Gerstner. I chose this deliberately so that GDScript can return the exact height cheaply. Horizontal Gerstner displacement would make the height query need an iterative solve.
- In low quality, overlapping transparent bodies show a seam where the basin and downstream meet (`waterfall_LOW.png`). High quality hides it with depth fade.
- WaterBody ignores rotation: its volume is axis-aligned and translation only. Use `size` for rectangles.
- The test bed uses placeholder art: box crates, sphere rocks, and a box cliff with a procedural wet-rock shader.

## Perf (RTX 2060, 1280x720, Compatibility, vsync off; GPU time from RenderingServer measurement)

| View | render GPU ms |
|---|---|
| Overview (pool, waterfall, river, about 5.5k grass clumps, trees) | 1.7-1.9 |
| Pool close, high quality | 1.5 |
| Pool close, low quality | 1.4 |
| Grass and trees, strong wind | 1.7 |

The high shader costs one extra screen copy and depth read, which matters more on low-end iGPUs than on this card. Grass uses 100 chunked MultiMeshes (8 m cells), `visibility_range_end = 45` and no shadows. The `vegetation_density` setting (new GraphicsSettings) or the Low preset scales the scatter count. Water mesh density is 96 subdivisions at High, 48 at Balanced and 24 at Low.

## Files (all mine)
- `shaders/water_waves.gdshaderinc`: shared wave function. It **must match** `WaterBody.wave_height`.
- `shaders/water_surface.gdshader` (high) and `shaders/water_surface_low.gdshader` (low)
- `shaders/waterfall_sheet.gdshader`, `impact_foam.gdshader`, `wet_rock.gdshader`, `wet_overlay.gdshader`, `water_ripple.gdshader`
- `shaders/wind_common.gdshaderinc`, `foliage_wind.gdshader` (rewritten, tiered, still backward compatible), `grass_wind.gdshader`
- `systems/water/WaterPreset.gd` and `presets/*.tres`, `WaterBody.gd/.tscn`, `Buoyancy.gd`, `BuoyantCrate.tscn`, `Waterfall.gd/.tscn`
- `systems/nature/WindSystem.gd`, `GrassScatter.gd/.tscn`
- `vfx/Splash.gd/.tscn`
- `systems/WaterPresentation.gd`: same API as before, now renders with the new shader (FLOODED_TEMPLE) and adds `get_surface_height`.
- `systems/FoliageWind.gd`: same API, plus an optional `profile` argument ("tree", "fern", "rock"), and it registers with WindSystem.
- `dev/WaterTest.gd/.tscn`, `dev/generate_water_presets.gd`
- `shaders/basin_water.gdshader` is now **unused**. It can be deleted once nothing references it.

## INTEGRATION (for the level agent and the player agent)

### Water volume (swimming and puzzles)
1. Instance `res://systems/water/WaterBody.tscn` and set:
   - `preset_name` (or drag a `presets/*.tres` into `preset`)
   - `size` (XZ, metres)
   - `depth`
   - `surface_level` (local Y of the surface; the node origin is the reference)
   - Do **not** rotate or scale it.
2. It joins group `water_volume` automatically. Contract for Player.gd:
   ```gdscript
   for w in get_tree().get_nodes_in_group("water_volume"):
       if w.is_point_underwater(chest_pos):
           var surface_y: float = w.get_surface_height(global_position)
           velocity += w.get_flow_velocity(global_position) * delta * k
           var rise: float = w.get_level_velocity()  # m/s while rising/draining
   ```
   It also emits `body_entered_water(body, impact_speed)` and `body_exited_water(body)`. It spawns entry and exit splashes for any CharacterBody3D or RigidBody3D, but skips bodies that have a Buoyancy component, because Buoyancy spawns its own.
3. Legacy `systems/WaterVolume.gd`, used by Chapter6 and not owned by me, still reads `surface.global_position.y + 0.4`. Chapter 6 can move to WaterBody (`preset_name = "FLOODED_TEMPLE"`) and use `set_level()` instead of tweening the parent. Until then WaterPresentation keeps working unchanged.
4. Rising/draining puzzle: call `water.set_level(target_local_y, seconds)`. Connect `level_target_reached` to the puzzle logic. To make the audio respond, add an `AudioStreamPlayer3D` child and set `flow_audio` to it.
5. Wet walls after draining: add the wall/floor MeshInstance3D nodes, or their parents, to group **`wettable`**. The WaterBody applies a darkening `material_overlay` inside its footprint (plus a 0.3 m margin) and removes it after `wet_dry_time`.
6. Quality: GraphicsSettings already calls `set_graphics_quality(tier)` on every node that has that method. Tier 0 switches to the low shader. `quality_override` forces High or Low per body.

### Floating props
Add `res://systems/water/Buoyancy.gd` as a child node of any RigidBody3D, or instance `BuoyantCrate.tscn`. Tune it with `buoyancy_scale`, and with `volume` (when ≤ 0 it is estimated from the collision AABB). Mass versus volume decides how high it floats: water density is 1000 kg/m³.

### Waterfall
Instance `res://systems/water/Waterfall.tscn` at the **foot of the cliff**. It falls toward local +Z. Rotate around Y only, preferably in steps of 90°.

Main settings:
- `fall_height`, `width`, `basin_size`, `downstream_length`, `downstream_width`, `downstream_flow_speed`
- Set `build_lip_rock = false` if the level already has a cliff mesh. The sheet starts at `fall_height`.

The basin and downstream are ordinary WaterBody nodes (`$Basin`, `$Downstream`), so swimming works there too. Use `Waterfall.make_wet_rock_material(wetness)` on nearby rocks.

### Wind
- **No autoload required.** WindSystem creates its own driver node the first time something registers. Optionally, the owner of project.godot can add the autoload `Wind="*res://systems/nature/WindSystem.gd"`.
- Weather and level script: `WindSystem.set_wind(Vector2(dir), strength, gust_amount, gust_frequency)`.
- Gameplay sampling: `WindSystem.sample_wind(pos)`.
- Foliage: the existing `FoliageWind.configure(plant, height, base_y)` calls keep working. Pass `"tree"`, `"fern"` or `"rock"` as a 4th argument to choose the response. `"rock"` means no shader and zero motion.

### Grass
Instance `res://systems/nature/GrassScatter.tscn` above the terrain, set `area_size` and `density`, and leave `scatter_on_ready` on. It ray-casts down onto colliders and rejects:
- slopes steeper than `max_slope_deg`
- points under water
- points overlapping other collision (checked with a sphere of `overlap_radius`)
- moving bodies
- anything in group `no_grass` (use it on paths and floors)

Place it **after** the level geometry so it is ready two physics frames after `_ready`. Call `scatter()` again if the geometry changes.

## Out-of-scope issues seen (not mine; not fixed)
- `systems/GraphicsSettings.gd:164`: `var enable := ...` fails to parse in 4.7 ("Cannot infer the type"). As a result the GraphicsSettings autoload fails, GameManager's dependent scripts fail to compile, and `qa_reality_audit.gd` errors on `quality_level`. The water and foliage code tolerates a missing GraphicsSettings, but every level currently runs without graphics presets until this is fixed (for example `var enable: bool = ...`).
