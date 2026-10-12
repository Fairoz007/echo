# Character Animation Audit — Mara

## Rig
41 bones (Tripo naming). There are no finger bones. In skeleton space Mara faces +X and +Z is lateral.
Clips: idle, walk, run, swim, climb, dive, fall, jump.

## Measured root causes of stiffness
Maximum rotation from the first key, in degrees:

| Clip | Upperarm L/R | Forearm | Spine01 | Head |
|------|--------------|---------|---------|------|
| idle | 0 / 0 | 0 | 0 | 0 |
| walk | 20 / 26 | 17 | 4 | 5 |
| run | 88 / 55 | 87 | 12 | 22 |
| swim | 74 / 68 | 70 | 2 | 9 |

- **Idle:** the clip is completely static, and the rig's rest pose is an A-pose with the arms held away from the body.
- **Walk:** the clip has a weak arm swing and almost no torso counter-rotation.
- **Reused clips:** sprint uses run; land, crouch_idle and swim_idle use idle or swim; mantle uses climb.

## Fixes (procedural layers in `Player._apply_body_layers`, run after the AnimationTree mixer)
- **Idle life:**
  - Slow pelvis weight shift with a counter-roll in the torso.
  - Head drift.
  - Relaxed elbows and arm sway.
  - Breathing (already present).
- **Arm relax:** the upper arms are rotated in 12° from the A-pose toward the thighs, during idle and walk.
- **Walk layer:**
  - A ±14° arm swing locked to the leg phase. The forward half is shorter than the back half.
  - A soft elbow bend (20°, deeper on the forward arm).
  - A 5° shoulder/pelvis counter-twist.
  - The walk layer cross-fades out as the existing run posture layer takes over above 1.7 m/s.
- **Run/sprint:** the existing posture layer is kept as is (lean, elbow-bent swing, head stabilisation).

## Verification
- `dev/movement_tests.gd`: 54/54 PASS.
- `dev/anim_capture.gd -- --only-walk`: an idle quarter view over 10 s, plus walk side and front sequences. Contact sheets were reviewed; the hands do not cross the body midline (0.000 m).

## Still open
- Chapter 6 swim polish: treading pose, dive and surface transitions.
- Strafe/backward-specific poses, start/stop.
- Procedural crouch, mantle, reload and interaction poses.
- No licensed clip pack was downloaded in this pass.
