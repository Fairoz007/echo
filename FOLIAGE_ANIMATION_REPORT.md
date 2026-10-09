# Foliage animation report

## Plant profiles (`FoliageWind.PROFILES`)

| Profile | Base | Motion | Player push |
|---|---|---|---|
| tree | Rooted (8% lock) | Primary sway, branches, leaf flutter | none |
| shrub / bush | Rooted (5%) | Soft whole-plant sway; outer leaves move most (radial flex) | 0.45 |
| fern | Rooted (4%) | Very soft fronds, strong flutter at the tips | 0.55 |
| vine | **Pinned at the top** (`pin_top`) | Free end swings; weight `(1-hn)²` | 0.4 |
| grass (MultiMesh) | Rooted (blade height²) | Per-instance phase/stiffness, blade flutter | 0.55 |
| rock | — | Never converted | — |

- **Converting procedural or untextured plants:** set `accept_untextured = true` before calling `configure()`.
- **Level B:** `LBFoliageWind` now inherits all of this. It keeps its amplitude boost (`amplitude`) and still accepts materials that have no normal or ORM map.

## Falling leaves (`systems/nature/FallingLeaves.gd`)

- **Particles:** GPUParticles3D, with a CPUParticles3D fallback (`force_cpu`, or a renderer that has no GPU particle path). The GL Compatibility renderer uses GPU particles; this was verified (`leaves_gpu=true`).
- **Wind response:** every frame, gravity follows `WindSystem.sample_wind()`. Particles that are already in the air follow wind changes immediately. Spin and turbulence grow with storm.
- **Rate:** `leaves_per_second × (0.5 + 0.5·strength) × (1 + 3·storm) × foliage_density`, applied through `amount_ratio`, so there's no restart.
- **Quality:** turned off on ULTRA LOW (`detail 0`).
- **Campaign use:** `follow_camera = true` keeps the emitter over the camera.

## Test results (LOW, `dev/nature/nature_capture.gd`)

The numbers below are mean frame-to-frame difference from `nature_sheet.py` (`motion`), and the percentage of pixels that move:

| Case | CALM | BREEZE | STRONG | STORM |
|---|---|---|---|---|
| wide | 0.92 / 2.1% | 2.68 / 7.0% | 6.99 / 16.2% | 9.60 / 20.1% |
| canopy | 0.61 | 2.15 | 5.67 | 7.22 |
| forest row | 0.72 | 2.74 | 5.73 | 10.98 |
| vines | – | 1.14 | – | 5.49 |

**What I saw at full size:**

- **Rooting and storm safety:** trunk bases and root flares stay fixed in every storm frame. No vertices fly off and there is no stretching.
- **Canopy and leaves:** the canopy leans downwind and the leaf cards flutter independently.
- **Desync:** the forest row moves out of phase.
- **Leaves:** falling leaves drift downwind, and there are visibly more of them in a storm.
- **Calm:** motion is subtle but present (not static).
- **Blend test:** a CALM→STORM blend over 2 s had a largest per-frame step of 0.027 and emitted 18 `wind_changed` signals.

**Fix made after review:** grass rendered with `grass_wind.gdshader` had black back-facing blades in Compatibility. I applied the Level B world-up fragment normal fix and lifted the AO. This also addresses open issue "flat Ch1 grass" for any level that uses the base shader.

## Known limits

- **Tripo trees:** they have no vertex-colour masks, so the radial mask is used. Some branches near the trunk move less than outer ones, which is intended.
- **Opaque only:** the wind shader is opaque. Alpha-cut card foliage is skipped and stays static, because converting it would render as silhouettes.
