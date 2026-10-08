# ECHOES BENEATH production audit — 2026-10-07

Decision: DO NOT SHIP. This is a substantial development build, not acceptance of the requested finished ten-hour game.

Engine: existing Godot 4.7.2 Steam project, Jolt physics. Graphics now default to OpenGL Compatibility after repeated D3D12 allocation/device failures on RTX 2060. This is a backend workaround; the driver fault is not certified fixed. The supplied production directive specifies Godot and preservation of the existing project. Tripo GLBs are also compatible with Unity, but no Unity migration was performed. Pre-existing working-tree changes were preserved; no release tag was created.

## Implemented

- Chapters 1–10, Prologue, Finale and Epilogue now use imported Mara artwork and campaign voice/subtitle integration. Level ordering gates, repeated transitions, overlapping interactions, Chapter 5 observation, Chapter 10 unique resonance nodes, and Prologue/Chapter 1 restored exits were repaired.

- Sidearm aiming/fire, ammunition, reload, cover-blocked hit rays, melee, stealth detection and noise/search behavior added. Enemy attacks respect cover. Swimming, diving, oxygen and drowning are connected to the Drowned Temple; a physical exit ramp connects its drained basin to the sanctum.

- Pause menu, manual save/load, chapter autosaves, separate restart checkpoints and death recovery implemented. Snapshots include player vitals/ammunition, missions, defeated enemies, mechanism state, unique nodes and persistent archaeology state. Movement/tween/transition saves are blocked to prevent incomplete mechanism restoration.

- Thirty optional archaeology chambers (three per chapter) use Tripo cave geometry, original inscriptions, three-dial puzzles, journal entries and persistent one-time rewards. These are similar small puzzles and are not evidence of ten hours of varied gameplay.

- Actual Tripo generation delivered fourteen new models: three cave modules, six supporting characters, sidearm, climbing pick, jungle tree, fern and archaeological survey desk/map. Six legacy character rigs and looping idle clips are selected in the runtime. Generated character gallery and cave/jungle walking captures were inspected. Remaining environmental primitives and repeated modular art still require replacement/polish.

- Original 68-line screenplay and 68 generated voice recordings (289.831 seconds), eleven ambience loops and 26 effects/Foley integrated: 105 runtime WAVs. Radio treatment, subtitles, ambience, terrain-family footsteps and combat/collapse events are connected. No music tracks were generated.

- Mara walk root drift was removed in a per-instance animation copy. Character facing, Prologue cave coverage and Chapter 1 white floor/cliff/missing sky were repaired. UI now displays weapon/oxygen state and controls.

- Windows development export exists at build/windows/EchoesBeneath.exe. Embedded resources; version 0.2.1; unsigned. Export omits generation scripts, credentials, source ledgers, QA scripts and reports. Final export completed with exit 0 and zero engine errors.

## Verification

Current scoped suites: runtime smoke 4/4, focused QA 12/12, and clean boot/teardown of all fourteen scenes. Focused checks cover checkpoints/death, ammunition/hit rays/cover/reload, swimming/diving/breath loss, audio references, archaeology puzzle/reward persistence, HUD timers, chapter mapping and save restoration. These checks are narrower than campaign acceptance.

Compatibility Low completed New Game through credits and back to Main Menu: exit 0, zero engine errors, 816.1 m and 264.6 seconds route time plus ending/teardown waits. This coordinate-guided scripted route proves progression, not human playtime. Final Chapter 6 physical scope also passed (61.4 m / 25.0 seconds), with real dive/drowning/recovery and zero swimming-state transitions during the drainage fixture. Failed headless aiming, scaled synthetic motion, detached scene changes, D3D12 crashes and corrupt/interrupted logs were retained; they were not counted as passes. The native Windows executable started under OpenGL Compatibility with exit 0 and zero errors. The exported resource bundle passed New Game, autosave, Main Menu and Continue checks with exit 0 and zero errors; this bundle test used the editor host and is not a native executable full-campaign playtest. Preserve docs/campaign_physical_latest.log, docs/focused_qa_latest.log and docs/campaign_scene_boot_latest.log as the detailed evidence.

Rendered captures: screenshots/production_character_gallery.png, screenshots/prologue_asset_transform_final_cave_walk.png and screenshots/prologue_asset_transform_repaired_jungle_walk.png. A historical D3D12 rendered stationary probe sampled three seconds after two seconds warmup in chapters 0–11 on RTX 2060 / D3D12 Forward+. Chapter 1 averaged 92.5 FPS with minimum 89; other scene averages were 211–240 FPS. The probe ran alongside the editor and rendered route, using the engine FPS monitor; this is not navigation stress, CPU/GPU/VRAM profiling or endurance acceptance. Single-frame asset captures are narrower evidence. Repeated cliff silhouettes, sediment texture scale and remaining primitive props are visible limitations.

## Low-GPU graphics and nature update

Low uses a 960x540 window and 30 FPS, no antialiasing/shadows/screen effects, aggressive mesh LOD and one third of the plants. Low disables fullscreen to prevent native resolution increasing GPU load. Balanced and High restore detail and cap at 60 FPS. Settings preserve existing audio/display preferences. SafeGraphics.cmd forces Low and OpenGL Compatibility. Physical mouse sensitivity and reticle resizing are corrected for window scaling.

Water geometry has 162 / 1250 / 8450 triangles across Low / Balanced / High, animated waves and normal ripples, and follows the real reservoir height. Swimming follows surface velocity; separate entry/exit depths and shallow-ground recovery prevent repeated state switching. Added temple lights and replaced the box gate with Tripo stone artwork. Foliage wind preserves imported PBR maps and is disabled in Low. Ground uses one MultiMesh with 42 / 270 / 480 pieces; smaller tiles improve scale at greater cost. The white survey-table placeholder is replaced by a generated desk/map.

All three quality modes compiled/rendered water, foliage and ground shaders with exit 0 and no engine errors. Short capped snapshots: Low 30 FPS; higher modes 56-60 FPS on RTX 2060. These are not endurance or worst-case benchmarks. Static-camera water-region frames differ over time, corroborating ripple motion. Evidence: docs/graphics_visual_latest.log, docs/graphics_water_final.log, docs/water_wave_image_difference.json. Staged screenshots are not progression tests. A weaker physical GPU was unavailable; reduced settings on RTX 2060 are not testing another GPU. No ultra-realism or crash-free operation on every GPU is certified.

## Required work before release

- The requested ten-hour duration has not been delivered or measured. Main-route scenes are compact; thirty similar chambers do not establish ten hours. More varied authored exploration, traversal, encounters and puzzles, plus timed human playtests, are required.

- Full Mara traversal/run/jump/swim/combat/damage/death animation set, enemy locomotion/combat presentation, grip alignment, character/environment optimization and LOD coverage remain incomplete.

- Ultra-realistic graphics have not been achieved. Sparse spaces, repeated modular patterns and remaining props require final art. Final art across every chapter, navigation/pathfinding encounter design, sustained performance/memory profiling, accessibility, controller support, final UI and extended save/campaign testing remain incomplete.

- Human listening/mix acceptance is pending. ElevenLabs account reports free tier; generated audio is marked noncommercial prototype pending applicable commercial rights. Music and a complete cinematic mix are absent.

- A continuous scripted route is technical progression evidence, not a human full-campaign acceptance test. Exported full-campaign/audio/credits acceptance, installer/signing and clean-machine testing are required.

## Generation and credential accounting

New Tripo spend: 920 credits (560 models, 300 rigs, 60 successful idle retargets); seven failed v2.5 retarget requests cost zero. All jobs are terminal. Final balances 0 / 60 / 100; none frozen. ElevenLabs latest usage 6412 / 10000 characters. No subscription purchase was made.

Credentials load from environment or Windows user-bound encrypted storage outside the repository. They are excluded from the game. Previously exposed credentials also existed in Git history; rotation remains advisable. No history rewrite was performed.

Final package evidence: docs/windows_export_latest.log, docs/windows_executable_final.log and docs/windows_package_checkpoint_latest.log. Build integrity is recorded in build/windows/build_manifest.json.

See ASSET_REGISTRY.md, COMPLETE_SCREENPLAY.md, FINAL_AUDIO_PRODUCTION_REPORT.md and the technical QA report for deliverables and outstanding acceptance gates. Do not distribute this development build as a finished production release.
