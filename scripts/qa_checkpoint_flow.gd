extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr("QA FAILED: " + message)
	quit(1)

func _run() -> void:
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SaveManager")
	sm.save_directory = "user://qa_checkpoint"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.save_directory))
	gm.start_new_game()
	await create_timer(0.9).timeout
	if not FileAccess.file_exists(sm.save_path(0)) or not FileAccess.file_exists(sm.save_path(1)):
		_fail("New Game did not create checkpoint and Continue save")
		return
	var player = get_first_node_in_group("player")
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	await create_timer(0.2).timeout
	gm.change_state(gm.GameState.PAUSED)
	gm._pause_menu.show_menu(false)
	if not paused or not gm._pause_menu.panel.visible:
		_fail("Pause user flow did not pause simulation")
		return
	if not sm.manual_save():
		_fail("Manual save on stable ground failed")
		return
	var saved_text = FileAccess.get_file_as_string(sm.save_path(0))
	var checkpoint_text = FileAccess.get_file_as_string(sm.save_path(1))
	gm._pause_menu.close_menu()
	if not gm.continue_saved_game(0):
		_fail("Continue failed")
		return
	await create_timer(0.3).timeout
	if saved_text != FileAccess.get_file_as_string(sm.save_path(0)) or checkpoint_text != FileAccess.get_file_as_string(sm.save_path(1)):
		_fail("Continue overwrote checkpoint or manual save")
		return
	player = get_first_node_in_group("player")
	player.take_damage(1000.0)
	if not paused or not gm._pause_menu.restart.visible or gm._pause_menu.resume.visible:
		_fail("Death user flow missing restart UI")
		return
	gm._pause_menu._restart()
	await create_timer(0.4).timeout
	player = get_first_node_in_group("player")
	if paused or player.current_health <= 0.0 or gm.current_state != gm.GameState.GAMEPLAY:
		_fail("Checkpoint restart did not restore a living player")
		return
	print("QA PASS: automatic checkpoint, pause/manual save, Continue preservation, death/restart")
	gm.return_to_menu()
	await create_timer(12.0).timeout
	quit(0)
