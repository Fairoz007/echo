# Seamless Transition QA (2026-10-12)

**Verdict:** all 11 in-game chapter boundaries now advance in the running world with the same Mara. **The story card and scene reload are gone from normal progression;** they remain only for menu, continue and the ending.

## Automated results (this commit)
| Test | Result |
|---|---|
| `dev/boundary_test.gd`: every boundary except 5→6 | **PASS**. For each boundary it checks: no story card; chapter advanced; same Mara and same HUD instance; health (77) and ammo (5) kept; exactly one player. Walkable exits also check that the exit and entry passages exist, that a save inside the entry passage reloads within 1 m, and that the reloaded region has its sealed entry passage. |
| `dev/region_handoff_test.gd`: Ch5→6 aqueduct | **PASS** (unchanged checks) |
| `scripts/qa_campaign_physical.gd`: full New Game → Credits, real input under Xvfb | **PASS**, 1302 m. The bot walks every passage through the swap; log below. |
| Movement 54/54, story flow, Ch5 stealth, Ch7 city 34/34, parse | **PASS** |

```
In-world advance 0 -> 1 (fade)     fade handoff 6811 ms (behind the black fade; software GL)
In-world advance 1 -> 2 (passage)  total 38 ms
In-world advance 2 -> 3 (fade)     15 ms
In-world advance 3 -> 4 (fade)     13 ms
In-world advance 4 -> 5 (passage)  total 1374 ms   <- Ch5 builds synchronously
(5 -> 6 staged aqueduct, step-by-step build)
In-world advance 6 -> 7 (passage)  total 593 ms (6.7-7.1 s on a cold cache) <- Ch7 builds synchronously
In-world advance 7 -> 8 (passage)  total 344 ms
In-world advance 8 -> 9 (fade)     14 ms
In-world advance 9 -> 10 (passage) total 35 ms
In-world advance 10 -> 11 (fade)   10 ms
```

## Bugs found and fixed on the way
- **Root cause of "popup, then gameplay restarts":** chapter exits went through the blocking story card and a full scene replacement, which recreated Mara at the chapter start. Replaced by in-world progression.
- **Death advanced the story:** dying during a chapter-ending scene (Ch8 betrayal) showed the game-over menu and then loaded the next chapter anyway. `load_chapter` now ignores advances while in GAME_OVER.
- **Fade kill plane:** during a fade, a scripted fall (Ch3 fissure) kept falling to the kill plane, and the corpse carried into Ch4. Mara is now frozen for the fade, and her fall speed is reset at the spawn.
- **Passage clearance:**
  - CSG blockouts kept their collision inside the tunnel.
  - An arch straddling the mouth (Royal Causeway) blocked the entrance.
  - The "ground" raycast hit the passage's own floor, so the real floor (the Ch6 ramp) was de-collided and Mara fell through.
  - Terrain crossing the tunnel (Ch1 ridge) blocked the way; it's now **carved** (heightmap, concave and mesh).
- **Third-person aiming:** shots traced from the camera, so with the camera behind a pillar Mara shot the wall while enemies could still hit her. The aim ray now starts at Mara's depth, and the shot is fired from her chest.
- **Persistent health with no recovery:** Mara could arrive at an encounter badly hurt. Added out-of-combat regeneration (6 s delay, 8 HP/s). Ch8 breach waves were rebalanced: 10 damage, sight 16/19 m.

## Not verified
- **Real-GPU frame times** at passage swaps. The Ch5 and Ch7 synchronous builds will still hitch; they need the staged build.
- **Death and respawn after an in-world boundary** through the pause-menu checkpoint flow.
- **Visual look of the passages** (no screenshots this pass) and of the carved terrain from outside.
- **No human playthrough.**
