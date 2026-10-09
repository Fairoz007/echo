# Echoes Beneath: Final Game Completion Report

Date: 2026-10-09 · Branch: `wip/game-recovery` · All tests ran on LOW (gl_compatibility / opengl3 / 1280x720 / `--quality=1`).

## Verification results

| Check | Result |
|---|---|
| Parse every `.gd` file (`dev/parse_all.tscn`) | 0 failures |
| Full New Game → Credits (`scripts/qa_campaign_physical.gd`) | **PASS**: 828.9 m, 534 s of route time, through the credits and back to the Main Menu, with 0 script errors |
| Story flow (`scripts/qa_story_flow.gd`) | PASS, 0 failures (save/continue, death/checkpoint, Finale → Epilogue → Credits) |
| Movement (`dev/movement_tests.gd`) | 54/54 |
| Water input (`scripts/qa_water_input.gd`) | PASS |
| Collision audit (`scripts/qa_collision_audit.gd`) | 3901 rows, 0 failures, 0 white |
| Prologue centreline and walk | PASS: no blocker at z=-16 |

## Open items from the handoff list

1. **Ch1 parse error:** fixed. A comment had been joined onto a code line in `Chapter1Dressing.gd`, and Ch1 now loads its dressing.
2. **Prologue route blocker:** verified clear.
3. **Jolt "Need triangles":** fixed. Degenerate meshes are skipped and shapes are built with trimesh.
4. **Ch9 load stall:** reduced. Start-up dropped from 2719 ms to 1160 ms and the worst frame from 553 ms to 383 ms. Hero props now load on a thread, and the cave builds in stages over several frames.
5. **Ch6 visuals:** fixed. The water is clear, the light shaft is soft, there are no wall specks, and the hall is readable.
6. **Ch1 visuals:**
   - Grass now renders green instead of black.
   - The trail texture is sharp (anisotropic filtering plus path grit).
   - The haze is lighter.
   - The lamp posts are hanging lanterns.
7. **Hero assets:** placed in Prologue, Ch2–4, Ch7, Ch9, Ch10 and Finale, and those chapters pass the route test.
8. **Water QA:** Mara now starts in the water.
9. **Animation:**
   - Fixed a frozen-pose bug (the state machine could stall in its `Start` state).
   - Fall clip waits a 0.15 s grace period.
   - Clip blends and turning are smoothed.
   - Lean follows acceleration.
   - Swim stroke rate scales with speed.
   - Sprint arms no longer cross the midline.
   - Planted run knee is straighter (119° to 129°).
   - Idle knee is straighter (147° to 160°).
   - Camera arm eases out after an obstruction clears.
10. **Also done:**
    - UI redesign with a shared theme for every screen.
    - The renderer error `Parameter "material" is null` traced to doubled enemy helmet and rifle gear, and fixed.
    - The QA route test now blocks stray F5/F9/Esc keypresses and restarts a chapter's route if the chapter reloads.

## Remaining issues

- **Licensing (blocks a commercial release):** the ElevenLabs dialogue was made on the free tier, which is **non-commercial only**. Either upgrade the plan and regenerate the dialogue, or replace it.
- **Security:** old Tripo and ElevenLabs keys are still in git history (`API_CAPABILITY_MATRIX.md`, `scripts/tripo_client.py`). They must be revoked and rotated before the repo is shared.
- **Animation:**
  - The leading arm still sits slightly forward in the run.
  - The idle clip keeps a soft knee bend; a straight stance needs a new idle clip.
  - Turning on the spot from standing is not a true in-place turn.
- **Visuals:**
  - Ch7 is very dark.
  - A Ch8 pillar shows white flecks.
  - Ch1 grass reads flat.
- **Performance:** Ch7 and Ch9 still have frames of 380–630 ms during load, coming from `CampaignEnvironmentArt.gd` and the cave shell build.
- **Not tested:**
  - 1920x1080
  - a real gamepad
  - camera pull-in against a wall behind Mara
  - the Ch6 cistern rising-water puzzle played by hand
  - the new UI sounds by ear

## Verdict

The game can be played start to finish on LOW with no blockers. That makes it fine for a private or demo build. It is not ready for a commercial release because of the voice-over licence and the leaked keys.

**DO NOT SHIP**
