# World Region Manifest

| Region (scene) | Chapter | Origin | Spawn (local) | Exit | Next | Connection | Checkpoint |
|---|---|---|---|---|---|---|---|
| Prologue.tscn | 0 | authored | (0,1,0) | ExitTrigger | Ch1 | fade (flash-forward → 72 h earlier) | chapter_01_start |
| Chapter1.tscn | 1 | authored | (0,1,20) | RidgeArea/ChapterEndTrigger | Ch2 | **passage** carved into the ridge | chapter_02_start (inside the entry passage) |
| Chapter2.tscn | 2 | authored | (0,1,15) | Sanctuary/AbyssTrigger | Ch3 | fade (abyss) | chapter_03_start |
| Chapter3.tscn | 3 | authored | (0,1,12) | FissureAbyssTrigger | Ch4 | fade (scripted fall) | chapter_04_start |
| Chapter4.tscn | 4 | authored | (0,1,20) | ExitTunnel/ExitTrigger | Ch5 | **passage** | chapter_05_start |
| Chapter5.tscn | 5 | authored | (0,1,25) | TempleEntrance (aqueduct) | Ch6 | **staged aqueduct** (co-present) | chapter_06_start |
| Chapter6.tscn | 6 | authored | (0,1.4,23) | TempleSanctum/ExitTrigger | Ch7 | **passage** | chapter_07_start |
| Chapter7.tscn | 7 | authored | (0,1,35) | RoyalCauseway/CausewayExitTrigger (gate needs 3 seals + fuse) | Ch8 | **passage** | chapter_08_start |
| Chapter8.tscn | 8 | authored | (0,1,20) | Passage/AdrianConfrontationTrigger | Ch9 | fade (betrayal) | chapter_09_start |
| Chapter9.tscn | 9 | authored | (0,1,30) | VaultThreshold/VaultGateTrigger | Ch10 | **passage** | chapter_10_start |
| Chapter10.tscn | 10 | authored | (0,1,35) | CentralPlatform/EscapeTrigger | Finale | fade (collapse) | chapter_11_start |
| Finale.tscn | 11 | authored | (0,1,30) | DaylightExitTrigger | Epilogue | story card (ending → credits) | — |

The exit table lives in `GameManager.IN_WORLD_EXITS`. Passage shape and waypoints are in `SeamlessPassage.WAYPOINTS`.
