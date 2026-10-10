# Ten-Hour Gameplay Audit

Audited 2026-10-10 on branch `claude/echoes-beneath-campaign-polish-d9lawx`, from the level scripts, the `.tscn` files and an automated campaign run. No human has played the game, so **no chapter has a measured playtime**.

## Bottom line
- **Duration:** the automated bot finishes New Game → Credits in **890 s (14.8 min)** and walks 830 m (`scripts/qa_campaign_physical.gd`, Xvfb, LOW). It knows every answer and skips optional content, so this is a floor, not a playtime.
- **Estimate (not a measurement):** a first-time player who does the optional dial tombs would plausibly take about **1.5 to 2.5 hours**. **The 600-minute target is roughly 8 hours short.**
- **Shortfall:** the gap is content, not polish. Most chapters are one objective chain of 1 to 5 steps. All the "optional tombs" are the same three-dial room template (`systems/CampaignExploration.gd` + `content/exploration.json`, 3 per chapter for Ch1–Ch10). Only Ch5 has enemies.

## Per chapter (static content counts)
| Chapter | Target | Enemies | Interactables | Collectibles | Objective steps | Tombs (template) | Main gap |
|---|---:|---:|---:|---:|---:|---:|---|
| Prologue | 20 | 0 | 2 | 0 | ~2 | 0 | Short linear cave; no traversal tutorial beats |
| 1 Arrival | 45 | 0 | 5 | 2 | ~4 | 3 | Camp exists, but little to do there; no ridge route |
| 2 Whispers | 45 | 0 | 3 | 0 | ~3 | 3 | One hydraulic interaction; no layered puzzle |
| 3 The Fall | 35 | 0 | 0 | 0 | 1 | 3 | Bridge collapse is a single trigger, not a set piece |
| 4 Beneath | 50 | 0 | 2 | 0 | ~2 | 3 | No branching caves, squeezes or rope |
| 5 Hunters | 55 | 2 (+1 dressing) | 0 | 2 | 3 | 3 | **Only combat chapter.** Stealth route added this session |
| 6 Drowned Temple | 60 | 0 | 2 | 2 | ~2 | 3 | One sluice wheel; no multi-stage water puzzle |
| 7 City of Echoes | 105 | 0 | 2 | 0 | ~2 | 3 | Hub districts don't exist yet |
| 8 Betrayal | 40 | 0 | 2 | 2 | ~2 | 3 | Investigation and clue beats missing |
| 9 Heart Road | 55 | 0 | 0 | 0 | 1 | 3 | No occupation, hazards or combat |
| 10 Heart Vault | 55 | 0 | 5 | 0 | 5 | 3 | Four nodes exist; no Drake fight |
| Finale | 25 | 0 | 0 | 0 | ~1 | 0 | Escape is a short run |
| Epilogue | 10 | 0 | 0 | 0 | 0 | 0 | Dialogue only |

Method for the static counts:
- **Enemies:** `EnemyMercenary` instances in the `.tscn`.
- **Interactables:** `Interactable3D` nodes.
- **Collectibles:** `collectible(` calls in the level script plus its dressing script.
- **Objective steps:** read from the level scripts.

## Systems that exist and work (verified this session)
- Movement suite 54/54.
- Story flow PASS.
- Full physical campaign PASS. It needs a window: under `--headless` the mouse can't be captured, so combat aim never moves (see `CONTINUOUS_QA_LEDGER.md` QA-002).
- Crouched melee from behind is a one-hit takedown (`Player.gd` `melee_attack`).
- Enemies have patrol, suspicious, alert and combat states, with crouch halving their sight range (`EnemyBase.gd`).

## Visual evidence
- Ch6 spawn before and after the camera fix: `dev/ch6_spawn_capture.gd`. The renders were checked this session but not committed (scratch only).
- Every other chapter still needs a rendered inspection pass. This audit doesn't approve any chapter visually.

## Recommended content priority (impact per effort)
1. **Ch7 hub.** It's 105 of the 600 minutes. Build districts with real activities, reusing existing Vaelor kit assets.
2. **Spread combat and stealth beyond Ch5,** using the existing EnemyBase and takedown, into Ch4 (Meridian traces), Ch8 (camp), Ch9 (occupation) and Ch10 (Drake).
3. **Replace the copy-paste dial tombs with distinct puzzle types** built on systems that already exist: water level (Ch6), pressure plates (`PressurePlate.gd`), resonance nodes (Ch10).
4. **Turn the Ch3 collapse and the Finale into playable set pieces.**
