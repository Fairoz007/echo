# Campaign Playtime Report

**Target:** about 20 hours (raised from 10 on 2026-10-11).
**Measured:** no human playtest yet. Nothing below is a measured first-time-player time.

## What is actually measured
| Run | Result |
|---|---|
| Scripted bot, New Game → Credits (`qa_campaign_physical.gd`) | 15–25 min of route time. The bot knows every answer and skips all optional content. |

## Estimate of current first-time play (not measured)
| Content | Estimate | Basis |
|---|---|---|
| Critical path (12 chapters, cutscenes, dialogue) | 1.2–2 h | Bot route time ×4–5 for navigation, reading and failures |
| Optional dial tombs (30 across Ch1–Ch10) | 0.5–1 h | Same template every time, 1–2 min each |
| Collectibles (Ch1, 5, 6, 8 documents) | 0.1–0.2 h | 2 per dressed chapter |
| **Resonance shards (new, 57 across 12 chapters)** | **0.5–1 h** | A 5–36 m detour each, 30–60 s including reading |
| **Total** | **≈ 2.3–4 h** | **About 16–18 hours short of 20** |

## Resonance shards (added 2026-10-11)
- **System:** `systems/environment/RelicHunt.gd`. Lore is in `content/relic_shards.json`: five fragments per chapter that tell the Vaelor story in order.
- **Placement:** placed on real floor 5–36 m off the travel corridor. Each spot is validated by sweeping Mara's own collision capsule from the corridor, plus floor sampling for pits.
- **Rewards and saving:** a full chapter set completes `opt_relics_cNN` and grants 400 XP once. Shards save through the existing collectible persistence.
- **Proof of reachability:** `dev/relic_reach_test.gd` walks Mara to every shard with real move input and reads it. Result: **57/57 collected across all 12 levels** (Ch1 has 2 because its tight layout leaves few valid spots). Placement waits until level collision has stopped changing for 2 s, because procedural rock masses arrive late, and keeps shards 8 m from story triggers.

## Plan toward 20 hours (content, not padding)
| Priority | Work | Est. added play |
|---|---|---|
| 1 | **Ch7 City of Echoes hub:** 6 districts, each with an objective, a puzzle or encounter, and a landmark | 2–3 h |
| 2 | **Replace the 30 identical dial tombs** with 5 distinct mechanics (water level, counterweight, pressure sequence, resonance tuning, light beam), 2–4 min each | 1.5–2.5 h |
| 3 | **Combat and stealth encounters in Ch4, 7, 8, 9 and 10** (EnemyBase and takedowns already exist), 2–3 per chapter | 1.5–2.5 h |
| 4 | **Seamless world:** convert the remaining 11 chapter boundaries into walkable connectors with small encounters | 1–1.5 h |
| 5 | **Side contracts per chapter** (missing expedition members' caches, Meridian intel) using the shard and collectible systems | 2–3 h |
| 6 | **New areas between chapters:** jungle valley, underground river, Meridian forward base | 4–6 h |
| 7 | **Difficulty, retries and a post-game relic vault** | 1–2 h |

Even with all of this, reaching 20 measured hours is a multi-session effort. Each step will be playtested and reported with real numbers, not planned durations.
