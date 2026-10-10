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
| `scripts/qa_campaign_physical.gd` | **FAIL**: "Mara died in patrol combat Enemies/EnemyMercenary1" in Ch5. It reproduces on the unmodified base `32688d8`, so it's a regression since the `7a23488` PASS. |
| Ch6 spawn camera (`dev/ch6_spawn_capture.gd`) | Fixed. Details below. |

## Fixed
- **Ch6 camera obstruction.** It wasn't reeds: the camera spawned behind the south temple wall (`HallWall15/16`). The wall's trimesh didn't stop the spring arm when sweeping from inside the hall. A solid `SouthWallBacking` collider on world layer 2 was added in `systems/levelb/Chapter6Dressing.gd`. The camera now sits at z 24.78 (it was at 26.39) with a clear view of Mara and the flooded hall.

## Open P0/P1
- **P0:** Ch5 patrol combat kills the automated player, which blocks the physical campaign run. Next step: bisect `7a23488..32688d8`.
- **P1:** The rest of the list in `CONTINUE_CONTEXT.md` §5 is still unverified here: missing animations, the loading hitch, the Ultra hang, gamepad support.

## Playtime
Not measured. The last automated traversal took about 9 minutes, which isn't a playtime measurement. The 600-minute target is not met, and no human playtest has been done.

## Next three tasks
1. Bisect and fix the Ch5 combat regression, then get a full campaign PASS.
2. Run a rendered capture pass over every chapter's spawn to find more camera and visual defects.
3. Measure each chapter against `CHAPTER_DURATION_MATRIX` targets (not yet authored).
