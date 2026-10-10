# ECHOES BENEATH recovery audit — 2026-10-09

Follow-up: [2026-10-10 lighting/material refinement](LIGHTING_MATERIALS_2026-10-10.md) adds verified High/Ultra lighting balance and PBR preservation. It also records a fresh GPU-loss incident and the successful OpenGL checks after the GPU became available again; universal GPU stability is still unproven.

Scope: existing working tree at `6053bbf`, Godot 4.7.2 Steam, RTX 2060 / driver 617.42. Existing source/assets retained. One Astra High task was used for Mara IK; routine inspection and fixes remained in the primary task. No generation API was invoked.

## Latest status after integration at `7a23488`

The original inspection and intermediate results below are historical. The shared integration commit now includes the idle IK fixes, preserved elbow bend with bounded run/sprint arm reach, stronger hit reaction, mantle hand targeting, chapter wind presets and asynchronous environment/collision builds. Existing Mara assets remain usable; no replacement model or clips were generated.

The integration commit/report records character **27/27**, movement **54/54**, controls **24/24** and a full campaign route pass. Those are the integrating agent's results, not additional runs by this continuation. The stored five-preset performance logs cover six scenes each on OpenGL; they do not certify every chapter, long sessions or Forward+/Vulkan. Ultra also had an earlier timeout before a successful rerun.

This continuation independently ran the rendered turn/climb subset on Godot 4.7.2, Compatibility/OpenGL, Low: **7 checks, 0 failures** (`rig_turn_baseline.log`). The turn check now measures actual foot movement after subtracting character translation instead of accepting an internal gait-blend value: **0.187 m displacement, 0.053 m lift, 5 samples below 1 m/s**. Climb hand contact averaged **0.003 m** over 104 samples; mantle best contact gap was **0.000 m**. Best mantle contact does not prove continuous contact throughout the motion. No additional Player changes were needed after this result.

Current priorities:

1. **P0 GPU stability:** historical crashes remain unexplained; keep Compatibility as the verified path. Initial load/render spikes and the Ultra timeout still warrant investigation.
2. **P1 rig acceptance:** turn stepping works but only plays a short partial cycle; body-size extremes/collision, sustained mantle contact and real controller acceptance remain unverified. Character LOD selection and the IK-quality setting remain unfinished.
3. **P2 visual polish:** recolor masks/accessory overlaps, campaign leaf placement and manual foliage acceptance remain. Branch sway is shader deformation. The 41-bone rig has no fingers; slide, ledge shimmy and dedicated combat poses are absent.

The earlier save-backup incident is documented below. Subsequent test runs use current-data snapshot/restore; this continuation did not intentionally change campaign progression or save formats.

## Priorities and findings at initial inspection

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

## Intermediate recovery runtime evidence (before final integration)

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

## Initial remaining work / blockers (superseded by latest status above)

1. Establish a reproducible GPU-crash trigger before changing renderer architecture or drivers. Forward+/Vulkan stability is not certified.
2. Repair the three remaining animation-polish checks; validate body extremes against foot IK and collision. Character LOD1–3 assets exist but player LOD selection is unfinished.
3. Integrate chapter wind presets/leaf placement; decide whether physical branch interaction is actually needed.
4. Complete real-gamepad, manual cistern-puzzle, camera-wall and long-duration acceptance; measure load spikes after the recovered asynchronous changes.
5. Previously documented dark Chapter7, Chapter8 flecks, voice licensing and historical credential exposure remain outside these fixes. No credential or licence change was performed.

Do not treat this recovery pass as release completion.
