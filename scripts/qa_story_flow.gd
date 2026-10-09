extends SceneTree

## Story-flow + save retest (harness-driven, NOT a playthrough):
## death -> pause menu "Restart checkpoint", chapter transition persistence,
## Finale -> Epilogue card, Epilogue credits card. Takes screenshots of each card.
## Run with: --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720

var out_dir := ""
var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _note(t: String) -> void:
	print("[FLOW] " + t)

func _check(ok: bool, what: String) -> void:
	_note(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)

func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func _wait_scene(suffix: String, timeout: float) -> bool:
	var gm = root.get_node("GameManager")
	var t := 0.0
	# Wait for the requested transition to actually start (it is deferred).
	for i in 20:
		if gm.transition.is_active():
			break
		await create_timer(0.1).timeout
	while t < timeout:
		if current_scene and current_scene.scene_file_path.ends_with(suffix) and not gm.transition.is_active():
			return true
		await create_timer(0.25).timeout
		t += 0.25
	return false

func _skip() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SaveManager")
	var mm = root.get_node("MissionManager")
	root.get_node("GraphicsSettings").apply_quality(1, false)
	sm.save_directory = "user://qa_flow"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_flow"))
	for f in ["save_slot_0.json", "save_slot_1.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_flow/" + f))
	# 1. New game -> card -> Prologue; skip test: card must not end before load + skip.
	gm.start_new_game()
	await create_timer(0.8).timeout
	_check(gm.transition.is_active(), "New Game shows story card")
	await _skip()
	_check(await _wait_scene("Prologue.tscn", 20.0), "Prologue loads after skip")
	_check(FileAccess.file_exists("user://qa_flow/save_slot_1.json"), "chapter-start checkpoint written (slot 1)")
	# 2. Death -> GAME_OVER -> Restart checkpoint.
	await create_timer(1.0).timeout
	var player = get_first_node_in_group("player")
	player.take_damage(10000.0)
	await create_timer(2.2).timeout
	_check(gm.current_state == gm.GameState.GAME_OVER, "death enters GAME_OVER (state=%s)" % gm.GameState.keys()[gm.current_state])
	await _shot("flow_death_menu")
	gm._pause_menu._restart()
	_check(await _wait_scene("Prologue.tscn", 20.0), "restart checkpoint reloads Prologue")
	await create_timer(0.5).timeout
	player = get_first_node_in_group("player")
	_check(player and player.current_health > 0.0, "player alive after restart (hp=%s)" % (player.current_health if player else -1))
	_check(gm.current_state == gm.GameState.GAMEPLAY and not paused, "gameplay resumes unpaused after restart")
	# 3. Chapter transition persistence: progression carried across load_chapter.
	root.get_node("SkillManager").current_xp = 123
	gm.load_chapter(5, gm.chapter_scene(5))
	await create_timer(1.0).timeout
	await _shot("flow_card_ch5")
	_check(await _wait_scene("Chapter5.tscn", 25.0), "Chapter 5 loads through card")
	_check(root.get_node("SkillManager").current_xp == 123, "XP persists through chapter transition")
	_check(sm.load_game(1) and int(sm.game_data.chapter) == 5, "chapter-start checkpoint records chapter 5")
	sm.restore_pending = false
	# 4. Quit/continue: save slot 0, back to menu, Continue.
	await create_timer(1.0).timeout
	_check(sm.save_game(0), "save_game slot 0 in Chapter 5")
	gm.return_to_menu()
	await create_timer(1.0).timeout
	_check(gm.continue_saved_game(0), "continue_saved_game")
	_check(await _wait_scene("Chapter5.tscn", 25.0) and gm.current_chapter == 5, "Continue returns to Chapter 5")
	# 5. Finale -> Epilogue -> credits cards.
	gm.load_chapter(11, gm.chapter_scene(11))
	await create_timer(1.0).timeout
	await _shot("flow_card_finale")
	_check(await _wait_scene("Finale.tscn", 25.0), "Finale loads through card")
	gm.load_chapter(12, gm.chapter_scene(12))
	await create_timer(1.0).timeout
	await _shot("flow_card_epilogue")
	_check(await _wait_scene("Epilogue.tscn", 25.0), "Epilogue loads through card")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse visible on Epilogue")
	var seen_credits := false
	for i in 120:
		await create_timer(0.25).timeout
		if gm.transition.is_active():
			seen_credits = true
			await create_timer(1.0).timeout
			await _shot("flow_card_credits")
			break
	_check(seen_credits, "credits card shown when Epilogue rolls credits")
	_note("RESULT %s (%d failures) %s" % ["PASS" if failures.is_empty() else "FAIL", failures.size(), ", ".join(failures)])
	quit(0 if failures.is_empty() else 1)
