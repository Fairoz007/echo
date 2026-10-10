# Production Status

Updated 2026-10-10. Branch `claude/echoes-beneath-campaign-polish-d9lawx`, base `32688d8`.

## Test environment
This is a Linux cloud container running the official Godot 4.7.2 build. It uses `gl_compatibility`/`opengl3` on LOW (`--quality=1`). Rendered captures go through Xvfb with software GL. **The renders aren't representative of performance, and they say nothing about Windows or Forward+.**

## Verified this session
| Check | Result |
|---|---|
| `dev/parse_all.tscn` | bad=0 |
| `dev/movement_tests.gd` | 54/54 |
| `scripts/qa_story_flow.gd` | PASS (0 failures) |
| `scripts/qa_campaign_physical.gd` (Xvfb, LOW) | **PASS**: New Game → Credits → Main Menu, 829.8 m, 1024 s route time |
| `dev/ch5_stealth_test.gd` | PASS |
| Ch6 spawn camera (`dev/ch6_spawn_capture.gd`) | Fixed. Details below. |

## Fixed
- **Ch6 camera obstruction.** It wasn't reeds: the camera spawned behind the south temple wall (`HallWall15/16`). The wall's trimesh didn't stop the spring arm when sweeping from inside the hall. A solid `SouthWallBacking` collider on world layer 2 was added in `systems/levelb/Chapter6Dressing.gd`. The camera now sits at z 24.78 (it was at 26.39) with a clear view of Mara and the flooded hall.

- **Ch5 "regression" (QA-002):** this was a test-environment artifact, not a game bug. `--headless` can't capture the mouse, so the bot's aim never moved. The test now detects this and fails with a clear message.
- **Ch5 stealth route (QA-003):** reaching the observation ledge undetected now completes the checkpoint objective without killing the patrol.

## Open P0/P1
- **P0:** none known. The campaign passes.
- **Content:** about 8 hours short of the 600-minute target. See `TEN_HOUR_GAMEPLAY_AUDIT.md`.
- **P1:** The rest of the list in `CONTINUE_CONTEXT.md` §5 is still unverified here: missing animations, the loading hitch, the Ultra hang, gamepad support.

## Playtime
Not measured. The last automated traversal took about 9 minutes, which isn't a playtime measurement. The 600-minute target is not met, and no human playtest has been done.

## Next three tasks
1. Build out the Ch7 hub districts: the largest content deficit.
2. Run a rendered capture pass over every chapter's spawn to find more camera and visual defects.
3. Measure each chapter against `CHAPTER_DURATION_MATRIX` targets (not yet authored).
