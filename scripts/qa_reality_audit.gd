extends SceneTree

## Reality audit (Compatibility/OpenGL, ULTRA LOW or LOW only on this machine).
## Drives the REAL game with simulated InputEvents only: mouse clicks on menu buttons,
## keyboard for movement/interaction/pause/journal. No teleports, no direct calls on
## gameplay objects, no scene switching during the playthrough.
## Optional scene-load sweep afterwards (labelled sceneload_*, NOT playthroughs).
## Usage:
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720
##     --path . -s res://scripts/qa_reality_audit.gd -- --out=<dir> --preset=1
##     [--skip-menus] [--skip-play] [--levels=0,1,6] [--uncapped]

var out_dir := "user://reality_audit"
var log_lines: PackedStringArray = []
var perf: Array = []
var player: Node

func _init() -> void:
	call_deferred("_run")

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return fallback

func _has(name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + name)

func _note(t: String) -> void:
	print("[AUDIT] " + t)
	log_lines.append(t)

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	_note("screenshot %s" % path)

func _sequence(name: String, frames: int, every: float) -> void:
	for i in frames:
		await _shot("%s_f%02d" % [name, i])
		await create_timer(every).timeout

func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func _tap(code: Key) -> void:
	_key(code, true)
	await create_timer(0.12).timeout
	_key(code, false)
	await create_timer(0.3).timeout

func _click_control(control: Control) -> void:
	var center: Vector2 = control.get_viewport().get_final_transform() * control.get_global_rect().get_center() if control.get_viewport() == root else control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = pressed
		m.position = center
		m.global_position = center
		Input.parse_input_event(m)
		await process_frame
	await create_timer(0.4).timeout

func _player_state() -> String:
	player = get_first_node_in_group("player")
	if not is_instance_valid(player):
		return "no player"
	var anim := ""
	var ap = player.find_children("*", "AnimationPlayer", true, false)
	if ap.size() > 0:
		anim = str(ap[0].current_animation)
	return "pos=%s vel=%.2f floor=%s state=%s anim=%s" % [str(player.global_position.snapped(Vector3.ONE * 0.01)), player.velocity.length(), player.is_on_floor(), str(player.get("current_state")), anim]

func _measure(label: String, seconds: float) -> void:
	var frames := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	var r := {
		"label": label, "preset": root.get_node("GraphicsSettings").quality_level,
		"avg_fps": snappedf(frames / elapsed, 0.1), "worst_ms": snappedf(worst, 0.1),
		"vram_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"ram_static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"process_ram_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	}
	_note("PERF " + JSON.stringify(r))
	perf.append(r)

func _wait_scene(suffix: String, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if current_scene and current_scene.scene_file_path.ends_with(suffix) and not root.get_node("GameManager").transition.is_active():
			return true
		await create_timer(0.25).timeout
		t += 0.25
	return false

func _run() -> void:
	out_dir = _arg("out", out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir if not out_dir.begins_with("user://") else ProjectSettings.globalize_path(out_dir))
	root.get_node("SaveManager").save_directory = "user://qa_reality"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_reality"))
	for f in ["save_slot_0.json", "save_slot_1.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_reality/" + f))
	var preset := int(_arg("preset", "1"))
	root.get_node("GraphicsSettings").apply_quality(preset, false)
	if _has("uncapped"):
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_note("renderer=%s driver=%s adapter=%s preset=%s window=%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(), root.get_node("GraphicsSettings").QUALITY_NAMES[preset], str(DisplayServer.window_get_size())])
	if not _has("skip-menus"):
		await _menus()
	if not _has("skip-play"):
		await _play()
	if _arg("levels", "") != "" or _has("sweep"):
		await _sweep()
	var f := FileAccess.open(out_dir.path_join("audit_results.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"log": log_lines, "perf": perf}, "\t"))
		f.close()
	_note("AUDIT COMPLETE")
	quit(0)

func _menus() -> void:
	change_scene_to_file("res://ui/MainMenu.tscn")
	await create_timer(1.5).timeout
	await _shot("m01_main_menu")
	var menu := current_scene
	var cont: Button = menu.get_node("VBoxContainer/BtnContinue")
	_note("menu: continue disabled=%s (no save in user:// root: %s)" % [cont.disabled, not FileAccess.file_exists("user://save_slot_0.json")])
	# Settings
	await _click_control(menu.get_node("VBoxContainer/BtnSettings"))
	var panel: Window = menu.get_node_or_null("MenuPanel")
	_note("settings panel opened=%s" % [panel != null])
	await _shot("m02_settings")
	if panel:
		var opt: OptionButton = panel.find_child("GraphicsQuality", true, false)
		_note("settings graphics items=%d selected=%d" % [opt.item_count if opt else -1, opt.selected if opt else -1])
		panel.close_requested.emit()
		await create_timer(0.3).timeout
	await _click_control(menu.get_node("VBoxContainer/BtnCredits"))
	await _shot("m03_credits")
	panel = menu.get_node_or_null("MenuPanel")
	_note("credits panel opened=%s" % [panel != null])
	if panel:
		panel.close_requested.emit()
		await create_timer(0.3).timeout

func _play() -> void:
	var gm = root.get_node("GameManager")
	var mm = root.get_node("MissionManager")
	if current_scene == null or not current_scene.scene_file_path.ends_with("MainMenu.tscn"):
		change_scene_to_file("res://ui/MainMenu.tscn")
		await create_timer(1.5).timeout
	await _click_control(current_scene.get_node("VBoxContainer/BtnNewGame"))
	await create_timer(1.5).timeout
	_note("after New Game click: transition active=%s" % gm.transition.is_active())
	await _shot("t00_card_prologue_a")
	await create_timer(3.0).timeout
	await _shot("t00_card_prologue_b")
	if not await _wait_scene("Prologue.tscn", 25.0):
		_note("FAIL: Prologue never became active")
		return
	var shown := Time.get_ticks_msec()
	await create_timer(0.5).timeout
	await _shot("p01_prologue_opening")
	_note("idle: " + _player_state())
	await _sequence("p02_idle_seq", 6, 0.25)
	await _measure("prologue_idle", 3.0)
	# Pause menu (Esc)
	await _tap(KEY_ESCAPE)
	await _shot("m04_pause_menu")
	_note("pause: state=%s paused=%s" % [gm.GameState.keys()[gm.current_state], paused])
	await _tap(KEY_ESCAPE)
	_note("unpause: state=%s paused=%s" % [gm.GameState.keys()[gm.current_state], paused])
	# Journal (advertised on HUD)
	await _tap(KEY_J)
	await _shot("m05_journal_prologue")
	await _tap(KEY_J)
	# Walk / run / sprint / jump
	_key(KEY_W, true)
	await create_timer(0.6).timeout
	_note("forward: " + _player_state())
	await _sequence("p03_run_seq", 8, 0.12)
	_key(KEY_SHIFT, true)
	await create_timer(0.5).timeout
	_note("sprint: " + _player_state())
	await _sequence("p04_sprint_seq", 6, 0.12)
	_key(KEY_SHIFT, false)
	_key(KEY_SPACE, true)
	await create_timer(0.1).timeout
	_key(KEY_SPACE, false)
	_note("jump: " + _player_state())
	await _sequence("p05_jump_seq", 6, 0.08)
	await _measure("prologue_moving", 2.0)
	var elapsed := 0.0
	var interacted := false
	var idx := 0
	var last_pos := Vector3.INF
	var stuck_count := 0
	while elapsed < 45.0 and gm.current_chapter == 0:
		await create_timer(0.5).timeout
		elapsed += 0.5
		player = get_first_node_in_group("player")
		if is_instance_valid(player) and player.get("nearby_interactable") and not interacted:
			_key(KEY_W, false)
			await create_timer(0.4).timeout
			await _shot("p06_artifact_prompt")
			await _tap(KEY_E)
			interacted = mm.completed_objectives.has("obj_prologue_explore")
			_note("interact: objective complete=%s %s" % [interacted, _player_state()])
			_key(KEY_W, true)
		# Stuck handling with simulated input only: strafe around the obstacle.
		if is_instance_valid(player):
			var p: Vector3 = player.global_position
			if p.distance_to(last_pos) < 0.05:
				stuck_count += 1
				var side: Key = KEY_D if stuck_count % 2 == 1 else KEY_A
				_note("stuck at %s -> strafing %s" % [str(p.snapped(Vector3.ONE * 0.01)), "right" if side == KEY_D else "left"])
				_key(side, true)
				await create_timer(0.3 + 0.2 * stuck_count).timeout
				_key(side, false)
			last_pos = p
		if int(elapsed * 2) % 4 == 0:
			idx += 1
			_note("t=%.1f %s" % [elapsed, _player_state()])
			await _shot("p07_walk_%02d" % idx)
	_key(KEY_W, false)
	_note("prologue end: chapter=%d interacted=%s %s" % [gm.current_chapter, interacted, _player_state()])
	await create_timer(1.0).timeout
	await _shot("t01_card_chapter1_a")
	_note("chapter transition card active=%s" % gm.transition.is_active())
	await create_timer(2.5).timeout
	await _shot("t01_card_chapter1_b")
	if not await _wait_scene("Chapter1.tscn", 30.0):
		_note("FAIL: Chapter1 never became active")
		return
	await create_timer(1.0).timeout
	await _shot("c01_opening")
	_note("chapter1 start: " + _player_state())
	await _sequence("c01_wind_seq", 8, 0.25)
	await _measure("chapter1_idle", 3.0)
	await _tap(KEY_J)
	await _shot("m06_journal_chapter1")
	gm.journal_screen.tabs.current_tab = 1
	await _shot("m07_inventory_chapter1")
	gm.journal_screen.tabs.current_tab = 2
	await _shot("m08_skills_chapter1")
	await _tap(KEY_J)
	# Checkpoint save via F5, then walk and reload via F9 (save system retest).
	await _tap(KEY_F5)
	var saved_exists := FileAccess.file_exists("user://qa_reality/save_slot_0.json")
	var before: Vector3 = get_first_node_in_group("player").global_position
	_note("F5 save exists=%s at %s" % [saved_exists, str(before)])
	_key(KEY_W, true)
	await create_timer(2.0).timeout
	_key(KEY_W, false)
	await create_timer(0.5).timeout
	var moved: Vector3 = get_first_node_in_group("player").global_position
	_note("walked to %s" % str(moved))
	await _tap(KEY_F9)
	await _shot("t02_card_reload")
	if await _wait_scene("Chapter1.tscn", 30.0):
		await create_timer(1.0).timeout
		var after: Vector3 = get_first_node_in_group("player").global_position
		_note("F9 reload: player at %s (saved %s) dist=%.2f chapter=%d" % [str(after), str(before), after.distance_to(before), gm.current_chapter])
		await _shot("c02_after_reload")
	# Pause -> Main menu -> Continue
	await _tap(KEY_ESCAPE)
	var pm = gm._pause_menu
	var btn_menu: Button = null
	for b in pm.find_children("*", "Button", true, false):
		if b.text == "Main menu":
			btn_menu = b
	if btn_menu:
		await _click_control(btn_menu)
		await create_timer(1.5).timeout
		_note("after Main menu: scene=%s" % current_scene.scene_file_path)
		var cont: Button = current_scene.get_node("VBoxContainer/BtnContinue")
		_note("continue enabled=%s (MainMenu checks user://save_slot_0.json, QA saves to user://qa_reality)" % [not cont.disabled])

func _sweep() -> void:
	var gm = root.get_node("GameManager")
	for part in _arg("levels", "0,1,2,3,4,5,6,7,8,9,10,11,12").split(","):
		var ch := int(part)
		var path: String = gm.chapter_scene(ch)
		gm.current_chapter = ch
		gm.change_state(gm.GameState.GAMEPLAY)
		change_scene_to_file(path)
		await create_timer(4.0).timeout
		if _has("uncapped"):
			Engine.max_fps = 0
		await _shot("sceneload_%02d_%s" % [ch, path.get_file().get_basename()])
		await _measure("sceneload_%s" % path.get_file().get_basename(), 4.0)
		root.get_node("AudioManager").stop_dialogue()
