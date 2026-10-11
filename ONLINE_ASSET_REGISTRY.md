# Online Asset Registry

Only sources whose license I checked on the source's own license page are listed. **Integrated** means downloaded, imported, used in a scene, and checked in a rendered capture.

## Verified license sources (checked 2026-10-11)
| Source | License page | License | Commercial use | Attribution |
|---|---|---|---|---|
| Poly Haven | https://polyhaven.com/license | CC0 | Yes | Not required (appreciated) |
| ambientCG | https://docs.ambientcg.com/license/ | CC0 1.0 Universal | Yes | Not required (appreciated) |

Not yet checked: Quaternius, Kenney, Sketchfab (per-model licenses), Fab. Don't integrate anything from these until its license has been checked.

## Assets
| Asset | Source URL | Author | License | Files | Status | Used in |
|---|---|---|---|---|---|---|
| Rock Wall 08 (PBR, 1k) | https://polyhaven.com/a/rock_wall_08 | Amal Kumar | CC0 | `assets/textures/polyhaven/rock_wall_08_{diff,nor_gl,rough}_1k.jpg` (2.4 MB) | **Integrated** | `systems/world/connectors/Ch5Ch6Aqueduct.gd`: triplanar on the shell and kit pieces. Rendered check: `seam_02_*.png` (scratch). |

| Forest Ground 04 (1k diff+nor) | https://polyhaven.com/a/forest_ground_04 | Rob Tuytel, Rico Cilliers | CC0 | `assets/textures/polyhaven/forest_ground_04_*` | **Integrated** | Ch1 terrain `ground_albedo` layer (`terrain_blend.gdshader`). Before/after: `docs/visual_benchmark/` |
| Rocky Terrain 02 (1k diff+nor) | https://polyhaven.com/a/rocky_terrain_02 | Amal Kumar | CC0 | `assets/textures/polyhaven/rocky_terrain_02_*` | **Integrated** | Ch1 terrain slopes, `rock_albedo` triplanar |
| Quaternius Universal Animation Library (120+ clips, CC0) | https://quaternius.com/packs/universalanimationlibrary.html | Quaternius | CC0 (license page) | — | **Blocked: needs a manual download.** The itch.io "name your own price" flow requires the browser. | Would cover strafe, push, crawl, combat and death clips for retargeting |
| Mixamo | https://www.mixamo.com/ | Adobe | Adobe terms (royalty-free in games) | — | **Blocked: needs an Adobe login** | — |


## Poly Haven 3D models: integrated in the Ch1 Expedition Camp (`Chapter1Dressing._photo_props`, `_ph`)
| Model | Polys | Use |
|---|---:|---|
| [Lantern 01](https://polyhaven.com/a/Lantern_01) | 33902 | workbench lantern with light |
| [Ammo Box](https://polyhaven.com/a/ammo_box) | 4382 | stacks by the truck and command tent |
| [Boulder 01](https://polyhaven.com/a/boulder_01) | 123976 | boulders |
| [Calathea Orbifolia 01](https://polyhaven.com/a/calathea_orbifolia_01) | 16688 | broadleaf understorey |
| [Cement Bag](https://polyhaven.com/a/cement_bag) | 844 | sandbag/supply pile |
| [Dead Tree Trunk 02](https://polyhaven.com/a/dead_tree_trunk_02) | 155864 | fallen trunk on the trail side |
| [Fern 02](https://polyhaven.com/a/fern_02) | 6232 | understorey |
| [Medical Box](https://polyhaven.com/a/medical_box) | 3718 | command tent |
| [Metal Jerrycan Green](https://polyhaven.com/a/metal_jerrycan_green) | 9636 | fuel cans by the generator (replaced box stand-ins) |
| [Metal Toolbox](https://polyhaven.com/a/metal_toolbox) | 14228 | workbench |
| [Pachira Aquatica 01](https://polyhaven.com/a/pachira_aquatica_01) | 76914 | small tropical trees |
| [Portable Generator](https://polyhaven.com/a/portable_generator) | 26419 | camp generator (replaced the yellow box) |
| [Portable Searchlight](https://polyhaven.com/a/portable_searchlight) | 18802 | camp floodlight |
| [Rock Moss Set 01](https://polyhaven.com/a/rock_moss_set_01) | 63127 | clearing-edge rocks |
| [Root Cluster 01](https://polyhaven.com/a/root_cluster_01) | 225261 | exposed roots |
| [Rusted Spade 01](https://polyhaven.com/a/rusted_spade_01) | 11436 | leaning by a tent |

Rejected after download as too heavy for real-time use: Island Tree 01 (3.7M polys), Island Tree 02 (1.8M), Jacaranda (210 MB). Old Military Crate was also rejected: its lids lie open and read as floating boards.
Evidence: `docs/visual_benchmark/camp_gear.jpg`, `camp_edge.jpg`. Fetch script: `scripts/fetch_polyhaven_models.py`.

## Campaign-wide dressing (`systems/environment/PhotoDressing.gd`)
Added 2026-10-11 for Prologue, Ch2, Ch3, Ch4, Ch7, Ch9, Ch10 and the Finale (Ch1, 5, 6 and 8 already have hand-built dressing).
- **Sets:** jungle (Ch2), ruins (Ch3, Ch7, Ch9), cave (Prologue, Ch4, Ch10, Finale), and Meridian supply clusters.
- **Placement:** raycast against real floor collision. It avoids spawn points, triggers and the central corridor, and prefers lit ground in dark levels. Every Meridian cluster brings its own lantern and work lamp.
- **No collision:** nothing it places has collision, so it can't block progression.
- **New models:** rock_07, rock_09, rock_moss_set_02, dry_branches_medium_01, dead_tree_trunk, old_military_compressor, plastic_crate_03, wooden_crate_01, Barrel_01, barrel_03, picke_dirty_01.
- **Placement counts** (`dev/photo_dressing_probe.gd`): Prologue 26+1 cluster, Ch2 46+1, Ch3 34, Ch4 34+3, Ch7 40+2, Ch9 36+3, Ch10 18+1, Finale 40.
- **Visual result:** clear in Ch3 (ferns flank the bridge-gate approach; same-camera before/after). Limited in the darkest levels (Ch4, Ch7, Prologue), where most of each level is unlit. Those need a lighting pass to show the dressing.

## Candidates for the next art pass (license OK, not downloaded)
- Poly Haven `rock_wall_10`, `cliff_side`: cave and cliff variety for Ch4 and Ch7.
- Poly Haven and ambientCG ground, moss and wet-stone sets for the Ch6 hall and the Ch7 plaza.
