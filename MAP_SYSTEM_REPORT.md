# Mini-map & World Map — System Report

## What exists now

| Piece | File | Role |
|---|---|---|
| Map state (autoload) | `systems/map/WorldMapManager.gd` | Coordinate mapping, region and layer resolution, fog of war, POI discovery, markers, waypoint, persistence, settings |
| Shared renderer | `ui/map/MapView.gd` | Region cartography with a fog shader, routes, a vector icon set and labels. Used by both maps. |
| HUD mini-map | `ui/map/MiniMap.gd` (added by `ui/HUD.gd`) | Circular map at the top right, compass ring, heading readout, rim pointers, waypoint/layer readout, and the in-world navigation indicator |
| Full-screen atlas | `ui/map/WorldMap.gd` (owned by `GameManager`) | M / D-pad Right; zoom, pan, region jump list, layer selector, legend filters, waypoint placement, scale bar |
| Cartography baker | `dev/map_bake.gd` | Offline bake from each chapter's real collision geometry plus a clipped overhead render (see below) |
| Data | `content/map/regions.json`, `content/map/baked/*`, `content/map/objective_targets.json` | Authored region, layer, landmark and tomb data; baked maps; objective → node mapping |
| QA | `dev/map_test.gd` | 162 automated checks across all 12 regions, with screenshots in `screenshots/map/` |

The input action `map` is part of the remappable control list in `systems/InputRemap.gd` (M; gamepad D-pad Right).

## Coordinate system (honest state of the unified world)

The campaign is still a chain of chapter scenes, each with its own local space; region handoffs carry the same Mara between them. The map uses **one** world-map coordinate system:

`map = level-local XZ − bake origin + region offset`

- **Player position:** never stored by the map. Each query reads the live Player and converts it into the owning level's local space (`level.to_local`). That conversion keeps it correct under region rebasing and the staged Ch5/Ch6 co-presence, and after save/load and respawn.
- **Region placement:** regions are laid out in campaign order, and deeper layer kinds are placed lower on the atlas.
  - Regions joined by a real passage (Ch1→2, 4→5, 5→6, 6→7, 7→8, 9→10) get a solid route line.
  - Regions joined by a fade (a fall or scripted descent) get a dashed line and a gap. They are **not** drawn as touching, because their true relative positions are not authored.
  - When chapters are physically merged, only `offset` per region needs to change. Nothing else depends on the layout.

## Cartography

`dev/map_bake.gd` loads each level and builds the map in three steps:

1. It casts rays down a 0.5 m grid and keeps upward-facing hits with at least 1.5 m of headroom. These are the walkable floors, recorded at every height.
2. It splits the floors into the layer bands from `regions.json`.
3. It renders an orthographic overhead view with the near plane just above the band, so roofs and ceilings are culled.

The output is the real art, graded bronze. Inside the walkable mask it gets height shading, hillshade, 4 m contours, and dark edges at steps over 0.7 m. Water comes from the actual `WaterVolume` areas. The baker also writes an 8-bit floor-height grid per layer, which is used for layer-aware waypoint snapping and for the alignment test. No live 3D map camera runs in game.

**Layers.** Multi-floor regions are banded from measured height histograms:

| Region | Layers |
|---|---|
| Drowned Temple | Upper Galleries (y ≥ 4) / Submerged Halls (y < 4) |
| Meridian Territory | Plateau / Excavation Pit |

Every region is also tagged with a layer kind: Surface, Upper Ruins, Cave Network, Submerged Temple, Lost City or Heart Vault.
- The mini-map follows Mara's layer automatically.
- The atlas can override the layer per kind (layer buttons or Q/E / LB/RB); regions of other kinds are dimmed.
- Stairs, ladders and cave entrances appear when the scene has nodes named that way. Few current scenes have them, so this layer is sparse.

## Markers

| Marker | When it shows |
|---|---|
| **Objective** | Active objectives mapped in `objective_targets.json` to real level nodes. Covers every main objective of all 12 regions, plus the Ch7 seals, fuse and causeway. An objective with no physical place (e.g. a radio call) has no marker. |
| **Landmark** | Once found within 30 m. Includes the camp, ridge and all Chapter 7 districts. |
| **Tomb** | Once found within 30 m. Covers CampaignExploration tombs and the Ch7 Hall of Weights, Sunken Archive and Resonant Chamber. |
| **Route onward** | The chapter exit from `GameManager.IN_WORLD_EXITS`. |
| **Enemy** | Only while that enemy is Suspicious, Alert, in Combat or Taking Cover. |
| **Relic shard** | Only with the Resource Awareness skill, within 45 m. |
| **Waypoint** | Placed on the atlas, snapped onto a real floor (Mara's layer first). |

**Waypoint guidance.**
- Distance is measured in real 3D local coordinates.
- If the waypoint is on another layer, the readout says "Upper/Lower level — find a way up/down" instead of giving straight-line guidance.
- If it is in another region, it names the region and says it is not reachable on foot from here.
- There is no navmesh in the project, so no route path is drawn.
- There is no fast travel; it was not requested as a feature and is not implemented.

## Fog of war & persistence

- Fog is a 4 m grid per region, revealed within 26 m of Mara every 0.2 s. Unexplored areas are fully hidden, and undiscovered regions show only as "Uncharted".
- The save stores revealed cells (deflate + base64), discovered regions, discovered POIs and the waypoint in `game_data["map"]`. It is validated in `_valid_save`, restored on `load_game`, and cleared on a new game.
- Mini-map rotation and the nav indicator are per-machine settings in `user://map_settings.cfg`.

## Input safety

- Opening the atlas pauses the tree, which is why the test confirms Mara does not move while move and fire are held.
- The atlas consumes keyboard and pad input; mouse events reach its own GUI only.
- On close it restores the previous pause state and mouse capture, releases latched combat/interaction actions, and shows the HUD again.
- The `map` action does not collide with any existing default binding.

## Verified (dev/map_test.gd, xvfb + GL compatibility, 1280×720)

**162 passed, 0 failed.** Each of the 12 regions is checked for:
- the region resolves;
- the map↔local round trip has 0.000 m error;
- **the baked map floor matches Mara's feet** (within 0.6 m plus quantisation), so the map is aligned with the playable geometry;
- heading error is 0.000 rad at N/E/S/W;
- fog reveals around Mara;
- the mini-map is visible and does not overlap the objective panel;
- objective markers are present;
- M opens the atlas paused, Mara does not move with move and fire held, a waypoint is placed 15 m away and measures 15 m, and M closes it unpaused with the HUD restored.

Also checked:
- **Layers:** auto-selection for the Temple and Meridian bands.
- **City of Echoes:** all 7 districts and landmarks discovered and revealed by walking to them.
- **Save → reset → load:** fog fraction, waypoint and discovered regions are restored exactly.
- **CPU cost (Temple):** mini-map + manager median 0.33 ms, p95 0.70 ms per frame. The manager alone is 0.03 ms.

## Known limits

- The world layout is a schematic atlas of separately authored regions, by design until the chapters are physically merged.
- Several levels are large flat slabs with visual dressing, so their maps show the real dressing over a broad walkable area.
- Bake bounds come from collision extents, so some maps have dark margins.
- Stairs, ladders and lifts depend on node naming; few scenes name them, so connection markers are rare.
- No navmesh means no drawn accessible route.
- Gamepad atlas controls read device 0 axes. They were exercised by code paths only; no physical controller was available in the test environment.
- Ultrawide was not captured as a screenshot. The UI is anchor-based (`canvas_items` + `expand`), so panels pin to the edges and the map fills the width.

## Re-baking

```
xvfb-run godot --path . --rendering-method gl_compatibility -s res://dev/map_bake.gd [-- --only=<chapter> --stats]
godot --headless --path . --import
```
