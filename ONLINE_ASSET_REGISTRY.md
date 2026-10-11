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

## Candidates for the next art pass (license OK, not downloaded)
- Poly Haven `rock_wall_10`, `cliff_side`: cave and cliff variety for Ch4 and Ch7.
- Poly Haven and ambientCG ground, moss and wet-stone sets for the Ch6 hall and the Ch7 plaza.
