# Unified World Architecture (2026-10-12)

## Root cause of "the chapter ends, a popup appears, and the game starts again"
Traced in code. It was the chapter-change design, not a stray bug:
1. A level's exit calls `GameManager.load_chapter(next)`.
2. `_transition_to` shows the full-screen story card (`ui/StoryTransition.gd`: "Loading…", then "Space / Enter to continue") and pauses the tree.
3. It replaces the whole scene with `change_scene_to_packed`, so a brand-new Mara spawns at the next level's authored start.
4. `_on_scene_changed` then writes a checkpoint at that start.

Separately, death opens the pause menu in GAME_OVER mode (`handle_player_death`). That is intended and unchanged.

## What changed
`GameManager.load_chapter` now advances **in the running world** whenever it's called during gameplay for the next chapter (`_advance_in_world`). The story-card path is used only for the main menu (New Game, chapter select), Continue / checkpoint restore, and Finale → Epilogue (the credits scene).

| Mode | Used for | What happens | Code |
|---|---|---|---|
| **Passage** | Walkable exits: Ch1→2 (ridge portal), Ch4→5 (exit tunnel), Ch6→7 (temple gate), Ch7→8 (Royal Causeway), Ch9→10 (Vault threshold) | An S-bend passage (`SeamlessPassage`) opens at the exit. When Mara reaches its middle leg, where neither mouth is visible, the next region is instanced with an identical passage behind its spawn. The old region is rebased (rotation included) so both passages coincide. Mara, the camera and the HUD move across, and the old region is released. | `RegionHandoff.hand_off_passage` |
| **Staged aqueduct** | Ch5→6 | Unchanged from before: co-present regions with a step-by-step build and activation mid-aqueduct | `RegionHandoff.stage/activate`, `Ch5Ch6Aqueduct` |
| **Fade** | Scripted transitions: Prologue→Ch1 (72 h flashback), Ch2→3 (abyss), Ch3→4 (fissure fall), Ch8→9 (betrayal), Ch10→Finale (collapse) | Mara is frozen, a 0.6 s fade plays, the next region is built, the **same Mara** is placed at its spawn (fall speed reset), then it fades back in | `RegionHandoff.hand_off_fade` |

Every mode shows a non-blocking chapter title (`RegionHandoff.show_title`), needs no input, and saves a checkpoint after the boundary.

**Passage geometry and seams** (`SeamlessPassage.clear_volume`): region art inside the tunnel volume is hidden and loses its collision. This includes CSG blockouts and arches straddling the mouth. The ground under the mouth is protected; where it's a heightmap, concave mesh or terrain mesh crossing the tunnel, it's **carved** below the tunnel floor instead.

**Standalone loads:** a region loaded on its own (Continue, chapter select) builds the same entry passage with a rockfall sealing the far end (`GameManager._ensure_entry_passage`), so save positions inside a passage stay valid.

## Why rebasing regions rather than one giant scene
- Each region keeps its authored origin, so existing saves, checkpoints, triggers and level scripts stay valid with no migration.
- Only the current region (plus the next one, briefly) is in memory.
- Float precision stays good.

The trade-off: there's no long-distance view from one region into another; the passages hide the joins.

## Not done (honest)
- **Geography:** regions are joined by passages, not authored into one continuous geography with roads, rivers and vistas. The Ch5→6 aqueduct is the only bespoke connector.
- **Main-thread hitch at passage swaps,** measured in this software-GL container: Ch2 ≈ 25–40 ms, Ch8 ≈ 0.3 s, Ch10 ≈ 35 ms, Ch5 ≈ 1.2–2.4 s, **Ch7 ≈ 6.7–7.1 s**. Ch5 and Ch7 still build their art synchronously; they need the step-by-step staged build Ch6 already uses. Real-GPU numbers haven't been measured.
- **Fade boundaries** teleport Mara (allowed for scripted falls and cinematics, but not physically continuous).
- **No unified world map UI** yet.
- **No stable-ID save migration:** saves stay per-region and keyed by scene. Old chapter-based saves keep working because each region is unchanged at its origin.
- **Untested:** death and respawn after an in-world boundary hasn't been specifically tested.
