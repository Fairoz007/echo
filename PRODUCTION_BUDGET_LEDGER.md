# Production Budget Ledger — $100 ceiling

## Verified facts (2026-10-10)
- **The agent can't read the balance.** This cloud session has no API for querying model-credit balance or per-call cost. The user must read actual spend from the claude.ai usage page. No dollar figure in this file is a vendor-measured number.
- **Tripo3D and ElevenLabs bill separately** from model credits. Their last known balances are in `CONTINUE_CONTEXT.md` §2. They weren't re-queried here because their keys live only in the Windows DPAPI store.
- **No Tripo or ElevenLabs credits were spent this session.**

## Planned allocation (planning figures, not prices)
| Category | Planned | Logged spend | Notes |
|---|---:|---:|---|
| Baseline inspection and planning | $8 | not measurable | Headless Godot 4.7.2 is now running in the cloud container |
| Level design and 10-hour expansion | $28 | — | |
| Art direction and asset sourcing | $16 | — | |
| Gameplay, animation and systems | $18 | — | |
| Cinematics, audio and UI | $10 | — | |
| Continuous QA and performance | $12 | — | |
| Final regression and reserve | $8 | — | |
| **Total** | **$100** | | |

## Gates
Check the usage page at $25, $50, $75 and $90 of actual spend, per the directive. Until then, the session works single-agent, with no subagents and no paid generation, to keep the spend per change low.
