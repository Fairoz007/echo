extends Node

## Controls test. Run as a scene (autoloads must be live):
##   godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --resolution 1280x720 [--headless] res://dev/controls/controls_test.tscn -- --quality=1 [--shot]
## --shot also captures screenshots/ui/controls_*.png (needs a window, not --headless).
const TEST_CFG := "user://controls_test.cfg"
var fails := 0
var R: Node

func check(cond: bool, what: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1

func key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k

func pad(btn: int) -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = btn
	return b

func bound(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if R.same_event(e, ev):
			return true
	return false

func _ready() -> void:
	R = get_node("/root/InputRemap")
	var shot := "--shot" in OS.get_cmdline_user_args()
	var real_cfg: String = R.config_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	R.load_config(TEST_CFG)  # no file -> defaults
	print("[CONTROLS] defaults")
	check(bound("jump", key(KEY_SPACE)), "jump default Space")
	check(bound("jump", pad(JOY_BUTTON_A)), "jump default pad A")
	check(bound("reload", key(KEY_R)) and bound("fire", R.default_event("fire", 0)), "runtime actions have defaults")
	check(R.find_conflict("dive", key(KEY_C)) == "", "crouch/dive may share C")

	print("[CONTROLS] rebind + conflict")
	check(R.rebind("jump", key(KEY_K)).ok, "rebind jump -> K")
	check(bound("jump", key(KEY_K)) and not bound("jump", key(KEY_SPACE)), "jump now K only (kbm slot)")
	check(bound("jump", pad(JOY_BUTTON_A)), "jump pad slot untouched")
	var r: Dictionary = R.rebind("jump", key(KEY_E))
	check(not r.ok and r.conflict == "interact", "E conflicts with interact (cancel)")
	check(bound("jump", key(KEY_K)) and bound("interact", key(KEY_E)), "cancel left bindings intact")
	r = R.rebind("jump", key(KEY_E), -1, "swap")
	check(r.ok and bound("jump", key(KEY_E)) and bound("interact", key(KEY_K)), "swap jump<->interact")
	check(R.rebind("sprint", pad(JOY_BUTTON_RIGHT_SHOULDER), R.SLOT_PAD, "cancel").conflict == "melee", "pad conflict RB with melee")
	check(R.rebind("sprint", pad(JOY_BUTTON_Y), R.SLOT_PAD, "swap").ok and bound("reload", pad(JOY_BUTTON_LEFT_STICK)), "pad swap sprint<->reload")
	check(not R.rebind("sprint", key(KEY_Z), R.SLOT_PAD).ok, "key rejected for pad slot")

	print("[CONTROLS] options + save/reload")
	R.mouse_sensitivity = 1.75
	R.invert_y = true
	R.deadzone = 0.33
	R.toggle_crouch = true
	R.fov = 88.0
	check(R.save_config(), "save_config")
	R.reset_all()
	check(bound("jump", key(KEY_SPACE)) and R.fov == 75.0 and not R.invert_y, "reset_all restores defaults")
	R.load_config(TEST_CFG)
	check(bound("jump", key(KEY_E)) and bound("interact", key(KEY_K)), "reloaded kbm bindings")
	check(bound("sprint", pad(JOY_BUTTON_Y)), "reloaded pad binding")
	check(is_equal_approx(R.mouse_sensitivity, 1.75) and R.invert_y and R.toggle_crouch and is_equal_approx(R.fov, 88.0), "reloaded options")
	check(is_equal_approx(InputMap.action_get_deadzone("move_forward"), 0.33), "deadzone applied to InputMap")
	check(is_equal_approx(R.get_mouse_sensitivity(), 0.003 * 1.75), "effective mouse sensitivity")

	print("[CONTROLS] reset per action")
	R.reset_action("jump")
	check(bound("jump", key(KEY_SPACE)) and bound("jump", pad(JOY_BUTTON_A)) and R.is_default("jump"), "reset_action jump")
	check(bound("interact", key(KEY_K)), "reset_action leaves others")

	print("[CONTROLS] toggle mode")
	R.toggle_sprint = true
	var e := key(KEY_SHIFT); e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	await get_tree().process_frame
	var up := key(KEY_SHIFT); up.pressed = false
	Input.parse_input_event(up); Input.flush_buffered_events()
	await get_tree().process_frame
	check(Input.is_action_pressed("sprint"), "toggle sprint latched after release")
	Input.parse_input_event(e.duplicate()); Input.flush_buffered_events()
	await get_tree().process_frame
	Input.parse_input_event(up.duplicate()); Input.flush_buffered_events()
	await get_tree().process_frame
	check(not Input.is_action_pressed("sprint"), "second press releases sprint")
	R.toggle_sprint = false

	print("[CONTROLS] camera integration")
	var rig := CameraController.new()
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	arm.add_child(camera)
	rig.add_child(arm)
	add_child(rig)
	rig.set_physics_process(false)
	await get_tree().process_frame
	check(is_equal_approx(rig.mouse_sensitivity, R.get_mouse_sensitivity()) and is_equal_approx(camera.fov, R.fov), "saved camera sensitivity and FOV applied")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, 10)
	R.invert_y = false
	var start_pitch := rig.pitch
	rig._input(motion)
	check(rig.pitch < start_pitch, "mouse look normal Y")
	R.invert_y = true
	start_pitch = rig.pitch
	rig._input(motion)
	check(rig.pitch > start_pitch, "mouse look inverted Y")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rig.queue_free()

	if shot:
		await _shots()
	R.reset_all()
	R.load_config(real_cfg)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	print("CONTROLS_DONE fails=", fails)
	get_tree().quit(1 if fails else 0)

func _save(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	var p := ProjectSettings.globalize_path("res://screenshots/ui/controls_%s.png" % name)
	get_viewport().get_texture().get_image().save_png(p)
	print("[SHOT] ", p)

func _shots() -> void:
	get_node("/root/GraphicsSettings").apply_quality(1, false)
	R.reset_all()
	R.rebind("jump", key(KEY_E), -1, "swap")  # show a non-default row
	var menu: Control = preload("res://ui/controls/ControlsMenu.gd").open(self)
	await get_tree().create_timer(0.5).timeout
	await _save("menu")
	menu._rows["sprint"].kbm.grab_focus()
	menu._rows["sprint"].kbm.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	await _save("capture")
	var f := key(KEY_F); f.pressed = true
	Input.parse_input_event(f); Input.flush_buffered_events()
	await get_tree().create_timer(0.3).timeout
	await _save("conflict")
	menu._resolve_conflict(false)
	menu._scroll.scroll_vertical = 10000
	menu._rows["journal"].pad.grab_focus()
	await get_tree().create_timer(0.3).timeout
	await _save("scrolled")
	menu.close()
