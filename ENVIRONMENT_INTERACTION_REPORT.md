# Environment interaction report

## Player to foliage

- **Tracking (no edits to Player.gd):** the WindSystem driver finds the node in group `"player"` (re-searching every 0.5 s if there isn't one). It reads `global_position` and computes a smoothed velocity.
- **Trail point:** it also keeps a lagged trail point, following at about 1.6/s.
- **Teleports:** a jump of more than 5 m (respawn or teleport) resets the trail, so nothing gets smeared.
- **Shader push:** `wind_player_push(world_pos)` in `wind_common.gdshaderinc` returns a horizontal push away from the player, in the range 0..1.
  - It uses a smoothstep falloff over `interact_radius` = 1.2 m.
  - A vertical band test means foliage on other floors isn't affected.
  - There is a small drag along the player's velocity.
  - A 0.7-weight push from the trail point makes plants the player passed recover smoothly instead of snapping back.
- **Users of the push:**
  - Grass, per clump root: up to 0.55 × blade bend ÷ stiffness.
  - Bushes and ferns, per vertex: weighted by height and flexibility.
  - Vines, from the free end.
  - Trees: `interact_strength` is 0, so they don't react.
- **Quality:** turned off on ULTRA LOW.
- **Result:** the walk sequence (`screenshots/nature/q1/walk_*`) shows grass and the bush parting around Mara's legs. In `walk_recover_*` the motion decays over about 1 s.

## Per-chapter wind preset recommendation

Each level adds one line at the end of its `_ready()`. I did not make these edits, because level files belong to Level A and Level B.

| Level | Setting | Preset | Line to add |
|---|---|---|---|
| Prologue (`levels/Prologue.gd`) | cave, river mouth | CAVE | `WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)` |
| Ch1 (`systems/levelb/Chapter1Dressing.gd:88`) | jungle outdoor | BREEZE | replace the `set_wind` call with `WindSystem.set_preset(WindSystem.Preset.BREEZE, 0.0, Vector2(0.8, -0.6))` |
| Ch2 (`levels/Chapter2.gd`) | jungle ruins outdoor | MODERATE | `WindSystem.set_preset(WindSystem.Preset.MODERATE, 0.0)` |
| Ch3 (`levels/Chapter3.gd`) | gorge bridge | STRONG | `WindSystem.set_preset(WindSystem.Preset.STRONG, 0.0)` |
| Ch4 (`levels/Chapter4.gd`) | deep cave | CAVE | `WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)` |
| Ch5 (`levels/Chapter5.gd`) | jungle stealth | BREEZE | `WindSystem.set_preset(WindSystem.Preset.BREEZE, 0.0)` |
| Ch6 (`levels/Chapter6.gd`) | drowned temple | CAVE | `WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)` |
| Ch7 (`levels/Chapter7.gd`) | subterranean city | CAVE | `WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)` |
| Ch8 (`levels/Chapter8.gd`) | surface camp | MODERATE | `WindSystem.set_preset(WindSystem.Preset.MODERATE, 0.0)` |
| Ch9 (`levels/Chapter9.gd`) | heart road, deep | CAVE | `WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)` |
| Ch10 (`levels/Chapter10.gd`) | heart vault | CAVE | `WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)` |
| Finale (`levels/Finale.gd`) | mountain breaks | STORM | `WindSystem.set_preset(WindSystem.Preset.STORM, 4.0)` (blend in during the escape) |
| Epilogue (`systems/levelb/EpilogueVista.gd:45`) | ridge vista | BREEZE | replace the `set_wind` call with `WindSystem.set_preset(WindSystem.Preset.BREEZE, 0.0, Vector2(0.6, -0.8))` |

**Extra optional lines:**

- **Prologue water:** `systems/environment/PrologueWater.gd:59` can keep its `set_wind`, or switch to CAVE.
- **Falling leaves in outdoor jungle chapters (Ch1, Ch2, Ch5, Ch8, Epilogue):**

  ```gdscript
  var leaves = preload("res://systems/nature/FallingLeaves.gd").new(); leaves.follow_camera = true; add_child(leaves)
  ```

**Audio and rain:**

```gdscript
WindSystem.driver().wind_changed.connect(func(s, d, turb, storm): ...)
```
