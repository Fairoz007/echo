# Lighting and material refinement — 2026-10-10

Implemented using the existing assets on Godot 4.7.2 / Compatibility OpenGL. This is a focused lighting/material improvement, not a claim that the whole game is photorealistic or release complete.

## Changes

- High/Ultra now use a refined light balance (65% / 100% blend). Chapter 1 has more neutral sunlight, reduced sky fill, clearer shadows and cooler distance haze. Ultra Low/Low/Medium restore the original lighting endpoints.
- Procedural chapter caves receive a restrained ambient-fill floor on High/Ultra so limestone and architecture remain visible beyond local lamps. Asynchronous cave builds apply the currently selected quality when their environment becomes ready.
- Stretched rock/terrain normals use the inverse-transpose normal matrix. Cave triplanar normal detail is projected into world space instead of blending unrelated tangent-space RGB directions; neutral maps retain the geometric normal.
- Rock moss overrides retain every surface's source albedo, normal strength and roughness texture/scalar/channel, including packed ORM green. Exact source/style cache keys avoid accidental sharing between different materials.
- No new model/texture generation, realtime reflection passes or renderer changes. No campaign logic, save formats, authored collision or Mara assets were changed.

## Verification

Machine: RTX 2060, NVIDIA 617.42. Rendered at 1280×720, OpenGL 3.3, 60 FPS test cap. One Godot test process at a time under the shared lock. QA saves use `user://qa_lighting_materials`; the runner snapshots/restores current top-level user files.

- `lighting_materials_2026_10_10.log`: **33 checks, 0 failures**, Godot exit 0. Includes multi-surface PBR preservation, cache distinctions, Chapter 1/7 live Low/Ultra restoration, 41-bone rig presence, floor support, unchanged collision-shape counts and captures. The wrapper was initially passed an incorrect expected count of 35; the actual 33-result success marker and absence of errors were inspected afterward, without rerunning successful checks.
- After increasing cave fill for readability, `lighting_cave_final_2026_10_10.log`: **12 checks, 0 failures**, runner/Godot exit 0. Only Chapter 7 was retested; material and Chapter 1 code were unchanged.
- Stationary 1.5-second samples: Chapter 1 mean 16.31 ms / p99 17.46 ms, 526 draw calls; final Chapter 7 mean 16.31 ms / p99 16.92 ms, 264 draw calls. These are short samples at a 60 FPS cap, not an uncapped benchmark or long-session guarantee.
- Captures in `screenshots/lighting/`: `Chapter1_authored_lighting.png`, `Chapter1_ultra.png`, `Chapter7_authored_lighting.png`, `Chapter7_ultra.png`. Visually inspected. Each pair uses the same new materials and Ultra geometry; only the lighting balance changes. Wind/idle animation can advance between captures.
- Read-only code review found no concrete regression in quality restoration, asynchronous setup or per-surface material caching. `git diff --check` passed.

## GPU incident and remaining limits

An earlier harness attempt preloaded a gameplay dependency before its autoload existed; the harness now loads that dependency after initialization. That attempt exited abnormally. A subsequent launch failed OpenGL/ANGLE initialization, and `nvidia-smi` reported the GPU lost and requested reboot. The relationship between the harness failure and driver loss is unproven. Failure logs are retained as `lighting_harness_initialization_failure.log` and `lighting_gpu_initialization_failure.log`.

On resumption, NVIDIA reported the GPU available again. Both rendered validations above completed without shader/script errors. This does not resolve the historical driver crashes; Forward+/Vulkan and long-duration Ultra operation remain unverified. Other chapter lighting still needs visual acceptance, and existing asset silhouette/texture limitations remain.

Repeat the complete check only after relevant changes:

```powershell
./dev/run_recovery_test.ps1 -Target '-s res://dev/lighting_material_tests.gd' -Log lighting_materials -UserArgs '--quality=4' -ExpectedMarker 'failures=0' -TimeoutSeconds 150
```

Normal-matrix reference: [Godot spatial shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
