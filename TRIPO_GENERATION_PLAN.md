# TRIPO3D GENERATION PLAN & BATCH QUEUE

## 1. Credit Economy & Optimization Strategy
- **Total Verified Credit Pool:** 1,800 Credits across 3 verified keys (600 + 600 + 600).
- Standard text-to-model cost: ~20 - 30 credits per model.
- Target asset batch allocation:
  - Phase 1 (Core Prototype & Prologue Assets): ~150 credits
  - Phase 2 (Ruins, Puzzles & Cave Modular Kit): ~250 credits
  - Phase 3 (Characters & Enemies): ~250 credits
  - Remaining pool: Retries, variations, and hero setpieces.

---

## 2. Generation Batch 1: Hero Relic & Environmental Baseline

### Batch 1 Targets:
1. `PROP_VAELOR_KEY`: "Ancient acoustic tuning key made of dark obsidian and engraved bronze, geometric soundwave runes, archaeological relic artifact, isolated on neutral background, realistic PBR materials, high detail."
2. `ENV_ROCK_BOULDER_01`: "Weathered limestone cave boulder approximately 2 meters wide, naturally fractured irregular silhouette, wet lower surface, subtle moss on upper crevices, realistic geological erosion, neutral pose, isolated 3d model."
3. `RUIN_PILLAR_BROKEN_01`: "Ancient weathered stone pillar broken at the top, cylindrical with carved geometric spiral relief, ancient ruin architecture, realistic stone texture, isolated 3d model."
4. `PROP_CAMP_CRATE_01`: "Weathered heavy-duty military expedition storage crate, olive drab and faded metal with latches and handles, modern adventure gear, isolated 3d prop."

---

## 3. Automation Runner
Assets will be generated sequentially using `scripts/tripo_client.py`, automatically saved to `d:/new-dev/assets/models/`, and imported directly into Godot's resource pipeline.
