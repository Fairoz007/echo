# Tripo Delivery Report — Echoes Beneath (2026-10-07)

Agent: Tripo3D asset generation & delivery. No git commits made. No keys printed or written.

## 1. Credits

| Key slot | Before | After | Spent | Notes |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | Empty. Owns the original Mara rig task (8e0c7b78-…), so Mara's rig cannot be retargeted from another account (HTTP 404 — tasks are account-scoped). |
| 2 | 60 | 30 | 30 | 3 enemy retargets on Meridian legacy rig |
| 3 | 100 | 50 | 50 | 5 locomotion retargets on Nadiya legacy rig |
| **Total** | **160** | **80** | **80** | 10 credits per `animate_retarget`; 25 per rig; 40 per textured text_to_model (measured from task records) |

80 credits deliberately held in reserve (see section 6).

**Security note:** older Tripo keys exist in git history (`API_CAPABILITY_MATRIX.md`, `scripts/tripo_client.py` in earlier commits). History was not rewritten; those keys should be revoked/rotated in the Tripo dashboard if not already.

## 2. Key finding: one shared skeleton

Mara, Elias, Nadiya, Tomas, Adrian, Drake and the Meridian base (legacy rigs) all use the **identical 41-bone Tripo legacy biped skeleton** (Root, Hip, Pelvis, L/R_Thigh/Calf/Foot/ToeBase, twist bones, Waist, Spine01/02, NeckTwist01/02, Head, L/R_Clavicle/Upperarm/Forearm/Hand). Joint names match exactly, **bind poses do not** (Mara is T-pose, NPCs A-pose; up to 160° difference at hands). So instead of paying for each clip per character, clips were generated once on funded rigs and retargeted locally with a new world-space retargeter (`scripts/generate_retargeted_library.py`, 0 credits; self-retarget error 5e-14°, visually checked in Blender renders).

## 3. Job log

| # | Job | Rig source (key) | Task id | Result |
|---|---|---|---|---|
| 1-5 | preset:run/jump/climb/fall/dive on Mara rig 8e0c7b78 | key 2 | none | REJECTED by API (HTTP 404: rig owned by key 1). 0 credits. |
| 6 | preset:run | Nadiya legacy 1adccc7d (3) | 93cb830e-f98f-432d-91ce-6660cc69307f | ACCEPTED (1.27 s loop, 22 animated bones) |
| 7 | preset:jump | Nadiya (3) | cfa97576-fb9a-47f0-a86c-ed5e4ab61fcc | ACCEPTED (2.23 s) |
| 8 | preset:climb | Nadiya (3) | f0513c8f-038b-4eb3-ac9c-21247ccebd36 | ACCEPTED (3.47 s) |
| 9 | preset:fall | Nadiya (3) | c3f115eb-6934-446c-a4ba-68df58f43761 | ACCEPTED (3.03 s) |
| 10 | preset:dive (swim-entry stand-in) | Nadiya (3) | 35d29af8-03a9-47d8-9be4-ae9d321a0d18 | ACCEPTED (2.73 s) |
| 11 | preset:shoot | Meridian legacy dcf78562 (2) | d94b9b2c-c386-4374-b317-28ac071eb4d6 | ACCEPTED with caveat: 9 s clip containing a crouched segment — trim in engine |
| 12 | preset:hurt | Meridian (2) | 04524c26-a2fa-47ee-8559-17f523b97b7c | ACCEPTED with caveat: 13.9 s — use a sub-range |
| 13 | preset:slash (melee) | Meridian (2) | 8da2448f-353b-4946-b753-93d00890bebd | ACCEPTED (6.6 s) |

Raw clip GLBs: `assets/characters/mara/animations/anim_{run,jump,climb,fall,dive}.glb`, `assets/characters/meridian/animations/anim_{shoot,hurt,slash}.glb`; log in `assets/characters/mara/animations/retarget_jobs.json`.

## 4. Mara verdict — KEEP (IMPLEMENTED, TESTED offline)

- Appearance (from `screenshots/prologue_asset_transform_final_jungle_walk.png`): olive field shirt, dark trousers, hiking boots, backpack, utility belt/pouch, ponytail, natural proportions, no armor. Matches brief; no regeneration needed.
- Problems found: 267,420 triangles (far too heavy); only `idle` + `walk` clips; a stray 80-tri `Icosphere` mesh is in the source and survives into all exports (hide it or delete the node on integration).
- Rig: 41-bone humanoid biped, usable. Now has **idle, walk, run, jump, climb, fall, dive**. **Missing: sprint** (use `run` at 1.3–1.4x speed scale), **crouch / crouch-walk** (no Tripo preset; recommend procedural: lower Hip track + additive spine bend, or Mixamo-style clip later), **swim** (no preset; `dive` + a procedural flutter on legs is a stop-gap). Status of those: NOT STARTED (no credit-based path exists).

## 5. Hand-off table (for integration agents)

All characters: glTF units, model ~1.0 tall → existing `VisualRoot` scale 1.7 in `scenes/Player.tscn` still applies; Mara needs the existing Y rotation of +90°. Recommended collision: CapsuleShape3D on the CharacterBody (as now), never mesh collision. Skeleton: `Skeleton3D` with the 41 bones above; AnimationPlayer clip names exactly as listed.

| Asset | Path | Tris | Clips | Status |
|---|---|---|---|---|
| Mara game LOD0 (replace CHR_Mara_Production) | `assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb` | 59,999 | climb, dive, fall, idle, jump, run, swim, walk | TESTED (Blender render) |
| Mara LOD1/2/3 | `.../CHR_Mara_Game_LOD1.glb` / `LOD2` / `LOD3` | 29,998 / 12,000 / 5,000 | same | TESTED |
| Mara full-res + all clips | `.../CHR_Mara_Locomotion.glb` | 267,420 | same | IMPLEMENTED (cinematics only) |
| Elias / Nadiya / Tomas / Adrian / Drake | `assets/characters/<name>/source/CHR_<Name>_Animated.glb` | 18.3k–18.7k | idle, walk | TESTED (Elias render) |
| Meridian mercenary base | `assets/characters/meridian/base/source/CHR_Meridian_Animated.glb` | 18,738 | idle, walk, run, shoot, hurt, slash | TESTED (render); shoot/hurt need sub-range trimming |

Notes for integrators:
- Mara LODs were re-exported by Blender: textures are 2048 JPEG; node path to AnimationPlayer may differ from `CHR_Mara_Production` — re-check `Player.gd` animation lookups (it should search for AnimationPlayer recursively). Loop mode: set `idle, walk, run, climb` to loop in the .import Advanced settings; `jump, fall, dive` one-shot.
- NPCs have no "talk" preset on Tripo. Recommended: play `idle` and add a procedural head nod / Spine02 sway and hand gesture (bones `Head`, `NeckTwist02`, `R_Forearm`) while dialogue audio plays.
- Meridian variation: one mesh; vary via material overrides (albedo tint on fabric, darker vest), not new models.
- NPC meshes at ~18.7k tris do not need manual LODs; keep `meshes/generate_lods=true` on import.

### Environment LODs (IMPLEMENTED, spot-TESTED)
Every `assets/models/*.glb` was ~500k triangles (explains the 3.9M primitive Chapter1 capture). Decimated variants with 1024 textures in `assets/models/optimized/<name>_LOD{0..3}.glb`:

| Category | Assets | LOD0 / LOD1 / LOD2 / LOD3 tris | Collision |
|---|---|---|---|
| Large architecture / env | arch_bridge_span, arch_floor_stone, arch_glass_barrier, arch_wall_vaelor, env_boulder_moss, env_stalagmite_cluster, prop_expedition_tent, prop_vaelor_turbine_wheel, ruin_arch_portal, ruin_pillar_vaelor | 24k / 10k / 4k / 1.5k | Box/convex for walls, floor, pillar, barrier, tent; trimesh from **LOD3** for bridge span and arch portal; convex for boulder/stalagmites |
| Props | prop_expedition_radio_station, prop_meridian_crate, prop_vaelor_key | 8k / 3k / 1.2k / 400 | Box (crate, radio); none/sphere trigger for key |

Total size 215 MB → 28 MB. Visual comparison (pillar, wall: original vs LOD0 vs LOD2/3) shows LOD0 indistinguishable at gameplay distance. Swap level instances to `_LOD0` and either use `visibility_range` with LOD1–3 siblings or rely on Godot's auto mesh LOD (then LOD0 alone suffices). Original scale/orientation is preserved, so existing transforms apply unchanged.

## 6. Not generated (and why)
- New environment/Vaelor assets: registry already contains stalagmite cluster, boulder, ruin portal/pillar, Vaelor wall/floor/key/turbine, cave wall/floor/ceiling. The bottleneck was performance, not missing assets. 80 credits remain (key 2: 30, key 3: 50) — enough for one 40-credit hero piece (e.g. Heart Vault geode centerpiece) on key 3 or 3 more retargets. Decision left to the director. Status: NOT STARTED.
- Sprint/crouch/swim clips: no Tripo preset. NOT STARTED.

## 7. Scripts
- `scripts/generate_mara_animations.py` — retarget submission on funded rigs, no key failover (account-scoped tasks), bounded polling, JSON log.
- `scripts/generate_retargeted_library.py` — local cross-bind-pose retarget; appends clips to a target GLB.
- `scripts/generate_lods_blender.py` — Blender 5.1 CLI decimation + texture cap, keeps skin/animations.

---

# Phase 2 — expanded budget (2026-10-07/08)

## Credits (9 keys)
| Key | Start of phase 2 | Now | Spent | Use |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | — |
| 2 | 30 | 30 | 0 | preset probes on the Meridian rig (invalid presets are free) |
| 3 | 50 | 40 | 10 | swim clip 33df212d-8526-4d03-97d3-17546a176302 |
| 4 | 600 | 0 | 600 | hero assets |
| 5 | 600 | 0 | 600 | hero assets |
| 6 | 600 | 0 | 600 | hero assets |
| 7 (reserve) | 600 | 0 | 600 | hero assets |
| 8 (reserve) | 600 | 240 | 360 | hero assets |
| 9 (reserve) | 600 | 600 | 0 | untouched |
| **Total** | 3680 | 910 | 2770 | 69 text_to_model × 40 credits (65 accepted + 4 rejected v1) + 1 retarget |

Policy deviation (honest): during the first wave the slot picker needed 50 credits, so it moved on to reserve key 7/8 while keys 4–6 each still held 40. That balance was then used for 3 of the 4 regenerations, so keys 4–6 are now empty; net reserve use is the same as if 4–6 had been drained first, minus one job.

## Animation presets (verified against the live API on the legacy rig)
Valid: idle, walk, run, jump, climb, fall, dive, slash, shoot, hurt, turn, **swim**. Rejected as "invalid animation name" (0 credits): sprint, crouch, crouching, sneak, crawl, squat, kneel, stealth, reload, cover, aim, throw, die, dying, dead, death, knockdown.
- **Mara swim: IMPLEMENTED, TESTED** (Blender render). Retargeted into `CHR_Mara_Locomotion.glb` and the rebuilt `CHR_Mara_Game_LOD0..3.glb`. Clips now: climb, dive, fall, idle, jump, run, swim, walk.
- **Sprint / crouch: BLOCKED (no Tripo preset).** Use run at 1.35x for sprint; crouch must be procedural (Hip translation down about 0.35 of hip height + Spine01/02 forward bend) or come from an external mocap library.
- **Meridian reload / take cover / death: BLOCKED (no Tripo preset).** Use a ragdoll (PhysicalBoneSimulator3D) for death, a crouched sub-range of `shoot` (around 2–5 s) as cover-fire, and a procedural arm offset for reload.

## Hero / environment generation — 65 assets, IMPLEMENTED + visually TESTED
Generator: `scripts/generate_hero_assets.py` (records in `assets/production/hero_jobs.json`, with prompts, task ids and key slots). Model P1-20260311, PBR textured; the API caps `face_limit` at 20k for this model, so every LOD0 is ≤20k tris.
Every output was rendered in Blender (contact sheets) before acceptance.

Rejected and regenerated (v1 moved out of the project; records keep `*_REJECTED_V1`):
| Asset | v1 problem | v2 |
|---|---|---|
| CH7_LANDMARK_TOWER | squat cone, not a tower | accepted: slender tiered spire |
| CH4_LIGHT_TOWER | crane/gun-like boom | accepted: vertical mast + flood panels on trailer |
| CH6_HYDRAULIC_WHEEL | read as a tyre | accepted: spoked waterwheel with buckets on stone piers |
| CH3_PYLON_BROKEN_A | not visibly broken | accepted: snapped column with fracture |

Known art caveats (accepted, still usable): jun_boulder_cluster_mossy_a has lumpy bump noise; ch9_heart_road_gatehouse is chunky; foliage is opaque mesh (no alpha cards), so it reads well at mid range but needs a wind shader from the shaders agent.

LODs: `<folder>/lod/<name>_LOD0..3.glb` = ≤20k / 8k / 3k / 1k tris. Hero textures are capped at 2048; jungle, cave and Meridian at 1024. Native Tripo scale is normalized to about 1 unit on the longest axis, so **apply the suggested uniform scale** (derived from the size in the prompt). Pivot is at the bounding-box centre/bottom as Tripo exports it; verify ground contact on placement.

Meridian gear (helmet, rifle, heavy vest, radio pack) are attachments for BoneAttachment3D on `Head`, `R_Hand` and `Spine02` of `CHR_Meridian_Animated.glb`. Combine them with material tints to make the variants (rifleman / heavy / radio operator) from one base.

## Hand-off table (phase 2)
| Asset ID | Target level | LOD0 path (LOD1-3 alongside in `lod/`) | LOD0 tris | Native bbox XYZ (units) | Target size | Suggested uniform scale | Collision | Task id |
|---|---|---|---|---|---|---|---|---|
| CH1_SEALED_PORTAL | Chapter1 | `assets/models/hero/ch1/lod/ch1_first_sealed_portal_LOD0.glb` | 19032 | 0.69 x 0.97 x 1.00 | 6 m tall | 6.18 | trimesh(LOD3) frame + box door | 30cc7031-aaaa-48c9-b1ef-075203d77a03 |
| CH1_EXPEDITION_CAMP_HUB | Chapter1 | `assets/models/hero/ch1/lod/ch1_expedition_command_tent_LOD0.glb` | 16947 | 0.99 x 0.39 x 1.00 | see prompt | match neighbours | box | c0922387-0ff8-4f86-8ded-e790a2d85951 |
| CH1_SUPPLY_TRUCK | Chapter1 | `assets/models/hero/ch1/lod/ch1_expedition_supply_truck_LOD0.glb` | 17559 | 0.53 x 0.63 x 1.00 | see prompt | match neighbours | convex | 460f9a1c-10bd-4294-aa59-0ef3abb51b50 |
| CH2_COUNTERWEIGHT | Chapter2 | `assets/models/hero/ch2/lod/ch2_hydraulic_counterweight_machine_LOD0.glb` | 18127 | 0.56 x 0.85 x 1.00 | 5 m tall | 5.86 | convex parts; animate weight node | 0e10ad17-c052-4b98-85d4-967bdcf32665 |
| CH2_INSCRIBED_GATE | Chapter2 | `assets/models/hero/ch2/lod/ch2_inscribed_vaelor_gate_LOD0.glb` | 19118 | 0.43 x 1.00 x 0.89 | 5 m tall | 5.01 | box per door + trimesh(LOD3) frame | 77248afa-edcf-4560-a30d-d174774ffb73 |
| CH2_VOICE_TABLETS | Chapter2 | `assets/models/hero/ch2/lod/ch2_voice_below_tablet_wall_LOD0.glb` | 18395 | 0.53 x 0.99 x 1.00 | see prompt | match neighbours | box | 839c6332-e342-46e1-a384-716f313c721f |
| CH2_WATER_CISTERN | Chapter2 | `assets/models/hero/ch2/lod/ch2_hydraulic_cistern_valve_LOD0.glb` | 17555 | 1.00 x 0.70 x 0.99 | see prompt | match neighbours | convex; valve wheel separate interact | 84130d39-5f79-4c77-8b50-4e8281992308 |
| CH3_BRIDGE_SECTION | Chapter3 | `assets/models/hero/ch3/lod/ch3_massive_bridge_section_LOD0.glb` | 17407 | 1.00 x 0.47 x 0.55 | 20 m long | 20.04 | trimesh(LOD2) for walkable deck | 51e6d6be-b1e7-401e-8ef0-a97a538cec37 |
| CH3_PYLON_BROKEN_A | Chapter3 | `assets/models/hero/ch3/lod/ch3_broken_pylon_a_LOD0.glb` | 18301 | 0.66 x 1.00 x 0.33 | 12 m tall | 12.02 | convex | d6c99cd5-9faa-415a-9e3d-cf958fd86ac3 |
| CH3_PYLON_BROKEN_B | Chapter3 | `assets/models/hero/ch3/lod/ch3_broken_pylon_b_LOD0.glb` | 18628 | 0.92 x 1.00 x 0.67 | 8 m tall | 8.02 | convex | 7c5f5e39-295b-4532-9354-16df792670c5 |
| CH3_BRIDGE_DEBRIS | Chapter3 | `assets/models/hero/ch3/lod/ch3_fallen_bridge_deck_chunk_LOD0.glb` | 17770 | 0.56 x 0.53 x 1.00 | see prompt | match neighbours | convex | 387b3207-5552-40fd-9a3f-8211c666c408 |
| CH4_MERIDIAN_GENERATOR | Chapter4 | `assets/models/hero/ch4/lod/ch4_meridian_generator_LOD0.glb` | 18706 | 1.00 x 0.77 x 0.78 | see prompt | match neighbours | box | 9e752b1c-60be-4cdb-9f9e-50ec3e205cbf |
| CH4_MERIDIAN_CRATE_STACK | Chapter4 | `assets/models/hero/ch4/lod/ch4_meridian_crate_stack_LOD0.glb` | 17935 | 1.00 x 1.00 x 0.90 | see prompt | match neighbours | box | f5c4e4e8-3376-4078-b9fc-911eb14a894c |
| CH4_MERIDIAN_TENT | Chapter4 | `assets/models/hero/ch4/lod/ch4_meridian_field_tent_LOD0.glb` | 17513 | 1.00 x 0.53 x 0.99 | see prompt | match neighbours | box | 1440f594-e552-42cb-9a64-4c4fdd637bb7 |
| CH4_LIGHT_TOWER | Chapter4 | `assets/models/hero/ch4/lod/ch4_mobile_light_tower_LOD0.glb` | 17168 | 0.36 x 1.00 x 0.27 | see prompt | match neighbours | box base + capsule mast | c0f13101-130a-4c5d-920d-0b0e6c6459a0 |
| CH4_1890_EXPEDITION_CACHE | Chapter4 | `assets/models/hero/ch4/lod/ch4_1890s_expedition_relics_LOD0.glb` | 18305 | 1.00 x 0.63 x 1.00 | see prompt | match neighbours | box | 3d1a29e7-ccef-40ac-9436-c12024c8dad5 |
| CH5_MERIDIAN_DRILL_RIG | Chapter5 | `assets/models/hero/ch5/lod/ch5_meridian_excavation_drill_LOD0.glb` | 17851 | 1.00 x 0.83 x 0.47 | see prompt | match neighbours | convex | 13f6a4f9-93a8-4128-ba44-0d37c125c6b2 |
| CH5_BARRICADE | Chapter5 | `assets/models/hero/ch5/lod/ch5_meridian_cover_barricade_LOD0.glb` | 18381 | 1.00 x 0.68 x 0.47 | 4 m long | 4.01 | box | fae5ff56-c19d-4cb0-980b-bed445a09fcc |
| CH5_COMMS_MAST | Chapter5 | `assets/models/hero/ch5/lod/ch5_meridian_comms_mast_LOD0.glb` | 17695 | 0.39 x 1.00 x 0.38 | see prompt | match neighbours | box base | 35f3261e-9936-461f-8cbf-431a47ee86c6 |
| CH6_TEMPLE_STATUE | Chapter6 | `assets/models/hero/ch6/lod/ch6_drowned_temple_statue_LOD0.glb` | 19324 | 0.63 x 1.00 x 0.65 | 8 m tall | 8.02 | convex | ed97cdbb-6704-44aa-9db0-06d1c5b0128f |
| CH6_SLUICE_GATE | Chapter6 | `assets/models/hero/ch6/lod/ch6_sluice_gate_LOD0.glb` | 17534 | 1.00 x 0.81 x 0.34 | 4 m wide | 4.01 | box gate + trimesh(LOD3) frame | 174d5530-f8be-48f6-bdd4-5b4818296782 |
| CH6_HYDRAULIC_WHEEL | Chapter6 | `assets/models/hero/ch6/lod/ch6_great_hydraulic_wheel_LOD0.glb` | 18711 | 0.56 x 0.96 x 1.00 | 9 m diameter | 9.38 | convex hub; rotate node | 3a9f80ba-cd3d-47f6-89a2-44492e5448fd |
| CH6_SUNKEN_AQUEDUCT | Chapter6 | `assets/models/hero/ch6/lod/ch6_sunken_aqueduct_arches_LOD0.glb` | 19027 | 0.19 x 0.48 x 1.00 | 10 m long | 10.02 | trimesh(LOD3) | 0f47f7d9-d05a-4230-95cf-df8e52c144d8 |
| CH7_LANDMARK_TOWER | Chapter7 | `assets/models/hero/ch7/lod/ch7_city_of_echoes_tower_LOD0.glb` | 17084 | 0.36 x 1.00 x 0.36 | 30 m tall | 30.06 | convex | c2a44c5a-c4bc-4a38-bb47-af0087f2003a |
| CH7_ARCHIVE_FACADE | Chapter7 | `assets/models/hero/ch7/lod/ch7_archive_facade_LOD0.glb` | 18881 | 0.95 x 0.83 x 1.00 | 15 m wide | 15.03 | trimesh(LOD3) | 483b1887-9006-4e64-bec1-bd8683a9b88a |
| CH7_TERRACED_RUINS | Chapter7 | `assets/models/hero/ch7/lod/ch7_terraced_ruins_LOD0.glb` | 19123 | 1.00 x 0.91 x 0.96 | 12 m wide | 12.02 | trimesh(LOD2) walkable | 85571fa6-29fd-4f36-8f6d-fa6e21ac3b30 |
| CH7_WATERFALL_CLIFF | Chapter7 | `assets/models/hero/ch7/lod/ch7_waterfall_cliff_LOD0.glb` | 18308 | 0.87 x 1.00 x 0.79 | 15 m tall | 15.03 | trimesh(LOD3) | 9d7ade54-06a1-4f0d-8d2b-cd53d888e29c |
| CH7_TOMB_SARCOPHAGUS | Chapter7 | `assets/models/hero/ch7/lod/ch7_optional_tomb_sarcophagus_LOD0.glb` | 18892 | 1.00 x 0.76 x 0.54 | see prompt | match neighbours | box | d0dc9616-0aa3-4cdb-b869-7b7e4bd80c04 |
| CH8_HARMONIC_KEY_ALTAR | Chapter8 | `assets/models/hero/ch8/lod/ch8_harmonic_key_altar_LOD0.glb` | 18654 | 1.00 x 0.77 x 0.91 | see prompt | match neighbours | convex | 63062fc4-c9be-4fcc-b88b-4483c87d165c |
| CH8_ELIAS_SYNDICATE_CAMP | Chapter8 | `assets/models/hero/ch8/lod/ch8_syndicate_field_lab_LOD0.glb` | 18053 | 1.00 x 0.55 x 0.94 | see prompt | match neighbours | box | 7368148b-558b-49bb-bc4a-a773b8729387 |
| CH8_COLLAPSED_STAIR | Chapter8 | `assets/models/hero/ch8/lod/ch8_grand_collapsed_stairway_LOD0.glb` | 18260 | 0.94 x 0.98 x 1.00 | 10 m long | 10.02 | trimesh(LOD2) walkable | 536b5fd1-2f6e-41d4-aba5-11aede7290c5 |
| CH9_SHEARED_CONDUIT | Chapter9 | `assets/models/hero/ch9/lod/ch9_sheared_resonance_conduit_LOD0.glb` | 18226 | 1.00 x 0.33 x 0.33 | 12 m long | 12.02 | convex | ba16dd95-4afa-4617-b60e-56446d4bd330 |
| CH9_FAULT_ROCK_SPLIT | Chapter9 | `assets/models/hero/ch9/lod/ch9_tectonic_fault_rock_LOD0.glb` | 19520 | 1.00 x 0.99 x 1.00 | 10 m tall | 10.10 | trimesh(LOD3) | c82a8420-657e-4b54-bbeb-f1ab4b4a74dd |
| CH9_HEART_ROAD_GATEHOUSE | Chapter9 | `assets/models/hero/ch9/lod/ch9_heart_road_gatehouse_LOD0.glb` | 18872 | 1.00 x 1.00 x 0.91 | 12 m tall | 12.02 | trimesh(LOD3) | 02046ff7-a25d-4909-9d04-008ae5d3b636 |
| CH10_HEART_CORE | Chapter10 | `assets/models/hero/ch10/lod/ch10_heart_vault_core_LOD0.glb` | 18642 | 0.90 x 1.00 x 0.90 | 10 m tall | 10.02 | sphere + convex dais | 1f63250c-70a3-4314-afd8-5a8f577c92ea |
| CH10_HARMONIC_PILLAR | Chapter10 | `assets/models/hero/ch10/lod/ch10_harmonic_node_pillar_LOD0.glb` | 17893 | 0.50 x 1.00 x 0.47 | 6 m tall | 6.01 | capsule/convex | 832ebc7a-46e5-4c79-9dfe-db52d40a69a3 |
| CH10_GEODE_WALL | Chapter10 | `assets/models/hero/ch10/lod/ch10_geode_crystal_wall_LOD0.glb` | 19307 | 0.83 x 1.00 x 0.99 | 8 m wide | 8.08 | trimesh(LOD3) | a2872151-7de7-4f96-a33a-80caff468798 |
| FIN_COLLAPSED_EXIT | Finale | `assets/models/hero/finale/lod/fin_collapsed_cave_exit_LOD0.glb` | 19465 | 0.80 x 1.00 x 0.96 | 8 m tall | 8.02 | trimesh(LOD3) | e22f4373-47d0-40c1-ba41-8e5068f57354 |
| FIN_RUBBLE_SLOPE | Finale | `assets/models/hero/finale/lod/fin_rockfall_rubble_slope_LOD0.glb` | 18786 | 0.50 x 0.44 x 1.00 | 8 m long | 8.02 | trimesh(LOD3) walkable | 8024f827-60a6-4286-b321-2efb5a994bcf |
| EPI_RIDGE_OVERLOOK | Epilogue | `assets/models/hero/epilogue/lod/epi_mist_ridge_rock_outcrop_LOD0.glb` | 19102 | 0.92 x 0.88 x 1.00 | 10 m wide | 10.02 | trimesh(LOD3) | afe57d34-b2b2-4e13-acbc-345c426728cd |
| PRO_RESONANT_GLYPH | Prologue | `assets/models/hero/prologue/lod/pro_resonant_glyph_monolith_LOD0.glb` | 19987 | 0.71 x 1.00 x 0.96 | 3 m long | 3.12 | convex | a77fbda4-d66e-44b2-bb0c-b2b75267498e |
| JUN_TREE_A | Shared jungle | `assets/models/jungle/lod/jun_kapok_tree_buttress_LOD0.glb` | 19122 | 1.00 x 0.99 x 0.98 | 18 m tall | 18.18 | capsule trunk | eeae2858-041e-427f-a393-b277f6530104 |
| JUN_TREE_B | Shared jungle | `assets/models/jungle/lod/jun_strangler_fig_tree_LOD0.glb` | 19999 | 0.93 x 1.00 x 0.86 | 14 m tall | 14.03 | capsule trunk | 99fa390e-cb52-41d6-ba5c-23c81ccb37db |
| JUN_TREE_C | Shared jungle | `assets/models/jungle/lod/jun_leaning_palm_cluster_LOD0.glb` | 16654 | 0.98 x 1.00 x 1.00 | 10 m tall | 10.02 | capsule per trunk | 82022841-fae1-4120-8960-4bbcf65c6de9 |
| JUN_TREE_D | Shared jungle | `assets/models/jungle/lod/jun_mossy_dead_tree_LOD0.glb` | 17274 | 0.49 x 1.00 x 0.50 | 7 m tall | 7.01 | capsule | c5806132-b1b8-42ec-9b28-db49bdb041b3 |
| JUN_ROOTS_A | Shared jungle | `assets/models/jungle/lod/jun_giant_surface_roots_a_LOD0.glb` | 18630 | 1.00 x 0.75 x 0.99 | 6 m wide | 6.01 | convex/trimesh(LOD3) | d526340f-c0b6-4e44-b6e3-9aaa0535eabd |
| JUN_ROOTS_B | Shared jungle | `assets/models/jungle/lod/jun_root_arch_over_stone_LOD0.glb` | 17466 | 1.00 x 0.83 x 0.83 | 4 m wide | 4.01 | convex | 2b6c4d80-21eb-4c0a-b062-b441cd52e211 |
| JUN_ROOTS_C | Shared jungle | `assets/models/jungle/lod/jun_hanging_root_curtain_LOD0.glb` | 19585 | 0.64 x 1.00 x 0.90 | 5 m tall | 5.01 | none (visual) | cadc6c69-84e1-40cb-8351-e614b4902560 |
| JUN_FERN_A | Shared jungle | `assets/models/jungle/lod/jun_fern_cluster_tree_fern_LOD0.glb` | 17838 | 1.00 x 0.85 x 1.00 | 3 m tall | 3.53 | none | 423479ea-ce77-42fe-a1a3-5ccf0479997e |
| JUN_FERN_B | Shared jungle | `assets/models/jungle/lod/jun_fern_cluster_low_LOD0.glb` | 15152 | 0.95 x 0.99 x 1.00 | 1.5 m tall | 1.51 | none | f26c364c-f640-4782-969d-d89758f2ef56 |
| JUN_BOULDER_A | Shared jungle | `assets/models/jungle/lod/jun_boulder_cluster_mossy_a_LOD0.glb` | 17434 | 0.98 x 0.64 x 1.00 | 4 m wide | 4.01 | convex | 2fa632b0-3145-4e0d-9542-0eff213807a1 |
| JUN_BOULDER_B | Shared jungle | `assets/models/jungle/lod/jun_boulder_cluster_split_b_LOD0.glb` | 17915 | 0.53 x 0.87 x 1.00 | 5 m wide | 5.01 | convex | 0cf42a20-0608-4773-b27a-2f9978b49fdc |
| JUN_BOULDER_C | Shared jungle | `assets/models/jungle/lod/jun_boulder_ruin_mix_c_LOD0.glb` | 18879 | 0.60 x 0.85 x 1.00 | 5 m wide | 5.01 | convex | 818d9c6d-30bf-4788-a4f3-a3156c601ce0 |
| CAV_STALACTITE_CLUSTER | Shared cave | `assets/models/cave/lod/cav_stalactite_ceiling_cluster_LOD0.glb` | 19552 | 1.00 x 0.94 x 0.99 | 5 m wide | 5.01 | none (ceiling) | cf9095d3-c141-4859-948e-a06c82a533c3 |
| CAV_COLUMN | Shared cave | `assets/models/cave/lod/cav_flowstone_column_LOD0.glb` | 19153 | 0.54 x 1.00 x 0.53 | 7 m tall | 7.01 | capsule/convex | 8a3f4ca2-850e-4edb-8c34-48b62ca6a1c1 |
| CAV_CLIFF_A | Shared cave | `assets/models/cave/lod/cav_limestone_cliff_a_LOD0.glb` | 18916 | 0.87 x 1.00 x 0.58 | 10 m wide | 11.56 | trimesh(LOD3) | 3ef656aa-2fe7-4dd1-87fa-00c7bbc1e1c7 |
| CAV_CLIFF_B | Shared cave | `assets/models/cave/lod/cav_limestone_cliff_b_overhang_LOD0.glb` | 19307 | 1.00 x 0.99 x 0.99 | 8 m wide | 8.02 | trimesh(LOD3) | d8d8335b-70f9-4c28-9559-faeaa14c2b27 |
| CAV_FLOWSTONE_WALL | Shared cave | `assets/models/cave/lod/cav_flowstone_drapery_wall_LOD0.glb` | 19509 | 0.33 x 0.61 x 1.00 | 6 m wide | 6.01 | trimesh(LOD3) | 7b1ac8a0-77a8-4fd8-9107-2be55535e6d0 |
| CAV_CRYSTAL_A | Shared cave | `assets/models/cave/lod/cav_resonant_crystal_cluster_a_LOD0.glb` | 19586 | 0.79 x 1.00 x 0.76 | 2 m tall | 2.00 | convex | 47d5b845-be1a-4137-8bfe-d0635d554248 |
| CAV_CRYSTAL_B | Shared cave | `assets/models/cave/lod/cav_resonant_crystal_vein_b_LOD0.glb` | 19232 | 0.87 x 1.00 x 0.80 | 3 m wide | 3.47 | convex | 27db1e25-f410-47bb-be75-9db522baf686 |
| CAV_RIMSTONE_POOLS | Shared cave | `assets/models/cave/lod/cav_rimstone_pool_terrace_LOD0.glb` | 19518 | 1.00 x 0.49 x 1.00 | 5 m wide | 5.01 | trimesh(LOD3) walkable | 12a77af8-fa9d-4081-bc1f-98421c458a2b |
| MER_GEAR_HELMET | Meridian | `assets/models/meridian/lod/mer_tactical_helmet_nvg_LOD0.glb` | 14293 | 0.98 x 1.00 x 0.97 | see prompt | match neighbours | none (attachment) | 3221aee6-50b0-457b-a914-8cea8e218df3 |
| MER_GEAR_RIFLE | Meridian | `assets/models/meridian/lod/mer_assault_rifle_LOD0.glb` | 17503 | 1.00 x 0.33 x 0.25 | see prompt | match neighbours | none (attachment) | cba70034-4cd7-456c-9bc8-af55f574e1a5 |
| MER_GEAR_HEAVY_ARMOR | Meridian | `assets/models/meridian/lod/mer_heavy_armor_vest_LOD0.glb` | 18389 | 0.67 x 1.00 x 0.72 | see prompt | match neighbours | none (attachment) | 8c215259-2e06-4478-ae20-6da728c0bd17 |
| MER_GEAR_BACKPACK_RADIO | Meridian | `assets/models/meridian/lod/mer_radio_backpack_LOD0.glb` | 14277 | 0.54 x 1.00 x 0.60 | see prompt | match neighbours | none (attachment) | 254d8034-fd76-4caa-8b75-29ac752a5a79 |
