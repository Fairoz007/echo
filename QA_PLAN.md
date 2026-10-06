# QA PLAN & TEST SUITE: ECHOES BENEATH

---

## 1. Test Categories & Verification Protocols

### A. Smoke & Headless Engine Tests
- Engine launches with zero fatal errors or unresolved script dependencies.
- All autoload singletons (`GameManager`, `SaveManager`, `MissionManager`, `AudioManager`) initialize within 50ms.
- Input map actions (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `crouch`, `interact`, `aim`, `fire`, `flashlight`, `journal`) load properly.

### B. Player Controller & Traversal Regression
- Movement velocity reaches target speeds (Walk: 1.8 m/s, Run: 4.5 m/s, Sprint: 7.0 m/s).
- Collision capsule properly handles slopes up to 45 degrees without jittering.
- Mantling shapecast detects 1.0m to 2.2m obstacles and smoothly transitions to ledge climb.
- Camera SpringArm collides smoothly with geometry without clipping into character mesh.

### C. Game Loop, Save/Load & State Persistence
- Game state properly transitions from Main Menu -> Prologue -> Gameplay.
- Checkpoint triggered -> writes JSON file to `user://save_slot_*.json`.
- Die or reload -> reads JSON file, restores exact checkpoint coordinates, vitals, inventory, and completed puzzle flags.

### D. Automated Playthrough Protocol
- Python automated runner launches Godot instance with `--headless` or `--playtest` arguments, simulating player input sequences and verifying objective completion signals until credits screen.
