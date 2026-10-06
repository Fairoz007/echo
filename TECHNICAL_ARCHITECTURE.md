# TECHNICAL ARCHITECTURE: ECHOES BENEATH

**Target Engine:** Godot Engine 4.7.2 Forward+ (D3D12, Jolt Physics 3D)  
**Language:** GDScript 2.0 (Type-annotated, high-performance static typing)  

---

## 1. Core System Singletons (Autoloads)

1. `GameManager.gd` (`systems/GameManager.gd`)
   - Global game state manager: `STATE_MENU`, `STATE_CUTSCENE`, `STATE_GAMEPLAY`, `STATE_PAUSED`, `STATE_GAMEOVER`.
   - Level streaming and scene loading with asynchronous background resource loading.
   - Chapter and mission coordination.

2. `SaveManager.gd` (`systems/SaveManager.gd`)
   - JSON-serialized versioned game saves (`user://save_slot_0.json`, etc.).
   - Checkpoint state: player position, camera pitch/yaw, health, skills, inventory, puzzle states, and objectives.

3. `MissionManager.gd` (`systems/MissionManager.gd`)
   - Reactive objective tree: Main Objectives, Sub-objectives, Optional Discoveries.
   - Signal bus: `objective_updated`, `checkpoint_reached`, `chapter_completed`.

4. `AudioManager.gd` (`systems/AudioManager.gd`)
   - 3D spatial sound bus routing: Master, Music, Ambience, SFX, Footsteps, Dialogue.
   - Dynamic cross-fading adaptive music states.

---

## 2. Character & Traversal Controller (`player/Player.gd`)
- Inherits `CharacterBody3D`.
- **State Machine:**
  - `IDLE`, `WALK`, `RUN`, `SPRINT`, `CROUCH`, `JUMP`, `FALL`, `VAULT`, `MANTLE`, `LEDGE_HANG`, `LEDGE_SHIMMY`, `SWIM`, `SWIM_DIVE`, `INTERACT`, `COMBAT_AIM`, `DEAD`.
- **Traversal Raycasts & Shapecasts:**
  - Wall collision check, Ledge top probe, Mantle height probe, Vault clearance probe, Water body detector.
- **Camera Controller (`player/CameraController.gd`):**
  - SpringArm3D with progressive collision avoidance, shoulder-swap toggle, dynamic FOV interpolation based on movement speed and combat aiming.

---

## 3. Interaction Framework (`systems/Interaction/`)
- `Interactable3D.gd`: Base node with customizable prompt text, hold duration, and interact callback.
- Player proximity detector (`Area3D` sphere) auto-sorts closest interactable object and emits UI prompts.

---

## 4. Reusable Puzzle Framework (`systems/Puzzle/`)
- `PuzzleComponent.gd`: Base class emitting `state_changed(is_solved)`.
- Components: `PressurePlate.gd`, `CounterweightPulley.gd`, `SluiceGate.gd`, `AcousticTuningLock.gd`, `RotatingPillar.gd`.
- `PuzzleMaster.gd`: Combines multiple components into logic gates (AND, OR, SEQUENCE) to trigger physical world reactions (e.g., lowering heavy stone gates, filling aqueducts).

---

## 5. Enemy AI Architecture (`ai/EnemyBase.gd`)
- State machine: `PATROL`, `SUSPICIOUS`, `INVESTIGATE`, `ALERT`, `COMBAT`, `TAKE_COVER`, `SEARCH`, `DEAD`.
- Vision cone using forward Raycasts + dot product cone math.
- Sound perception listener hookable to player sprint/footstep volume.
- NavMeshAgent3D for path calculation and flank routing.

---

## 6. Rendering & Foliage Performance Architecture
- Forward+ clustered lighting with DirectionalLight3D cascades.
- MultiMeshInstance3D procedural grass and foliage blades clustered in 32x32m chunks for zero draw-call overhead.
- Distance-based LOD culling and visibility ranges.
