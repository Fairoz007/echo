# Chapter 7: City of Echoes Expansion (2026-10-12)

Implementation: `systems/levelb/Chapter7City.gd`, plus `levels/Chapter7.gd` integration. Instrumentation: `systems/PlaytimeTracker.gd`. Tests: `dev/ch7_city_test.gd`, and the Chapter 7 route in `scripts/qa_campaign_physical.gd`.

## Layout
All districts are inside the one existing city cavern (≈45 × 100 m). There are no new scenes and no loading between districts, so the city stays a single connected space that works with the unified-world streaming.

| District | Where | Main beat | Distinct mechanic | Reward / outcome |
|---|---|---|---|---|
| Central Plaza | (0, 0) | Read the mural; this opens the city objectives | Hub: paved ring, colonnade, wayfinding steles colour-coded to each district | Unlocks the seal objectives |
| Scholar's Quarter | (−13, 20) | Investigation: read the 3 archive tablets, then study the lectern | Clue-gathering. The tablets teach the hymn order (middle, deep, bright) | Seal 1 |
| Echo Gardens | (14, 24) | Sing the hymn on 3 tuned stones (size = pitch) | Ordered resonance. A wrong note resets; after 2 failures a hint points back to the archive | Seal 2 |
| Temple District | (−13, −12) | Light 4 braziers within 30 s of game time, then take the seal from the opened sanctum | Timed traversal across the courtyard | Seal 3 |
| Collapsed Aqueduct | (16, −4 … −21) | Optional: climb the 3 m stair, jump two 1 m deck gaps, open the sluice | Vertical traversal | Opens a shortcut gate behind the Meridian camp; 150 XP |
| Meridian Forward Camp | (0, −17) | Pull the causeway gate fuse | 3 patrolling mercenaries (15 m sight), low cover, stealth or combat | Gate power cut |
| Royal Causeway | (0, −25 … −45) | Portcullis opens with 3 seals plus the fuse cut | Full-width barricade: no way round | Exit to Ch8 |

## Optional tombs (replace the generic three-dial rooms in this chapter)
| Tomb | Where | Logic | Failure and recovery | Persisted |
|---|---|---|---|---|
| Hall of Weights | (−15, 34) | Move 1–4 talent weights between a pedestal, the left pan and the right pan. The pans tilt by the load difference. Equal and ≥ 5 a side lifts the inner gate | Reset lever | weights, solved |
| Sunken Archive | (16, 10) | Valves +3 / +2 / −1 raise or lower the water in 0.2 m marks. At mark 7 the floating chest meets the shelf | Overfilling past 9 drains the hall to 0 | level, solved |
| Resonant Chamber | (15, 38) | 4 resonators; turning one also turns its clockwise neighbour. All must face the crystal | Any state is reversible; start state proven solvable (turn #3 ×2, #4 ×3) | rotations, solved |

Each tomb has an in-world hint tablet and gives 300 XP plus an optional objective.

## Verification (this session)
**`dev/ch7_city_test.gd`: 34/34 PASS.** It covers:
- every district builds, and the dial tombs are gone
- the gating order, including the lectern refusing until all tablets are read
- a wrong hymn resets; the altar stays locked until the braziers are lit
- the gate stays shut until both the seals and the fuse are done
- all three tombs, including the overfill drain and unbalanced pans
- a full save-state round trip into a fresh city

**Physical bot (Xvfb, real input):** it clears the camp, reads the mural, collects all 3 seals, completes the brazier trial (game-time timer), pulls the fuse, opens the portcullis and exits to Ch8.
- Scoped Ch7 run: 306.9 m, 245 s of bot time.

**Bugs this testing found and fixed:**
- **Brazier timer:** it used wall-clock time, so slow frames ate the window. It now uses game time.
- **Opened doors:** they kept their collision while disabled. They're now freed.
- **Avenue pillar:** a plaza pillar blocked the main avenue. The ring is now rotated 22.5°.
- **Alcove:** archive alcove 3 faced backwards, which left its tablet outside the wall.
- **Sanctum lip:** a 0.3 m lip on the sanctum floor slab was a marginal step at the doorway, and Mara sometimes failed to climb it. It's now 0.1 m.

**Full campaign:** PASS, New Game → Credits through the new city (1181.4 m, up from 995 m). The bot's Ch7 active time from PlaytimeTracker was 116 s; the bot knows every answer, so this is a functional floor, not a player duration.

Screenshot (Plaza, Scholar's Quarter, Echo Gardens, Temple District, Meridian camp, Hall of Weights): `docs/visual_benchmark/ch7_city_districts.jpg`.

## Not done / honest gaps
- **No human playtest yet.** Per-district active time is now recorded to `user://playtime_c07.json` by `PlaytimeTracker` (idle >8 s excluded). Use that from a real playthrough before claiming any duration.
- **Untested paths:** the optional aqueduct traversal (jump gaps) and the three tombs are tested logically, not walked by the bot. Ch7 death/respawn mid-district hasn't been tested.
- **Visuals:** a moody cave city. It's readable after the lighting pass, but it still needs better flames, more architectural detail, and carved Vaelor wall pieces instead of textured boxes.
- **Assets:** no new online assets or Tripo3D generations were used this pass. It reuses the Poly Haven rock_wall_08 PBR, Poly Haven props and plants, and the existing Vaelor pillar and crystal models.
- **Subagents:** none were spawned. The work was done directly, to keep credit use down.
