# Character Physics Report: Foot IK, Pelvis, Ragdoll

## Foot IK (`_apply_foot_lock` in `scripts/Player.gd`)

- **Foot lock:** each low foot is pinned at its world touchdown point and lifted onto the ground found by a raycast. The leg is re-solved with the analytic 2-bone IK, keeping the animated knee plane.
- **Pelvis compensation:**
  - On slopes, stairs and rocks, the hips drop by the lower foot's ground offset (up to 0.3 m, eased).
  - The run stance and idle lift re-extend the legs.
  - A pelvis tilt of at most 8° handles the unequal idle legs.
- **New: foot alignment.** A planted foot's pitch and roll follow the ground normal, up to 30° (`foot_align_to_ground`, `foot_align_max_deg`).
- **Disabled outside ground states.** Only IDLE, WALK, RUN, SPRINT and CROUCH on the floor count as grounded. In JUMP, FALL, SWIM, CLIMB and MANTLE the feet unlock and the pelvis offset eases back to 0. The swim test measured a pelvis offset of 0.000.

| Case (LOW) | Result |
|---|---|
| Stand across a 15° slope | worst foot gap 0.007 m, pelvis −0.006 |
| Stand on a 30° slope | 0.000 m, pelvis −0.035 |
| Stand on a stair edge | 0.000 m |
| Walk up stairs / 15° slope / over the small rock | deepest penetration −0.000 m |
| Landings (1.6 m and 4.5 m drops) | feet stay on the ground (0.000) |
| Planted-foot slide (walk/run/sprint, movement tests) | 0.000 m/s |

**A regression caught along the way:** measuring plant height as clearance above the sole stopped feet from planting during strides, and the walk slide went to 2.5 m/s. I reverted to the clip's ankle height, and the slide is back to 0.

## Ragdoll

`scripts/Ragdoll.gd` is unchanged. Death still uses the 1.6 s ragdoll, and the procedural layers are skipped when the character is in the DEAD state.

## Unresolved

- Foot alignment uses a single ray under the ankle, so a toe hanging over a stair nosing isn't detected separately.
- There is no knee-collision check against tall rocks. The IK clamps only by leg length.
