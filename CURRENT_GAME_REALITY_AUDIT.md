# Current game reality audit: ECHOES BENEATH

Date: 2026-10-07/08. Engine: Godot 4.7.2 (Steam build). GPU: NVIDIA RTX 2060, driver 617.42.
Test configuration (user's hard rule): `--rendering-method gl_compatibility --rendering-driver opengl3`, 1280x720 window, ULTRA LOW / LOW presets only.
Older reports in the repo that say "production ready" were not used as evidence. Everything below comes from the runs listed here.

## How it was tested
| Script | What it does | Evidence |
|---|---|---|
| `scripts/qa_reality_audit.gd` | Opens the real main menu. Clicks Settings, Credits and New Game with simulated mouse events. Plays the Prologue and the start of Chapter 1 with simulated key events only (W/Shift/Space/E/J/Esc/F5/F9). Strafes with A/D when stuck. Uses no teleports and no direct gameplay calls. Captures frame sequences. | `screenshots/reality_audit/low_play/` |
| `scripts/qa_story_flow.gd` | Harness test, not a playthrough. Story cards, death followed by Restart checkpoint, persistence across chapter transitions, save, quit to menu and Continue, Finale/Epilogue/credits cards. | `screenshots/reality_audit/flow/` |
| `qa_reality_audit.gd --skip-play --levels=...` | Loads each level directly to take a screenshot and measure FPS. These are **scene-load captures, not playthroughs.** | `screenshots/reality_audit/perf_preset0/`, `perf_preset1/`, `gl_default/sceneload_*` |

Note: other agents were editing Player.gd, the levels and the environment scripts while these runs happened. Some runs hit their files in a half-edited state. Those cases are marked below.

## Natural playthrough result (LOW, simulated input)
- Main menu: loads. New Game shows the Prologue story card, then the Prologue (`t00_card_prologue_b.png`, `p01_prologue_opening.png`).
- Movement works. Forward speed is 3.6 m/s, sprint is 5.6 m/s and jump leaves the floor (`p03_run_seq_*`, `p04_sprint_seq_*`, `p05_jump_seq_*`).
- Pressing E at the relic completes `obj_prologue_explore`.
- **Mara gets stuck on the relic pedestal/fern at z = -11.2** and cannot move forward until she strafes (`p06_artifact_prompt.png`, `p07_walk_*`). A player holding W is blocked.
- After strafing, she reaches the portal and the Chapter 1 card appears. Chapter 1 then loads (`t01_card_chapter1_b.png`, `c01_opening.png`).
- In Chapter 1: J opens the Field Journal, F5 saves, and F9 restores the saved position exactly (distance 0.00). Pause, then Main menu, returns to the menu, and Continue is enabled.
- `qa_story_flow.gd` passed 17/17 checks before another agent's `LevelCave.gd` parse error broke `Finale.tscn`. In the last run, Finale and Epilogue failed to load because of that error.

## Defects

### P0 (blocks play or crashes)
1. ~~**Finale.tscn fails to load.**~~ **RESOLVED 2026-10-08:** LevelCave.gd compiles again, and qa_story_flow.gd now passes 17/17 from New Game through Prologue, death/restart, Chapter 5, save/Continue, Finale, Epilogue and the credits card. Original issue: `systems/environment/LevelCave.gd` has a parse error (`Cannot infer the type of "z"`), and `Finale.tscn:121` fails to parse as a result. The campaign cannot reach the ending while this is broken. Owner: environment/levels agent. The transition screen now refuses to change to a null scene instead of throwing an engine error.
2. **Prologue critical path blocked.** Re-test 2026-10-08: the Prologue now generates 11 collision bodies (it was 48), and the block moved to z ≈ -16.1. It took about 20 alternating strafes before forward input got through (low_play/ run log). The relic pedestal/fern collision sits in the middle of the tunnel. Forward input stops at 0 m/s, and only strafing gets past it. Owner: levels/collision.
3. Intermittent parse errors in shared files while agents edit them: `Player.gd` (`WaterBody` not declared), `Prologue.gd` (`AudioBuses`/`ReverbZone` not declared because the class cache had not refreshed), and `LevelCave.gd`. When this happens New Game spawns no player, or a plain CharacterBody3D, and HUD.gd:108 spams 9,000+ errors about `is_aiming`. Every shared script needs a final compile pass once editing stops.

### P1 (major quality problems)
4. **Chapters 2–10 are mostly empty, dark, foggy flat planes.** They contain a few floating rock slabs, and there is no readable path or landmark (`gl_default/sceneload_02..10*.png`).
5. **Finale renders as a grey void**, with a default environment and no geometry (`gl_default/sceneload_11_Finale.png`).
6. **Mara's T-pose in Chapter 3** (`gl_default/sceneload_03_Chapter3.png`).
7. **Mara's animation state is missing.** In the latest runs the AnimationPlayer reports an empty `current_animation` during idle, run and jump. In an earlier run sprint used the `walk` animation and jump used `idle`. No dedicated run or jump clips were observed.
8. **Chapter 1 ground** looks wrong: large hard-edged shadow blobs on low-poly sand bumps, and a flat untextured sky (`low_play/c01_wind_seq_f00.png`).
9. **Foliage wind is not visible in Chapter 1 at LOW.** The frame-to-frame pixel delta is 0.01–0.06 with a static camera (`low_play/c01_wind_seq_*`). For comparison, the idle sequence in the Prologue changes by 2.7–4.8 because of mist and water. Either the wind effect is disabled at the LOW tier or it is too subtle to see.
10. **FIXED:** ui/JournalScreen.gd adds Journal, Inventory and Skills tabs. J opens it in every level, including the Prologue (low_play/m05_journal_prologue.png, m07_inventory_chapter1.png, m08_skills_chapter1.png). Original issue: no inventory or skills screen existed, even though SkillManager tracks XP and points. In the Prologue, J (advertised on the HUD) does nothing because CampaignExploration is not attached there (`low_play/m05_journal_prologue.png`).

### P2 (noticeable problems)
11. **FALSE ALARM (retracted):** the source files are valid UTF-8 (byte check: E2 80 94 / E2 80 A2). The garbled characters came only from PowerShell's console decoding. In-game screenshots render the em dash and bullet correctly. Original claim: `Epilogue.gd` shows "â€”" and "â€¢", `CampaignExploration.gd` shows "FIELD JOURNAL â€¢", and `MainMenu.gd` credits shows "â€”". Source files were saved with a double encoding.
12. Many dialogue IDs have no recorded audio and fall back to subtitles only, e.g. PRO_MARA_001/002, FIN_*, EPI_*, C05_*. AUDIO_REPORT.md says the manifest was regenerated afterwards, so this needs re-checking.
13. Jolt warns about non-uniform scale on generated `AutoCollision` bodies (around 11–17x scale), and collision is approximated as a result.
14. 2–33 ObjectDB instances leak at exit on every run.
15. **FIXED:** ui/GameTheme.gd styles Settings, Credits, Pause and Journal with dark panels and a brass accent (low_play/m02_settings.png). Original issue: the Settings window was a plain grey OS-style popup with a lot of empty space (`low_play/m02_settings.png`). It works, but it is not styled like the rest of the game.
16. The field journal is a plain grey panel (`low_play/m06_journal_chapter1.png`).

### P3 (polish)
17. The art on the transition card is a procedural strata/mist shader, not chapter key art.
18. The Prologue is very short, about 25 m of tunnel. It can be finished in about 10 seconds.

## Crash investigation (D3D12)
- These runs happened **before** the user's hardware rule was received, on 2026-10-07: Prologue for 600 frames, plus a full 13-level scene-load sweep on Forward+ D3D12 and Forward+ Vulkan at the old High preset. **No crash reproduced.** D3D12 showed a 1.5 s hitch on loading Chapter 3 (shader compilation) and leaked RIDs at exit. Logs are in the session scratchpad, and screenshots are in `screenshots/reality_audit/fwd_d3d12/` and `fwd_vulkan/`.
- The user reports that their GPU crashes at high settings. Per that rule, no further Forward+/D3D12/Vulkan runs were done.
- Fix: `project.godot` now defaults to `gl_compatibility` + `opengl3`, with ANGLE fallback. It also sets a 1280x720 window override and a 2048 directional shadow atlas, and `GraphicsSettings.DEFAULT_LEVEL = 1` (LOW). If a Forward+ renderer is ever chosen, the RD driver is set to Vulkan with fallback to OpenGL3. `build/windows/SafeGraphics.cmd` forces Compatibility and ULTRA LOW. The exported .exe in `build/windows/` is from 19:31 and **has not been re-exported** with these changes.

## Not verified
- Medium, High and Ultra presets on this machine (hardware rule).
- Whether the recap narration is audible on the transition card. Code paths ran without errors, but nobody listened to the output and no screenshot was taken during a recap cue.
- A full natural playthrough beyond the start of Chapter 1.
- Audio mix levels after the gain changes (not checked by ear).
- The exported build.
