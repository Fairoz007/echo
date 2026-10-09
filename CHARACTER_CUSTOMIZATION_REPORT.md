# Character Customization Report

All tests ran on LOW (gl_compatibility/opengl3, 1280x720, `--quality=1`), through the shared lock. No Tripo credits were spent.

## What was added
| File | Purpose |
|---|---|
| `systems/MaraAppearance.gd` (autoload, one line in `project.godot`) | Profile in `user://appearance.cfg`. It applies the profile to the player and to any Mara rig. |
| `ui/customize/CustomizeScreen.gd/.tscn` | The Customize screen. |
| `ui/MainMenu.gd/.tscn` | Adds a **CUSTOMIZE MARA** button. Settings now has a **Controls** button that calls `ControlsMenu.open(self)` and refocuses Settings on `closed`. |
| `dev/customize/customize_capture.gd`, `mask_probe.gd`, `mara_probe.gd`, `run.sh` | Capture and probe harnesses. |

## How it works
- **Recolor.** Mara has one atlas material, so a ShaderMaterial (`material_override`) reuses her Color, Normal and ORM textures. It sorts texels by HSV, sampled at mip +1.5 to reduce speckle:
  - **Skin:** warm, mid saturation, bright.
  - **Hair:** warm, highly saturated, dark.
  - **Jacket:** olive hues.
  - **Pouches and trim:** tan, low saturation.

  Each class is retinted with its luminance preserved. Swatch colors are linearised in the shader, because the `source_color` uniforms were not linearised on Compatibility. When the profile has no recolor, the original imported material is kept.
- **Hair is only partly separable.** It shares the texture with leather trims. Strong hair colors leave some speckle from the original color, especially blonde over the dark base. The UI tells the player this.
- **Accessories.** Hat, headlamp (with an emissive lens), backpack (on Spine02) and satchel (on Spine01) are procedural meshes on `BoneAttachment3D` nodes. They are authored in skeleton space and converted into each bone's rest frame. Head items are offset for the head bone's +0.062 X origin.
- **Body.** Scaling is on the `Skeleton3D` node only: height 0.96–1.01 (at most 1.717 m, inside the 1.72 m capsule) and build 0.94–1.06. The capsule and camera are untouched.
- **Discovery.** `node_added` catches any Skeleton3D under the player group or a `/characters/mara/` scene and applies the profile one frame later, after Player's height normalisation. `skeleton_of()` uses `get_skeleton()`/`get_visual_root()` when they exist and falls back to `find_child("Skeleton3D")`.
- **Graphics presets.** On ULTRA LOW/LOW the preview has no shadows, no MSAA, a single key light and higher ambient. MEDIUM and above add shadows and a rim light.

## Customize screen
- Preview in a SubViewport playing the looping `idle` clip.
- Tabs: Outfit (6 palette presets, jacket and trouser swatches, strength slider), Skin & Hair (swatches and blend sliders), Gear (4 toggles) and Body (height and build).
- Buttons: Randomize, Reset, Save, Back. Back discards unsaved edits.
- Mouse: drag to orbit, wheel to zoom.
- Keyboard: Q/E orbit, R/F zoom, PgUp/PgDn change tab, arrows and Enter navigate, Esc goes back.
- Gamepad: right stick orbits and zooms, LB/RB change tab, D-pad and A navigate, B goes back.

## Verification (LOW)
- `dev/parse_all.tscn`: **PARSE_DONE bad=0**. The parse failure another agent reported was a mid-edit state and does not reproduce.
- Screenshots in `screenshots/customize/`:
  - `cust_default`, `cust_custom_*` and `cust_tab1-3` for the screen.
  - `ingame_Chapter1`, `ingame_side` and `ingame_front` for Ch1 with Glacier, a dark skin tone, blonde hair, all 4 accessories and build 1.04.
  - The in-game log confirms skeleton scale (1.04, 1, 1.04) and 4 attachments.
- Fixed during testing:
  - Hair was being caught by the trouser mask.
  - The face was outside the skin mask.
  - Swatches looked washed out because of the sRGB/linear mixup.
  - Hat and headlamp sat behind the head and the headlamp band floated.
  - The backpack had a gap at the back.
  - The preview hint label was clipped.

## Known limits
- Hair recolor is approximate.
- Light jacket colors keep some dirt speckle from the original texture.
- The procedural accessories are blocky placeholders; they could be replaced with Tripo props later.
- The trousers are grey-brown and have low saturation, so they are mostly left unchanged; only tan pouches and trim take the secondary color.
- Not yet tested with a real gamepad.
