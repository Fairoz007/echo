# Continuous QA Ledger

| ID | Sev | Status | Summary | Evidence | Fix |
|---|---|---|---|---|---|
| QA-001 | P1 | **Fixed** | Ch6 spawn camera ended up behind the south hall wall (the earlier report said "in reeds") | `dev/ch6_spawn_capture.gd`: camera z 26.39 → 24.78; render checked | `SouthWallBacking` collider in `systems/levelb/Chapter6Dressing.gd` (80207af) |
| QA-002 | P0→invalid | **Closed (test env)** | Campaign "Mara died in patrol combat EnemyMercenary1" | Under `--headless`, camera yaw stays at 0.0 because `CameraController._input` needs a captured mouse. Under Xvfb the same run passes. | The test now fails fast with a clear message if the mouse isn't captured. This was not a game regression; the previous status report was wrong to call it one. |
| QA-003 | P1 | **Fixed** | Ch5 promised "stealth or combat", but progression required killing both mercenaries | `dev/ch5_stealth_test.gd` PASS (undetected → progresses with 2 alive; detected → still gated) | Undetected-arrival route in `levels/Chapter5.gd`. A physical sneak traversal hasn't been played yet. |

## How to run (Linux container)
- Parse, movement and story tests: `--headless`.
- Physical campaign: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 -s res://scripts/qa_campaign_physical.gd -- --quality=1`
