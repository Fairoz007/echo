# Seamless Transition QA

| Boundary | Mode | Test | Result | Notes |
|---|---|---|---|---|
| Ch5 → Ch6 | RegionHandoff | `dev/region_handoff_test.gd` (Xvfb) | **PASS** on 12 checks | Scenery swaps at the threshold (no connector yet). Swap frame 4.1 s in software GL. |
| All others | Story card + scene swap | `scripts/qa_campaign_physical.gd` | See `PRODUCTION_STATUS.md` | Not seamless |

Visual evidence was checked this session: `handoff_before.png` shows the Ch5 ruin gate; `handoff_after.png` shows the Ch6 landing with the same HUD and subtitle. The images are scratch only, not committed.
