# Echoes Beneath — Session Handoff Context

Paste this whole file into a new chat to continue the game-recovery work.

## 1. Hard rule: LOW GRAPHICS ONLY

The user wants every test run in low graphics. Never launch Forward+/Vulkan/D3D12 or the Medium/High/Ultra presets unless the user explicitly asks.

- Godot 4.7.2 (Steam build):
  `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- Every launch:
  ```
  godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 <scene or -s script> -- --quality=1
  ```
  `--quality=0` = ULTRA LOW, `1` = LOW. Use `--headless` when nothing needs rendering.
- Run only one Godot instance at a time and close it after each test.
- `project.godot` already defaults to Compatibility/OpenGL, 1280x720, the LOW preset. `build/windows/SafeGraphics.cmd` launches ULTRA LOW.
- History: an earlier GPU crash came from a loose cable. On 2026-10-08, after the cable change, a test run on Ultra (Vulkan, 1080p) passed all levels with no crash (RTX 2060, peak 75 °C, 174 W). Even so, the user's standing instruction is to test on LOW only.

## 2. API keys: how they are stored and used (never paste keys into files)

- Keys live ONLY in the Windows DPAPI-encrypted user store, outside the repo:
  - `%USERPROFILE%\.codex\secrets\echoes-beneath\TRIPO_API_KEYS.dpapi`: 9 Tripo keys, comma-separated, used in order.
  - `%USERPROFILE%\.codex\secrets\echoes-beneath\ELEVENLABS_API_KEY.dpapi`
- Load them in Python with `scripts/production_credentials.py` → `get_secret("TRIPO_API_KEYS")` / `get_secret("ELEVENLABS_API_KEY")`. An environment variable of the same name takes priority if it is set.
- Add a new Tripo key without printing the existing ones (PowerShell):
  ```powershell
  $p = Join-Path $env:USERPROFILE '.codex/secrets/echoes-beneath/TRIPO_API_KEYS.dpapi'
  $s = (Get-Content -LiteralPath $p -Raw).Trim() | ConvertTo-SecureString
  $old = [System.Net.NetworkCredential]::new('', $s).Password
  ConvertTo-SecureString ($old + ',NEW_KEY_HERE') -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $p -Encoding ascii
  ```
- Check balances (no keys printed): `python scripts/tripo_client.py balance`, or GET `https://api.tripo3d.ai/v2/openapi/user/balance` with a Bearer key.
- Last known Tripo credits: about 910 in total (key 9: 600, key 8: 240, key 3: 40, key 2: 30; all others 0).
- ElevenLabs: free tier, about 995 credits left until about Nov 7. The free tier is non-commercial only.
- Rules: never print, commit, or write keys into docs or Godot resources. Old keys exist in git history (`API_CAPABILITY_MATRIX.md`, `scripts/tripo_client.py`); they should be revoked. Keys pasted in chat should be rotated.

## 3. Repo state

- Branch `wip/game-recovery`, checkpoint commit `f03621d` (not a release). `master` is untouched.
- Reports to read: `CURRENT_GAME_REALITY_AUDIT.md`, `MOVEMENT_TUNING.md`, `COLLISION_AUDIT.md`, `WATER_NATURE_REPORT.md`, `TRIPO_DELIVERY_REPORT.md` (Phase 2 asset hand-off table), `AUDIO_REPORT.md`, `LEVEL_B_REPORT.md`, `PERFORMANCE_REPORT.md`.

## 4. Done (verified)

- **Player** (`scripts/Player.gd`): rebuilt.
  - Measured speeds: walk 1.6, run 3.6, sprint 5.6 m/s.
  - Jump apex 1.15 m. Slopes up to 30–45°, steps up to 0.3 m.
  - Mantling, climbing (only on `climbable` surfaces) and swimming all work.
  - Foot-lock IK. Run posture fixed.
  - 54/54 checks in `dev/movement_tests.gd`.
- **Mara**: `assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb` with idle, walk, run, jump, climb, fall, dive and swim clips.
  - Sprint is the run clip at 1.36× speed; crouch is a procedural pose; death is a ragdoll.
  - No T-pose in any level: `Player.gd` swaps old Mara models at runtime.
- **Collision**: automatic via `systems/environment/EnvironmentCollision.gd`. The audit (`scripts/qa_collision_audit.gd`) shows 0 failures.
- **Water and wind**: `systems/water/` (WaterBody presets, buoyancy, rise/drain, waterfall), `systems/nature/` (wind, grass scatter).
- **Audio**: ElevenLabs dialogue, recaps and soundscapes, normalized; buses and reverb zones in `systems/audio/`.
- **UI**:
  - Story transition cards with recaps (`ui/StoryTransition.gd`).
  - Journal, inventory and skills screen on the J key.
  - Five graphics presets.
- **Story flow**: `scripts/qa_story_flow.gd` passed 17/17 (New Game → Credits flow, save/continue, death/checkpoint).
- **Tripo**: 65 hero assets with LOD0–3 in place, listed per chapter in `TRIPO_DELIVERY_REPORT.md`.

## 5. Open work (in priority order)

NOTE: The last session ended while three agents (Level A, Level B, Movement/Animation) were working on the items below. They may have left partial, uncommitted edits. Start by running `git status` and `git diff --stat` on `wip/game-recovery`, then do a headless parse check of all scripts:
`godot --headless --path D:/new-dev --quit`
Fix any parse errors before anything else.


1. **P0:** `levels/Chapter1.gd` parse error. It can't preload `systems/levelb/Chapter1Dressing.gd` ("Cannot infer the type of 'dressing'"), so Chapter 1 loads empty.
2. **P0:** Prologue route blocker. Holding W stops Mara at about z = -16. Use a shape query along the route centreline (`scripts/qa_prologue_centreline.gd` exists).
3. Jolt concave-shape errors ("Need triangles to create a mesh shape!") on `ChasmWallsBody` and two other StaticBody3Ds, around chapter index 7–8. Build these with `mesh.create_trimesh_shape()`.
4. Chapter index 9 has a 1 FPS stall on load (synchronous generation).
5. **Ch6 visuals:** flat teal water, a rectangular light shaft, a dark hall, white wall specks.
6. **Ch1 visuals:**
   - black spiky grass
   - blurry trail texture
   - washed-out haze
   - placeholder lamp post
7. Integrate the hero assets into Prologue, Ch2, Ch3, Ch4, Ch7, Ch9, Ch10 and the Finale (these were flat planes in fog). Update the route table in `scripts/qa_campaign_physical.gd`.
8. Make `scripts/qa_water_input.gd` place Mara in water first (Ch6 now spawns her on dry ground).
9. Animation polish:
   - sprint forearm crossover
   - deep knee bend mid-stance in the run clip
   - swim clip plays at its 3× speed cap
   - pelvis height doesn't adjust on uneven ground
10. Then run the full New Game → Credits playthrough on LOW, commit, and write `FINAL_GAME_COMPLETION_REPORT.md` ending in SHIP / DO NOT SHIP.

## 6. Working method

- Level ownership: Prologue, Ch2, Ch3, Ch4, Ch7, Ch9, Ch10 and the Finale use `systems/environment/`. Ch1, Ch5, Ch6, Ch8 and the Epilogue use `systems/levelb/`. Don't have two agents edit the same file.
- After every change: run on LOW, capture screenshots or frame sequences, look at them at full size, and fix what's visibly wrong.
- Commit on `wip/game-recovery`, with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Scan for keys before committing.
