# Character Baseline Audit: Mara

This is the state of the rig and animation before the character pass (2026-10-09, branch `wip/game-recovery`, HEAD `6053bbf`). Every measurement was taken on LOW (gl_compatibility / opengl3, `--quality=1`).

## Rig

- **In-game model:** `assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb`. `Player._ensure_rigged_model()` swaps it in at start-up for any other Mara GLB a level instances.
- **Skeleton:** 41 bones, one skinned mesh of 39.8k vertices, normalised to 1.70 m.
  - The bone chain is Root > Hip > Pelvis > L/R Thigh > Calf > Foot > ToeBase, plus twist bones. The spine runs Waist > Spine01 > Spine02 > NeckTwist01/02 > Head. Each arm runs L/R Clavicle > Upperarm > Forearm (+ ForearmTwist) > Hand.
  - There are **no finger bones**, so hand poses (grip, point, fist) are impossible without re-rigging.
- **Skeleton space:** Mara faces +X, +Y is up and +Z is lateral. In the clips' bone space, the Hip translation is Z-up.
- **Other GLBs:**
  - LOD1–LOD3 exist but the player doesn't use them.
  - `CHR_Mara_Optimized.glb` is static and `CHR_Mara_Production.glb` has only idle and walk. Both are legacy and get replaced at runtime.
- **Verdict:** the rig is usable, so repair it rather than regenerating it.

## Clips (8)

| Clip | Natural ground speed @1x | Used for slots |
|---|---|---|
| idle | 0 | idle, land, crouch_idle |
| walk | 1.107 m/s | walk, crouch_walk |
| run | 4.126 m/s | run, sprint (×1.35 floor) |
| jump | n/a | jump |
| fall | n/a | fall |
| climb | 0.858 m/s | climb, mantle |
| dive | n/a | not mapped (swim stand-in candidate) |
| swim | 0.367 m/s (tempo-driven) | swim_idle, swim |

All clips are retargeted Tripo animations.

- **run:** retargeted. It runs in a deep crouch with the leading arm thrust forward, palm up.
- **idle:** has soft knees of about 148°.

## AnimationTree (built in code, `Player._build_anim_tree`)

- **State machine:** `locomotion` (1D blend of idle/walk/run/sprint, one TimeScale per point), `crouch`, `swim`, `climb`, `jump`, `fall`, `land` and `mantle`. Every pair is connected, and the cross-fades come from `_xfade`.
- **Root motion:** `_make_in_place` strips Hip/Root XY travel and records each clip's natural speed. Playback is scaled by ground speed ÷ natural speed so the feet don't slide.
- **Post-tree procedural layers** run on `mixer_applied` in this order:
  1. crouch pose
  2. run posture (lean, head level, phase-locked arm swing)
  3. foot lock with a 2-bone leg solve, pelvis drop and stance-extension lift

## Gaps against the target list (before this pass)

| Target | State before | Plan |
|---|---|---|
| Idle breathing | none | procedural (spine and clavicles) |
| Straight-knee idle | partial: stance lift to 0.985 leg length | keep the lift, then verify knee angle by measurement |
| Strafe | none; the character always turns to face the input | out of scope: the design is turn-to-move; aiming walks forward-facing |
| Start / stop | handled by gait blend and stride-matched playback down to 0.2× | no change |
| Turn in place | **none**: the body spins on fixed feet | procedural: walk cycle driven at pseudo-speed during standing turns, with the upper body leading |
| Soft / hard landing | land = idle clip for 0.12–0.3 s; the whole mesh was dropped (feet sank into the floor) | procedural hip squash absorbed by the leg IK |
| Ledge hang / shimmy | `LEDGE_HANG` enum exists but is unused | not implemented (no gameplay state drives it) |
| Slide | none | not implemented |
| Crawl | crouch pose only (1.15 m capsule) | unchanged |
| Water entry / exit | swim blend with a 0.4 s cross-fade; climb-out mantle | foot IK disabled in SWIM; hand IK on the climb-out mantle lip |
| Interact / pickup / lever / push | none | procedural right-hand reach IK toward the interactable |
| Aim / fire / reload / melee | none (sidearm prop shown only) | not implemented (would need an upper-body layer; no clip) |
| Hit reaction | none | procedural flinch away from the hit direction |
| Death | ragdoll (`Ragdoll.gd`, 1.6 s) | unchanged |
| Hand contacts on climb / mantle | hands float off the wall and ledge | hand IK onto raycast contact points |
| Foot IK on slopes, stairs, rocks | foot lock plus pelvis drop; feet stayed flat on slopes | added foot alignment to the ground normal; explicitly off in air and water |
| Run leading arm (§5.3) | forward swing plus the elbow bend let the hand reach ahead | shorter forward swing (×0.5) plus a 0.27 m hand-ahead-of-chest limit |

**Tripo credits:** none spent. Every gap above that is addressed was filled procedurally. The remaining gaps are slide, ledge shimmy and aim/reload/melee. They need gameplay states or clips, but none of them is a blocker for the existing levels.
