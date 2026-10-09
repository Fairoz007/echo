# Controls Report

## Files
- `systems/InputRemap.gd`: new autoload, registered in `project.godot` as `InputRemap="*res://systems/InputRemap.gd"`.
- `ui/controls/ControlsMenu.gd` and `ControlsMenu.tscn`: the Controls screen, built on the shared GameTheme.
- `ui/PauseMenu.gd`: the Controls tab now has a "Customize controls…" button and a summary of the current bindings. Closing the pause menu also closes the Controls screen.
- `dev/controls/controls_test.gd` and `controls_test.tscn`: the test. Add `--shot` to capture screenshots.
- Screenshots: `screenshots/ui/controls_{menu,capture,conflict,scrolled}.png`.

## InputRemap API
- Bindings use two slots per action: `SLOT_KBM` (0, keyboard and mouse) and `SLOT_PAD` (1, gamepad). The functions are:
  - `rebind(action, event, slot=-1, on_conflict="cancel"|"swap"|"steal") -> {ok, conflict}`
  - `find_conflict`, `unbind`, `reset_action` and `reset_all(include_options=true)`
  - `get_event`, `default_event`, `is_default`, `event_label` and `action_label`
- Defaults are captured from `project.godot` at startup.
  - The autoload also adds keyboard and mouse defaults for the actions `Player.gd` creates at runtime (reload, melee, walk, dive, fire, aim). Player skips actions that already exist, so its behaviour doesn't change.
  - It adds Xbox-layout gamepad defaults for all 16 actions. The project had no gamepad bindings before this.
- Crouch and dive may share a key, as they did by default.
- Options are stored as properties and emit `changed`:
  - `mouse_sensitivity` (multiplier)
  - `invert_y`
  - `stick_sensitivity`
  - `deadzone`, applied to the InputMap deadzone of every action
  - `toggle_sprint`, `toggle_crouch` and `toggle_aim`
  - `fov`
- Toggle mode works without editing Player: a fresh press latches the action through `Input.action_press` and the next press releases it.
- Settings persist in `user://controls.cfg`, in the sections `[kbm]`, `[pad]` and `[options]`. They are loaded on startup and saved on every change in the screen.

## What already works with no hooks
- **Bindings, deadzone and toggle modes:** all applied.
- **Mouse sensitivity and FOV:** InputRemap finds each `CameraController` as it enters the tree and sets `mouse_sensitivity` to 0.003 × the multiplier and `camera.fov`. It does the same again on every change.

## Hooks needed in files I don't own
1. **Invert Y (`scripts/CameraController.gd`, Movement owner):** in `_input`, replace `pitch -= motion.y * mouse_sensitivity` with:
   ```gdscript
   pitch -= motion.y * mouse_sensitivity * (-1.0 if InputRemap.invert_y else 1.0)
   ```
2. **Gamepad camera look and stick sensitivity (`CameraController.gd`):** there is no gamepad look today. At the top of `_physics_process`, add:
   ```gdscript
   if not get_tree().paused:
   	var look: Vector2 = InputRemap.get_look_vector()  # deadzone, invert and sensitivity applied
   	yaw -= look.x * 3.0 * delta
   	pitch = clamp(pitch - look.y * 2.2 * delta, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
   ```
3. **Main menu Settings (`ui/MainMenu.gd`, UI owner):** in `_on_settings_pressed`, add a button to the Controls tab:
   ```gdscript
   preload("res://ui/controls/ControlsMenu.gd").open(self)
   ```
   `open()` returns the screen; connect to its `closed` signal to restore focus.

## Tests (LOW)
- `dev/controls/controls_test.tscn` passes 24 of 24 checks headless. The checks cover:
  - defaults
  - keyboard and gamepad rebinds that leave the other slot alone
  - conflict cancel and swap, on both keyboard and gamepad
  - rejection of an event in the wrong slot
  - save, then reset all, then reload, verifying the InputMap and the options
  - deadzone applied
  - per-action reset
  - the sprint toggle latching and releasing
- The test writes to `user://controls_test.cfg` and restores the real config afterwards.
- The screenshots were reviewed at full size. Polish done after review:
  - scrollbar gutter
  - column alignment
  - journal moved into the Actions group
  - conflict message shown in the status line
- `dev/parse_all.tscn`: `PARSE_DONE bad=0`.

## Not verified
- A real gamepad.
- Capturing by hand in a running game. The test feeds simulated input.
