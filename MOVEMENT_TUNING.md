# Mara Movement Tuning

Owner: player movement / animation agent. Measured on 2026-10-08 with `dev/movement_tests.gd`, headless, on `dev/MovementTestCourse.tscn`. Visual checks used the Compatibility renderer (opengl3) at the Ultra Low preset.

## Before (original Player.gd)
| Item | Old value | Problem |
|---|---|---|
| walk / run / sprint | 2.2 / 4.8 / 7.2 m/s | Velocity snapped instantly, with no acceleration |
| Deceleration | run_speed x 5 per second | Asymmetric |
| Jump | 5.2 m/s with project gravity 9.8, so a 1.38 m apex | Floaty: no fall multiplier, no coyote time, no buffer |
| Turning | lerp_angle on the visual only | Velocity was already reversed, so Mara could run backwards |
| Capsule | r 0.40, h 1.74 | Too wide for a 1.7 m character |
| Visual height | Ch1/3/4/6 used CHR_Mara_Optimized (no skeleton) at x1.7 | Mara was 2.89 m tall and frozen in bind pose |
| Slopes / steps | Godot defaults (45 deg), no step-up | |
| Mantle | lerp straight to the target | No clearance check, so it could pass through walls |
| Animation | AnimationPlayer idle/walk; walk at 0.8-2.2x | Visual lean was applied backwards |

## Current values (all are exports on Player.gd)
| Parameter | Value | Measured |
|---|---|---|
| walk / run / sprint / crouch | 1.6 / 3.6 / 5.6 / 1.3 m/s | Same, within 0.01 |
| Reach 95% speed | accel 14 m/s^2 | walk 0.12 s, run 0.25 s, sprint 0.38 s |
| Stop | decel 18 m/s^2 (x1.6 on a reversal) | run 0.20 s / 0.33 m, sprint 0.32 s / 0.83 m |
| Turn rate | 10 rad/s (6.5 while sprinting, half in the air) | A 180-degree reversal peaks at 65 deg between facing and velocity, so she never runs backwards |
| Gravity | 9.8; x1.9 falling; x2.4 rising with jump released | |
| Jump | apex target 1.10 m | Held: 1.147 m apex, 0.87 s airtime. Tapped: 0.505 m |
| Coyote / buffer | 0.12 s / 0.15 s | Both tested |
| Landing | hard at 9 m/s or more (0.35 s slowdown); damage above 15 m/s | A 4 m drop lands at 12.2 m/s, which counts as hard |
| Capsule | r 0.30, h 1.72 (crouched 1.15) | Replaced at runtime: the level capsule sub-resource is shared with NPCs |
| Visual | normalised to 1.70 m | 1.700 in all 12 levels |
| floor_max_angle | 44 deg, snap 0.32, stop_on_slope, block_on_wall | 15/30 deg climbable; 45/60 deg blocked |
| Step-up | 0.35 m max (test_move up / forward / down) | 0.15 and 0.30 m pass; 0.50 m blocked; 0.25 m rock passes; 0.9 m rock blocked; 0.18 m stairs up and down |
| Mantle | 0.45-1.9 m (from water 0.15-2.5 m) | Large rock 0.9, box 1.0 and ledge 1.6 all pass. A 4 m wall gets no mantle. The capsule path is validated with test_move |
| Climb | group "climbable" or meta climbable=true; 1.1 m/s | 4.5 m wall climbed and topped. A plain wall is refused |
| Camera | SpringArm sphere r 0.22, world mask 2, player excluded; pulls in instantly, eases out at 3 m/s; pivot dropped under low ceilings; h_offset 0.35 | Narrow cave: arm shortened to 2.02 m, camera not inside rock. Low pitch keeps the camera at y = 0.22 |

## Water contract (consumed by Player.gd)
- Water bodies are `Area3D` nodes in group `water_volume` that expose `get_surface_height(world_pos) -> float`. `systems/water/WaterBody.gd` implements this. Optional: `get_flow_velocity(world_pos) -> Vector3`, which is added to swim drift.
- The player polls `overlaps_body(self)` each physics frame, and the highest surface wins. If no volume is found, the player stays dry.
- Legacy push API is still accepted: `water_surface`, `water_vertical_velocity`, `enter_water()` and `exit_water()` (used by systems/WaterVolume.gd).
- Depth is measured from the feet to the surface:
  - Wading starts above 0.5 m (speed falls to x0.45 at most).
  - Swimming starts above 1.25 m and ends below 1.0 m once Mara is on the floor.
  - While floating, the feet sit 1.38 m below the surface (shoulders at the waterline).
  - Underwater means the head (feet + 1.55 m) is below the surface.
- Tested: entry from a fall; float at 0.91 m (expected 0.92); dive; resurface; climbing out over a rim 0.2 m above the surface; wading out up a 20-degree beach.

## Animation
- An AnimationTree is built in code. It is a state machine with these states: locomotion, crouch, swim, climb, jump, fall, land, mantle.
- The slot-to-clip mapping is data-driven (`clip_candidates`, `clip_fallback`). Every fallback chain ends at idle, so a missing clip never leaves Mara in a T-pose.
- Mara model: `CHR_Mara_Game_LOD0.glb`. Player.gd swaps it in at startup for any other Mara model a level instances.
  - Clips: idle, walk, run, jump, fall, climb, dive, swim.
  - Sprint plays run at about 1.35x.
  - Crouch is procedural: hips drop by leg-length x (1 - cos 62 deg), the knees bend so the feet stay planted, and the spine pitches forward 18 deg.
  - Death is a runtime PhysicalBone3D ragdoll (`scripts/Ragdoll.gd`).
- Natural speeds come from Hip root travel; root motion is stripped and the Hip pinned to the origin:
  - walk 1.107 m/s
  - run 4.126 m/s
  - climb 0.858 m/s
  - swim 0.367 m/s
- Foot sliding:
  - Each blend point has its own TimeScale set to ground speed divided by that clip's natural speed.
  - The blend position picks one dominant clip. Crossfades happen only in a 0.6 m/s band at the midpoint between gaits, because walk and run cycles are not phase-aligned.
- Stance-foot world speed, measured as the mean over each foot's lowest 20% of frames, worst foot:
  - Walk: 0.31 m/s. The source clip alone measures 0.07-0.09 m/s.
  - Run: 2.39 m/s. FAIL. The source run clip alone already slides 0.66-0.74 m/s (a retarget artifact). A per-frame trace shows one foot reaching 0.2-0.5 m/s, while the other foot's stance creeps at about 2.3 m/s.
  - Sprint: 3.0 m/s. FAIL, for the same reason.

## Known problems
1. Run and sprint foot slide. The run clip's right-foot stance is not planted in the source, and both ankles dip about 2.5 cm below the floor. Fixing this needs a cleaner run clip, or foot IK (SkeletonModifier3D two-bone IK with ground raycasts). Neither is done.
2. The swim clip's natural speed is 0.37 m/s, so playback is clamped at 3x while swimming at 1.6 m/s.
3. The 'land' state uses idle because there is no landing clip. Landing compression is a visual offset only.
4. Ragdoll joint limits are not tuned, so the bodies collapse into contorted poses.
5. Meridian gear sizes and offsets are set in code; alignment has not been checked up close.
6. Chapter 6 spawns Mara in water, so she starts in the swim state.
