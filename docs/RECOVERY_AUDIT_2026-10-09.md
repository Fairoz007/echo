# ECHOES BENEATH recovery audit — 2026-10-09

Scope: existing working tree at `6053bbf`, Godot 4.7.2 Steam, RTX 2060 / driver 617.42. Existing source/assets retained. One Astra High task was used for Mara IK; routine inspection and fixes remained in the primary task. No generation API was invoked.

## Priorities and findings

| Priority | Area | Working | Broken or unfinished at inspection |
|---|---|---|---|
| P0 | Startup | Main menu, campaign infrastructure and original scripts exist | ControlsMenu inferred a float from a Dictionary Variant; MaraAppearance inferred a string from an untyped array. These prevented menu dependencies and an autoload from compiling. Fixed. |
| P0 | GPU stability | Compatibility/OpenGL is the default; D3D12 fallback disabled | Windows Application events confirm earlier Godot crashes, including `nvoglv64.dll` / `0xc0000409` on Oct 7 and a Godot access violation. No matching device-loss evidence in reviewed Ultra logs. Root cause remains unproven; a successful OpenGL run is not a universal crash fix. |
| P1 | Mara rig/animation | Existing 41-bone skinned LOD0 and eight clips are usable; root-motion stripping, locomotion, swim, climb and procedural layers exist | Source idle is asymmetric: L knee 160.39°, R 115.414°. Sole offset was omitted from planting thresholds, leaving R unplanted. One shared leg length also under-extended the longer leg. Fixed without regeneration. |
| P1 | Movement/collision | Terrain, stairs, landing, mantle and swim have runtime harnesses; Jolt collision filtering exists | New cave worker builds, staged dressing and collision cooking were uncommitted and needed fresh campaign verification. Individual hull cooking can still exceed the frame budget. |
| P1 | Controls | Two binding slots, conflicts/swaps, config persistence, deadzones, FOV and sensitivity implementation exist | Camera ignored invert-Y and right-stick look; toggle release could clear a held action. Fixed. Real controller behavior remains unverified; the HUD help still lists default keys after rebinding. |
| P1 | Graphics | Five presets, renderer feature guards, density/LOD/shadow controls exist | `leaf_particles` and `vegetation_interaction` were declared but ignored by their consumers. Fixed. `character_ik_quality` remains unused. Full tier-by-tier gameplay/performance acceptance is unfinished. |
| P2 | Trees/grass/leaves | Shared wind shader, gusts, branch deformation, flutter, rooted bases, player push, MultiMesh grass and GPU/CPU leaf paths exist | Branch motion is shader deformation, not articulated physical branch collision. Alpha-cut foliage is skipped by material conversion. Chapter-specific wind presets and outdoor leaf placement remain recommendations, not integrated campaign features. |
| P2 | Customization | SubViewport preview, existing rig, cosmetic config, swatches, body limits and four accessory toggles exist | Hue masks are approximate on the single atlas; recoloring can touch leather/gear and does not cleanly isolate all skin. Accessories can overlap. Cosmetic body changes do not resize gameplay collision. |
| P2 | Animation polish | Hand reach, climb/mantle contacts and hit recovery execute | Run/sprint leading hand reach and hit-reaction amplitude still fail existing checks. Slide, ledge shimmy and dedicated aim/reload/melee clips are absent; there are no finger bones. |

## Prior task recovery

The working tree contained 19 modified tracked files plus new controls, customization, character/nature/performance harnesses and reports. Those implementations were inspected and reused. No individual failed-agent transcript is stored in the project; logs are the evidence, not inferred agent status.

`dev/perf/logs/before_q1.log` recorded controls/customization parse failures, partially implemented Player methods, and repeated runtime errors. Medium/High/Ultra historical logs also recorded Chapter1 parse failures; the verbose Ultra log includes Jolt errors and resource leaks. Their FPS figures cannot establish that the current campaign is healthy. Reports claiming earlier success were treated as historical evidence only.

A leftover customization capture and a shell queue launching nature captures were stopped. The editor was retained. Subsequent tests use the existing directory lock, one test process, explicit OpenGL flags and bounded timeouts.

## Completed changes

- Explicitly typed both startup parse failures.
- Fixed a campaign-transition error: deferred appearance application now uses a weak skeleton reference and validates it after yielding, so temporary/replaced rigs can be freed safely.
- Fixed wind tracking of a valid-but-detached player during save/continue transitions; clears stale position/velocity before searching for the new player.
- Connected camera invert-Y and right-stick look; retained configured sensitivity/FOV.
- Retained toggle latches across physical release; verified second press releases them.
- Corrected sole-relative foot planting, per-leg lengths and idle pelvis alignment. Idle knee angle now 168.5°; feet 0/0 m; breathing 0.0074 m. Chest translation resets explicitly to avoid cumulative drift.
- Applied leaf and vegetation-interaction quality switches to runtime consumers.
- Made wind QA continuity time-step-aware, and checked live leaf/interaction switches across all five settings on OpenGL.
- Fixed a vector/boolean expression in the customization capture harness and isolated its campaign saves.
- Added `dev/run_recovery_test.ps1`: shared lock, timeout, error checks, optional required success marker and snapshot/restore of top-level game user data.

## Runtime evidence

| Check | Result |
|---|---|
| Script audit after startup fixes | `PARSE_DONE bad=0` (`recovery_parse_fixed.log`) |
| Rendered controls and camera | `CONTROLS_DONE fails=0`; save/reload, conflicts, toggles, FOV, normal/inverted mouse look (`recovery_controls.log`) |
| Rendered foliage QA | `FOLIAGE_WIND_PASS`; original PBR maps preserved, preset blend/signals and five-level leaf/interaction settings (`recovery_foliage.log`) |
| Rendered customization | Preview, orbit/zoom, tabs, cosmetic save/application and four accessories rendered in Chapter1; screenshots visually inspected (`recovery_customize.log`) |
| Rendered character | 24/27 pass; remaining failures: run/sprint reach ~0.40 m, hit flinch amplitude (`recovery_character_final.log`) |
| Rendered campaign | Segmented coverage: initial Prologue/Chapter1; corrected Chapters2–9; separate Chapters10–Finale **PASS**, 194.1 m / 116.3 s, through credits and Main Menu (`recovery_campaign_end.log`). The resumed run exited with code 0 during Chapter10 but without a success marker; its cause is unknown and it is not counted as a full pass. No uninterrupted clean full-campaign result is claimed. |

All rendered runs use Compatibility/OpenGL at 1280×720 window size, normally LOW. The small foliage QA changes settings live through all five tiers; it is not a five-tier campaign performance certification. Character checks validate measurements, not complete animation aesthetics. Gamepad look has code integration but no physical controller acceptance test.

## Save preservation incident and limits

The original customization capture unexpectedly autosaved slots 0/1. Their current saves were restored byte-for-byte from `.bak` and verified against pre-test SHA-256 hashes. Slot 99 was unchanged. However, the older `.bak` versions for slots 0/1 had already been replaced by that capture; those older backups could not be restored. The capture now writes to `user://qa_customize`, and the runner snapshots/restores existing top-level user files. Campaign QA uses its existing isolated directory. Cosmetic test edits were restored.

## Remaining work / blockers

1. Establish a reproducible GPU-crash trigger before changing renderer architecture or drivers. Forward+/Vulkan stability is not certified.
2. Repair the three remaining animation-polish checks; validate body extremes against foot IK and collision. Character LOD1–3 assets exist but player LOD selection is unfinished.
3. Integrate chapter wind presets/leaf placement; decide whether physical branch interaction is actually needed.
4. Complete real-gamepad, manual cistern-puzzle, camera-wall and long-duration acceptance; measure load spikes after the recovered asynchronous changes.
5. Previously documented dark Chapter7, Chapter8 flecks, voice licensing and historical credential exposure remain outside these fixes. No credential or licence change was performed.

Do not treat this recovery pass as release completion.
