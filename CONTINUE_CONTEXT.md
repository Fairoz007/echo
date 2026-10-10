# Echoes Beneath: Session Handoff Context

Paste this whole file into a new chat to continue the game-recovery work. Last updated 2026-10-10.

## 1. Hard rule: LOW GRAPHICS BY DEFAULT

Test on LOW by default. On 2026-10-09 the user asked for the game to be "optimized for all graphics", so the Ultra Low to Ultra presets (`--quality=0..4`) may be tested, but always with `gl_compatibility`/`opengl3`. Never launch Forward+/Vulkan/D3D12 unless the user explicitly asks; they caused GPU crashes before.

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

- Work happened on branch `wip/game-recovery` (this session: `7a23488`). As of 2026-10-10 the checkout is on `main` with newer commits from another tool (see §4b); verify with `git branch` before working.
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

## 4b. Session 2026-10-09/10: five-agent pass (commit `7a23488`)

The user asked for the work to be split into subagents by category, with wind animation, control customization and character customization included and every graphics preset optimized. Five agents ran in parallel, each owning separate files:

| Agent | Built | Report(s) |
|---|---|---|
| Character | Straight-knee breathing idle, turn-in-place stepping, hip-drop landing, hit reaction (`take_damage(.., from_dir)`), interact reach, climb/mantle hand contact, slope foot tilt, shorter run arm reach. `Player.get_skeleton()`, `get_visual_root()`, group `"player"`. Camera: invert Y and gamepad stick look via `InputRemap` | `CHARACTER_BASELINE_AUDIT.md`, `CHARACTER_RIGGING_REPORT.md`, `ANIMATION_INTEGRATION_REPORT.md`, `CHARACTER_PHYSICS_REPORT.md` |
| Wind & nature | `WindSystem.set_preset(Preset.CALM/BREEZE/MODERATE/STRONG/STORM/CAVE, blend, dir)`, turbulence/storm uniforms, `wind_changed` signal; rooted height-weighted tree sway, branch bend, leaf flutter; grass/bush/fern/vine variants; player push within 1.2 m; `systems/nature/FallingLeaves.gd`. Test bed `dev/nature/NatureTest.tscn` | `TREE_WIND_SYSTEM.md`, `FOLIAGE_ANIMATION_REPORT.md`, `ENVIRONMENT_INTERACTION_REPORT.md` |
| Controls | `systems/InputRemap.gd` autoload (`user://controls.cfg`), `ui/controls/ControlsMenu`: KB + gamepad rebinding, conflict swap/cancel, reset, sensitivity, invert Y, deadzone, hold/toggle, FOV. Opened from Pause → Controls and Main Menu → Settings → Controls | `CONTROLS_REPORT.md` |
| Customization | `systems/MaraAppearance.gd` autoload (`user://appearance.cfg`), `ui/customize/CustomizeScreen` from the main menu "CUSTOMIZE MARA": 3D preview, outfit palettes, skin/hair recolour by colour mask, hat/headlamp/backpack/satchel on bones, height 0.96–1.01 and build 0.94–1.06 | `CHARACTER_CUSTOMIZATION_REPORT.md` |
| Graphics | `GraphicsSettings` keys `foliage_density`, `foliage_wind_detail`, `leaf_particles`, `vegetation_interaction`, `character_ik_quality` plus `get_setting(key, default)`. Ch7 worst frame 628 → ~285 ms and Ch9 ~458 → ~290 ms (threaded `CaveBuilder`, spread-out collision in `EnvironmentCollision.gd`). Sweep: `dev/perf/preset_sweep.gd` | `PERFORMANCE_REPORT.md` |

The coordinator then wired a wind preset into every level: CAVE for the Prologue, Ch4, Ch6, Ch7, Ch9 and Ch10; BREEZE for Ch1, Ch5 and the Epilogue; MODERATE for Ch2 and Ch8; STRONG for Ch3; STORM for the Finale (4 s blend). These are the first line of each `levels/*.gd` `_ready()`, plus `Chapter1Dressing.gd:88` and `EpilogueVista.gd:45`.

QA on LOW before `7a23488`:

| Check | Result |
|---|---|
| Parse every script | 0 failures |
| Full campaign | PASS, 828.6 m |
| Story flow | PASS |
| `dev/movement_tests.gd` | 54/54 |
| `dev/character/character_tests.gd` | 27/27 |
| Controls test | 24/24 |
| `scripts/qa_foliage_wind.gd` | PASS (its calm→storm blend was lengthened from 1 s to 3 s) |

All presets 0–4 ran without a crash; Ultra hung once and the rerun was clean. No Tripo credits were spent.

**Warning: another tool works in this folder in parallel.** A separate session ("Antigravity Game Director"/Astra) edited files during this session: it wrote `docs/RECOVERY_AUDIT_2026-10-09.md` and `dev/run_recovery_test.ps1`, staged files, and made a `Player.gd` foot-planting edit that caused 2.5 m/s walk slide (reverted). After `7a23488` it added `ed023b1`, `68b4055`, `be45cd7` ("first commit") and `3bb8aed`, and **the checkout is now on `main`, not `wip/game-recovery`.** Before working, run `git status`, `git branch` and `git log`, and coordinate with the user so two tools don't edit at once.

## 5. Open work (priority order)

1. **Release blockers (user decisions):** the ElevenLabs free tier is non-commercial, so upgrade and regenerate the voices or replace them. Revoke and rotate the leaked keys.
2. **Ch7 is very dark:** do a lighting pass (Level A ownership).
3. **Animation:**
   - Not built: strafe, slide, ledge hang/shimmy, aim/fire/reload/melee poses, push. Each needs a gameplay state or new clips.
   - No finger bones, so the hands can't grip or point.
   - A 180° turn plays only about a quarter step, because the turn takes ~0.3 s. Slowing it changes the movement feel, so it's the user's call.
   - The landing dip is real but brief (~0.2 s).
4. **Visuals:**
   - White flecks on a Ch8 pillar.
   - Ch1 grass: the black-blade normal fix may have solved the flat look; check it.
   - The Ch6 camera spawns inside reeds.
   - Customization: hair recolour leaves brown speckle, the trousers barely recolour, and the accessories are blocky placeholders.
5. **Load spikes:** about 190–310 ms in the first two frames of every level, almost certainly first-draw shader compiles. It needs a shader warm-up during the loading fade.
6. **Untested:**
   - 1920x1080
   - a real gamepad (rebinding, stick look, customize screen)
   - the Ultra Low wind frames
   - the HUD help still shows default keys after rebinding
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
  | Wind & nature | `systems/nature/**`, `shaders/foliage_wind`/`grass_wind`/`wind_common`, `FoliageWind.gd`, `LBFoliageWind.gd` |
  | Controls | `systems/InputRemap.gd`, `ui/controls/**` |
  | Customization | `systems/MaraAppearance.gd`, `ui/customize/**` |
  | Graphics | `systems/GraphicsSettings.gd`, `CampaignEnvironmentArt.gd`, `dev/perf/**` |

  Never let two agents edit the same file.
- After every change, run on LOW, capture screenshots or frame sequences (`dev/seq_capture.gd`, `dev/ui_capture.gd`, `dev/levela_capture.gd`), look at them at full size, and fix whatever is visibly wrong.
- Commit on `wip/game-recovery` with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Scan for keys before committing.
