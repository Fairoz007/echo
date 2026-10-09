# Character Rigging Report: Mara

## Rig decision

I repaired the existing rig. Nothing was regenerated and **no Tripo credits were spent**.

The rig is `assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb`, with 41 bones, one skinned mesh of 39.8k vertices and 8 clips. No asset files changed. The full inventory and gap list are in `CHARACTER_BASELINE_AUDIT.md`.

## Public API added (`scripts/Player.gd`)

These are for the customisation agent:

- `get_skeleton() -> Skeleton3D` returns Mara's Skeleton3D. It is resolved lazily, so it is safe to call before `_ready` finishes.
- `get_visual_root() -> Node3D` returns `visual_mesh` (the `VisualRoot` node). It carries the yaw and the step-smoothing offset, and it contains the model.
- `_ready()` now adds the node to group `"player"` if a level didn't already. All levels and `scenes/Player.tscn` already had it.

The following were also added:

- `play_hit_reaction(from_dir, strength)`
- `play_interact_reach(target)`
- `take_damage(amount, from_dir := Vector3.ZERO)`. The new argument is optional, so existing callers are unchanged.

## Procedural layers (on `AnimationTree.mixer_applied`)

They run in this order:

1. `_apply_crouch_pose` (existing)
2. `_apply_run_posture` (existing, with the leading-arm fix)
3. `_apply_body_layers` (**new**): idle breathing, landing squash, hit reaction, turn-in-place upper-body lead
4. `_apply_foot_lock` (existing, extended): foot IK, pelvis compensation, foot-to-ground alignment
5. `_apply_hand_ik` (**new**): climb wall contact, mantle ledge contact, interact reach

`_solve_leg` is now a generic 2-bone solver with a pole fallback, and the arms reuse it.

## Known rig limits (unresolved)

- **No finger bones.** Grip, point and fist poses can't be made. The hands keep the clip's open pose.
- **Unequal leg lengths.** The right leg is slightly longer than the left. The idle stance compensates with a pelvis tilt of at most 8°.
- **LOD1–LOD3 are unused** by the player.
