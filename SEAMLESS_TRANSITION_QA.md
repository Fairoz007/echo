# Seamless Transition QA

## Ch5 → Ch6: walkable Meridian aqueduct
These numbers come from `dev/region_handoff_test.gd` (Xvfb, LOW, real move input) and **all checks PASS**:
- **Build in Ch5:** saving works before staging. Reaching the perch stages Ch6, which builds while Mara is still in Ch5. Saving is refused while the old region is rebased.
- **The walk:** Mara walks perch → gate → leg A → chamber → leg B. Ch6 activates out of sight, and she arrives on the landing floor.
- **Continuity:** the same Player and HUD instances carry over. Health and ammo are preserved, and the Ch6 objective is active.
- **Cleanup:** Ch5 is released and exactly one player remains. Wind switches to CAVE, and the Ch6 Soundscape is running.
- **Frame time:** no frame exceeds 1.5× this renderer's own Ch5 baseline. Software GL here runs a median 1268 ms and worst 1958 ms per frame; the worst frame during the walk and activation was 1771–1886 ms.
- **Save/load in Ch6:** saving in Ch6, loading, and reloading standalone Ch6 restores the position within 0.01 m. The aqueduct is sealed by a rockfall in standalone Ch6.

Full physical campaign PASS through the aqueduct (999 m, Xvfb).

### Main-thread cost: before → after
| Stage | Before | After |
|---|---|---|
| Ch6 scene and asset load at the threshold | 2073 ms blocking | 6–10 ms. Background prefetch starts at Ch5 `_ready`; the manifest now resolves `DIR + "file.glb"` constants. |
| Ch6 dressing build | one 3–5 s block | Spread over ~15 frames. Every step is ≤137 ms CPU (terrain 137, machinery 3, hero props 1). |
| Aqueduct, collision, blockout, exploration | — | 9, 0, 3, 4 ms |

Screenshots checked: `seam_01_gate.png` (cave mouth in the rock face), `seam_02_QA_AqA/B.png` (masonry aqueduct, Ch6 glow visible ahead), `seam_03_landing.png` (Mara between the doorway pillars, looking into the flooded hall). Scratch only, not committed.

### Known remaining
- **Hardware:** frame timing hasn't been measured on real GPU hardware. Here, rendering dominates every frame.
- **Lighting:** the environment and directional-light swap happens at activation, mid-tunnel. Its visual effect is masked by the tunnel lamps but isn't cross-faded.
- **Audio:** Ch5 ambience fades over 1.5 s. Ch6 audio starts at activation without a fade-in.
- **Placement:** the doorway infill is plain stone boxes in the Ch6 hall material, not carved Vaelor wall pieces.
- **Death and respawn while staged** hasn't been tested.

## Other boundaries
Still use the story card and scene swap.
