# Animation Integration Report

## Files changed

- `scripts/Player.gd`: new procedural layers, hand IK, turn-in-place drive, run-arm fix, API.
- `scripts/CameraController.gd`: controls hooks requested by the coordinator.
  - The mouse pitch obeys `InputRemap.invert_y`.
  - Each physics frame, when the tree isn't paused, it reads the stick look vector from `InputRemap.get_look_vector()`: yaw at 3.0 rad/s and pitch at 2.2 rad/s, clamped to `min_pitch`/`max_pitch`.
  - `InputRemap` is looked up with `get_node_or_null`, so the script still works without the autoload.
- New:
  - `dev/character/CharacterTest.tscn` and `CharacterTest.gd`: the movement course (flat ground, rocks, slopes, stairs, climbable wall, pool) plus a lever interactable.
  - `dev/character/character_tests.gd`: measurements and LOW frame capture.
  - `CHARACTER_BASELINE_AUDIT.md` and the three reports.

## What was added (all procedural, no new clips)

| Feature | How it works | Measured |
|---|---|---|
| Straight-knee idle | Stance lift to 0.995 leg length plus a pelvis tilt for the unequal legs | knee 168.5° (clip alone ~148°) |
| Idle breathing | 0.24 Hz pitch on Spine02 and lift on the clavicles, weighted by idle | head travel 7.4 mm |
| Turn in place | Standing turns drive the walk cycle at 0.95 m/s pseudo-speed so the feet step and re-plant; spine and head lead the turn by up to 22° | turn weight 1.0; gait blend 0.27 at under 0.5 m/s |
| Soft/hard landing | Hip squash replaces the old whole-mesh drop, which sank the feet; the leg IK bends the knees and the spine pitches forward | soft 0.069 m (7.5 m/s); hard 0.124 m (12.8 m/s); feet gap 0.000 |
| Hit reaction | Spine, chest and head snap away from the hit direction, then recover in 0.45 s; fires from `take_damage` | weight 0.70, head 0.106 m, recovers to 0 |
| Interact reach | The right arm reaches toward the interactable through IK (pickup, lever, button) | hand 0.106 m from the lever centre |
| Climb hand IK | Each animated hand is projected onto the wall with a raycast | average gap 0.003 m over 104 samples |
| Mantle hand IK | Both hands are pinned to the ledge lip for the whole mantle | gap 0.000 m |
| Run leading arm (§5.3) | Forward swing ×0.5 of the backward swing; the whole arm is rotated back when the hand would pass 0.27 m ahead of the chest, which keeps the elbow bend | run and sprint 0.270 m (was 0.395 / 0.407) |

## Tests (all on LOW)

| Test | Result |
|---|---|
| `dev/character/character_tests.gd` | **27/27 PASS** |
| `dev/movement_tests.gd` | **54/54** |
| `scripts/qa_water_input.gd` | **PASS** |

The character tests run on gl_compatibility / opengl3 at `--quality=1`.

## Screenshots

Frames are in `screenshots/character/<case>_fNN.png`, and contact sheets are in `screenshots/character/sheet_*.png`. Cases: idle, turn_180, turn_90, stand_slope15/30, stand_stairs, walk_stairs/slope15/rock, land_soft/hard, hit_front/side, interact, climb, climb_top, mantle, run_arms, sprint_arms, swim_entry.

## Unresolved / honest defects

- **Turn in place is only partial.** The 180° turn takes about 0.3 s, which is faster than the gait-blend smoothing, so only about a quarter step plays. A slower standing turn rate would fix it, but it would change movement feel and the movement tests, so I left it.
- **Landing squash is subtle.** It's measurable (0.12 m) but short (about 0.2 s), and it's hard to see on the capture sheet.
- **Not implemented:** strafe (the design is turn-to-move), slide, ledge hang/shimmy (the `LEDGE_HANG` state is unused), aim/fire/reload/melee upper-body poses, and push. Each needs a gameplay state or clips.
- **Framing:** the climb capture camera loses Mara near the top of the wall. The metric still covers it.
- **Other agents' work, not mine:** during one run, other agents' in-progress scripts (`ui/controls/ControlsMenu.gd`, `systems/MaraAppearance.gd`) briefly failed to parse. They were clean in the final runs.
