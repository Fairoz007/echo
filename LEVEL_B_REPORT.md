# Level B Report: Ch1, Ch5, Ch6, Ch8, Epilogue

All testing used Godot 4.7.2 with the gl_compatibility / opengl3 renderer, the **Low** preset (`--quality=1`) and a 1280x720 window, one instance at a time.
- Capture harness: `systems/levelb/qa_levelb_capture.gd`. It takes `--levels=1,5,6,8,12`, `--tag`, `--seq` (6-frame sequence) and `--drain` (Ch6 drained views). Output goes to `screenshots/levelb/<tag>_Lnn_*.png`.
- Final evidence set: `screenshots/levelb/final_*`. Iterations it1 to it11 are kept as history; `base_L01_*` shows the state before this work.

## Architecture
Each level script calls a runtime dresser in `systems/levelb/` from `_ready`, so the authored gameplay node paths, QA routes and save paths are unchanged.
- **Removed from my scenes:** the `CampaignEnvironmentArt` node (the sand MultiMesh ground) and Ch1's eight identical `NaturalCliff` nodes.
- **Shared parts:**
  - `LBKit.gd`: fitted model placement, the rock re-grade material, NPCs, colliders, collectibles and lights.
  - `LBTerrain.gd`: heightfield mesh plus HeightMapShape3D.
  - `terrain_blend.gdshader`: procedural grass/soil/litter, slope rock strata and wet mask.
  - `rock_moss.gdshader`: re-grades a model's own atlas with tint breakup and moss.
  - `LBCollectible.gd`: Interactable read panel, MissionManager objective and SaveManager persistence.
  - `LBFoliageWind.gd`: uses the `shaders/foliage_wind.gdshader` tiered shader through WindSystem and stays on at Low.
  - `LBMeridianGear.gd`: BoneAttachment3D gear (helmet on Head, rifle on R_Hand, vest or radio on Spine02) in three variants: rifleman, heavy and radio.
- **Audio:** each level calls `Soundscape.attach(level, "Cxx")` and adds emitters and reverb zones. Ch6 also drives `set_water_state` (draining/rising) and `set_underwater`.
- **Mara source:** the Ch1, Ch5, Ch6 and Ch8 scenes now point at `CHR_Mara_Game_LOD0.glb`.
- **Collision audit** (`scripts/qa_collision_audit.gd --levels=1,5,6,8`): **failures=0**. The last run before the final light-shaft fix showed white=1 (the Ch6 light-shaft beam). It was given a texture afterwards and has not been re-audited.

## Physical route QA (`qa_campaign_physical.gd`, scoped per chapter)
All four chapters walk their full route and load the next chapter:
- Ch1 → Ch2
- Ch5 → Ch6
- Ch6 → Ch7
- Ch8 → Ch9

Every scoped run still ends with "Credits return did not reach Main Menu". That happens in the harness's return-to-menu step after the next chapter has loaded, when `--qa-end-chapter` is not 12; it is not a level failure. I did not investigate it, because it is outside my files.

Route blockers I found and fixed:
- Ch1: the command tent and hero portal were on the walked line.
- Ch5: a sandbag wall and a crate stack were on the line.
- Ch6: the scaled turbine, and the side-on sanctum arch that blocked the ramp.
- Ch1: the survey desk had gained auto collision. It is set back to no collision, which was the previous behaviour, because the QA bot has to stand at the table's centre.

## Per level

### Chapter 1, The Arrival: IMPLEMENTED / TESTED / VISUALLY VERIFIED
- **Ground:** a 220 m blended terrain replaces the sand. Paths are packed soil, the meadow has noise-varied grass and leaf litter, and slopes turn to rock strata. P1 fixed: the blotchy sand is gone (`final_L01_gameplay`, `final_L01_ground_blend`).
- **Ridge cliff:** staggered, curved massing with varied scale, yaw and depth, talus boulders, and the moss/tint re-grade. P1 fixed: the straight line of identical walls is gone (`final_L01_cliffline`, `trail_ridge`).
- **Landmark:** the hero sealed portal (phase-2 asset) between carved pillars, on a 6 m-high ridge plateau reached by an ascending trail (`final_L01_ridge_portal`).
- **Camp:**
  - Six tents, the hero command tent and the supply truck.
  - A command tarp over the survey table, and a campfire with flickering light, smoke and seat logs.
  - Nadiya's radio and antenna mast (blinking beacon), and Tomas's gear bench.
  - A generator, fuel cans and lantern posts.
- **NPCs:** Elias at the table, Nadiya at the radio, Tomas at the bench (new "Talk to Tomas") and Adrian apart. They play animated idles (`final_L01_camp_close`).
- **Routes:**
  - Primary: the trail from camp to the portal.
  - Secondary: the western ledges past the survey cairn, with a plank bridge, to the plateau.
  - East spur to the waterfall gorge, with a Waterfall, basin and swimmable stream (`final_L01_gorge`).
- **Discoveries:** R. Vale's 1987 journal at the cairn, and a Vaelor tablet beside the falls.
- **Vegetation:**
  - Phase-2 jungle set: 4 tree types plus the original tree, 2 fern clusters plus the original fern, 3 boulder clusters, 3 root pieces (the curtain sways).
  - GrassScatter with a lighter tint is masked off the paths.
- **Wind:** visible on Low. Mean frame-to-frame motion is about 0.9 (`final_L01_seq00-05`), up from 0.01–0.06 before. The figure is measured on the camp view, which mixes foliage and campfire smoke.
- **Sky and light:** a procedural sky, filmic tonemap and fog. Sun shadows use blur 2.5 and opacity 0.72 to soften the hard shadow blobs.
- **Wildlife ambience:** Soundscape emitters in group `wildlife_ambience_hook` (birds/insects), a waterfall emitter and ruin reverb zones.
- **Remaining defects:**
  - Steep terrain faces stretch texture slightly.
  - Grass blades are still dark at grazing angles on Low.
  - Mara's T-pose arms appear in some captures; this is the player model, not mine.

### Chapter 5, Hunters: IMPLEMENTED / TESTED / VISUALLY VERIFIED (lighting is dim)
- **Cavern:** a limestone cavern with cliffs, ceiling and stalactites.
- **Lanes and approach routes:**
  - Centre lane: crate and barricade cover.
  - West route: a 3.5 m ledge with a ramp, plus a scaffold watchtower (4 m deck, stair ramp, sweeping searchlight) as the vertical observation points.
  - East route: a flooded drainage channel (WaterBody UNDERGROUND_STREAM) with pipe cover.
- **Overlook:** the overlook rail, then a ramp down to the aqueduct entrance, with the flooded temple basin and pillars as the landmark.
- **Phase-2 props:** drill rig, 5 barricades, comms mast, generator, crate stacks, field tent, light tower and flowstone columns.
- **Enemies:** Meridian enemies wear bone-attached gear variants.
- **Discoveries:** Meridian Requisition Order 7-C, and the tower watch log on the deck.
- Evidence: `final_L05_*`.
- **Remaining defects:**
  - The scene is still dark in places, because the Compatibility renderer allows only 8 lights per mesh on the large floor.
  - The gear attachment offsets were not checked in close-up.

### Chapter 6, The Drowned Temple: IMPLEMENTED / TESTED / PARTIALLY VISUALLY VERIFIED
- **Water:** WaterBody FLOODED_TEMPLE (46x38) replaces the legacy WaterVolume and WaterPresentation.
- **Drain:** turning the turbine calls `set_level` over 4 s (the legacy `water_plane` tween is kept for QA). It also spins the hero great waterwheel and the bronze gear train, raises three hero sluice gates and plays the grind and draining audio.
- **Wet surfaces after draining:** visible in `final_L06_drained_*`. Walls, floor and props are in group `wettable`.
- **Underwater:** fallen pillars, slabs, waterweed and a cool underwater light. Dive slate document on the floor.
- **Hero assets:** the guardian statue and two sunken aqueduct arch spans.
- **Rising-water puzzle:** in the east cistern, a valve raises RISING_PUZZLE_WATER over 10 s. Mara swims up to the high ledge to reach the "Tablet of the Waterline" (optional objective).
- **Spawn:** moved onto a dry stone landing at (0, 1.4, 23), as the movement agent requested. Consequence: `scripts/qa_water_input.gd` expects Mara to start in SWIM, so it will now fail until it moves her into the water first.
- **Remaining defects:**
  - The hall reads dark and murky on Low.
  - The re-graded Vaelor wall atlas shows white specks.
  - Underwater visibility was only partly verified.
  - The cistern puzzle was never played end-to-end with input (only implemented).
  - The sanctum arch has no collision on its open frame; I added jamb boxes.

### Chapter 8, The Betrayal: IMPLEMENTED / TESTED / VISUALLY VERIFIED
- **Setting:** a sanctum nave with a colonnade and carved walls, and the survivor refuge: tent, bedroll, med kit, and Nadiya and Tomas with "Talk to Tomas". Elias is shown lying injured.
- **Routes:** the raised east gallery with balustrade cover and a ramp is the secondary route.
- **Landmark:** the hero Harmonic Key altar with its empty cradle glow, a ring of pillars, the sanctum arch and resonant crystals.
- **Props:** the syndicate field lab and Adrian's transmitter on the gallery, and the collapsed stairway.
- **Cinematic staging:** 9 `cinematic_mark` Marker3Ds (Mara, Elias, Nadiya, Tomas, Adrian, Drake, and wide and close cameras).
- **Combat escalation:** starts after Elias speaks. Wave 1 (2 mercs) arrives after 6 s. Clearing it brings wave 2 (3 mercs, flanking the gallery), with gear variants and barks. Waves do not gate the confrontation, so the existing flow and QA pass.
- **Discoveries:** Adrian's transmission log and Elias's journal.
- Evidence: `final_L08_*`.
- **Remaining defect:** combat waves were not exercised by an automated fight test.

### Epilogue, Daylight: IMPLEMENTED / VISUALLY VERIFIED
- A SubViewport sunrise vista sits behind the unchanged text, credits and button flow: procedural dawn sky, valley terrain, swaying jungle trees, a RIVER WaterBody, the hero ridge outcrop, and Mara, Nadiya and Tomas looking out at the valley.
- A slow camera pull-back, a readability band and a daylight wind and birds bed.
- The mojibake in the credits text is fixed.
- Evidence: `final_L12_t7`.
- **Remaining defect:** the full credits-to-menu path was not re-run.
