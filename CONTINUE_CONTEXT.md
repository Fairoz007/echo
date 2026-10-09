# Echoes Beneath: Session Handoff Context

Paste this whole file into a new chat to continue the game-recovery work. Last updated 2026-10-09.

## 1. Hard rule: LOW GRAPHICS ONLY

The user wants every test run in low graphics. Never launch Forward+/Vulkan/D3D12 or the Medium/High/Ultra presets unless the user explicitly asks.

- Godot 4.7.2 (Steam build): `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- Every launch:

  ```
  godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 <scene or -s script> -- --quality=1
  ```

  `--quality=0` is ULTRA LOW and `1` is LOW. Add `--headless` when nothing needs rendering.
- Run only one test instance at a time. Agents share a lock:

  ```bash
  until mkdir "$TEMP/echoes_godot.lock" 2>/dev/null; do sleep 5; done; <godot ...>; rmdir "$TEMP/echoes_godot.lock"
  ```

  If a session dies, clear any stale lock and kill orphaned `godot` test processes. Don't kill the user's editor (`--editor`); the user said tests may run alongside it.
- Real keypresses can reach the test window. `qa_campaign_physical.gd` blocks F5, F9 and Esc through `dev/levelb_key_spy.gd`.
- `project.godot` already defaults to Compatibility/OpenGL, 1280x720 and the LOW preset.

## 2. API keys (never paste keys into files)

- Keys live only in the Windows DPAPI user store: `%USERPROFILE%\.codex\secrets\echoes-beneath\TRIPO_API_KEYS.dpapi` holds 9 comma-separated Tripo keys, and `ELEVENLABS_API_KEY.dpapi` holds the ElevenLabs key.
- Load them in Python with `scripts/production_credentials.py` → `get_secret("TRIPO_API_KEYS")` / `get_secret("ELEVENLABS_API_KEY")`. An environment variable with the same name overrides the stored value.
- Check Tripo balances with `python scripts/tripo_client.py balance`. The last known total was about 910 credits.
- ElevenLabs is on the free tier, which is **non-commercial only**, with about 995 credits left until about Nov 7.
- Never print or commit keys. Scan staged diffs before every commit. Old keys remain in git history (`API_CAPABILITY_MATRIX.md`, `scripts/tripo_client.py`) and must be revoked and rotated.

## 3. Repo state

- Branch `wip/game-recovery`. `master`/`main` is untouched.
- Commits this session:

  | Commit | Contents |
  |---|---|
  | `fb71ea0` | Level A/B fixes |
  | `aa6c097` | Player animation |
  | `dcfd2ee` | UI redesign |
  | `4ccbc65` | Player and camera polish |
  | `79e0542` | Full campaign PASS and final report |

- Reports:
  - **This session:** `FINAL_GAME_COMPLETION_REPORT.md` (verdict DO NOT SHIP), `LEVEL_B_REPORT.md`.
  - **Background:** `CURRENT_GAME_REALITY_AUDIT.md`, `MOVEMENT_TUNING.md`, `COLLISION_AUDIT.md`, `WATER_NATURE_REPORT.md`, `TRIPO_DELIVERY_REPORT.md`, `AUDIO_REPORT.md`, `PERFORMANCE_REPORT.md`.

## 4. Verified state (all on LOW)

| Check | Result |
|---|---|
| Parse every script (`dev/parse_all.tscn`; `-s` mode gives false autoload errors, so run it as a scene) | 0 failures |
| `scripts/qa_campaign_physical.gd`, New Game → Credits → Main Menu | **PASS**, 828.9 m, about 9 min |
| `scripts/qa_story_flow.gd` | PASS (its death check now waits 2.2 s for the 1.6 s ragdoll) |
| `dev/movement_tests.gd` | 54/54 |
| `scripts/qa_water_input.gd` | PASS |
| `scripts/qa_collision_audit.gd` | 3901 rows, 0 failures |

What was done this session:

- **Levels and loading:**
  - Ch1 parse error fixed.
  - Prologue route clear.
  - Jolt trimesh errors fixed.
  - Ch9 load reduced: start-up 2.7 s → 1.2 s (threaded `HeroProps`, staged `CaveBuilder`/`LevelCave`).
  - Hero assets placed in all eight levels on the Level A list.
- **Visuals and fixes:**
  - Ch6 water, light shaft, specks and hall fixed.
  - Ch1 grass, trail, haze and lanterns fixed.
  - Enemy doubled gear (the cause of "material is null") fixed in `LBMeridianGear.gd`.
- **Player (`scripts/Player.gd`, `scripts/CameraController.gd`):**
  - Frozen `Start` state bug fixed.
  - 0.15 s fall grace.
  - Smoothed gait blend and turns.
  - Lean follows acceleration.
  - Swim stroke rate scales with speed.
  - Sprint arm crossover and run knee bend reduced.
  - Idle knee straightened.
  - Camera arm eases out after an obstruction clears.
  - Hand props load asynchronously (start-up 400 ms → 3 ms).
- **UI:**
  - Shared theme in `ui/GameTheme.gd` and `ui/theme/echoes_theme.tres`, set in `project.godot`.
  - Redesigned menu, HUD, pause, settings, journal, death screen and story cards.
  - Screenshots in `screenshots/ui/`.

## 5. Open work (priority order)

1. **Release blockers (user decisions):** the ElevenLabs free tier is non-commercial, so upgrade and regenerate the voices or replace them. Revoke and rotate the leaked keys.
2. **Ch7 is very dark:** do a lighting pass (Level A ownership).
3. **Animation:**
   - The leading arm reaches slightly forward in the run.
   - The idle clip has a soft knee; a straight stance needs a new idle clip.
   - There's no true turn in place.
   - The remaining polish list hasn't been started.
4. **Visuals:** white flecks on a Ch8 pillar, and flat-looking Ch1 grass.
5. **Load spikes:** 380–630 ms frames on Ch7/Ch9, from `systems/CampaignEnvironmentArt.gd` (no owner yet) and the cave shell build.
6. **Untested:**
   - 1920x1080
   - a real gamepad
   - camera pull-in against a wall
   - the Ch6 cistern puzzle played by hand
   - UI sounds by ear
   - HUD bars have no labels or icons
7. Re-run the full campaign, commit, and update `FINAL_GAME_COMPLETION_REPORT.md`.

## 6. Working method

- **File ownership:**

  | Owner | Files |
  |---|---|
  | Level A | `systems/environment/`; Prologue, Ch2, Ch3, Ch4, Ch7, Ch9, Ch10, Finale |
  | Level B | `systems/levelb/`; Ch1, Ch5, Ch6, Ch8, Epilogue |
  | Movement | `scripts/Player.gd`, `Ragdoll.gd`, `CameraController.gd`, Mara assets |
  | UI | `ui/**` |

  Never let two agents edit the same file.
- After every change, run on LOW, capture screenshots or frame sequences (`dev/seq_capture.gd`, `dev/ui_capture.gd`, `dev/levela_capture.gd`), look at them at full size, and fix whatever is visibly wrong.
- Commit on `wip/game-recovery` with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Scan for keys before committing.
