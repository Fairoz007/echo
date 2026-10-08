extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SaveManager")
	sm.save_directory = "user://qa_save_restore"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.save_directory))
	var mm = root.get_node("MissionManager")
	var sk = root.get_node("SkillManager")
	gm.start_new_game()
	await create_timer(0.2).timeout
	var player = get_first_node_in_group("player")
	player.current_health = 43.0
	player.current_stamina = 62.0
	player.rotation.y = -0.37
	var expected_position: Vector3 = player.global_position
	current_scene._on_artifact_interacted(player)
	current_scene.transition_started = true
	mm.complete_objective("obj_prologue_explore")
	mm.register_objective("qa_save_objective", "Saved objective")
	sk.add_xp(125)
	sk.unlock_skill("hunter_silent_step")
	if not sm.save_game(98):
		quit(1)
		return
	if sm.game_data.get("level_state", {}).has("transition_started"):
		printerr("QA FAILED: transient transition flag persisted")
		quit(1)
		return
	gm.start_new_game()
	await create_timer(0.2).timeout
	if sk.current_xp != 0 or not mm.completed_objectives.is_empty():
		printerr("QA FAILED: New Game retained progression")
		quit(1)
		return
	if not sm.load_game(98):
		quit(1)
		return
	gm.load_chapter(0, "res://levels/Prologue.tscn")
	await process_frame
	await process_frame
	player = get_first_node_in_group("player")
	await physics_frame
	if not current_scene.artifact_acquired or current_scene.transition_started or current_scene.resonant_artifact_interactable.is_enabled:
		printerr("QA FAILED: restored Prologue artifact/transition gate state")
		quit(1)
		return
	if absf(wrapf(player.rotation.y + 0.37, -PI, PI)) > 0.01 or player.current_health != 43.0 or sk.current_xp != 125 or sk.available_skill_points != 0 or not sk.is_skill_unlocked("hunter_silent_step") or not mm.active_objectives.has("qa_save_objective") or not mm.completed_objectives.has("obj_prologue_explore") or player.global_position.distance_to(expected_position) > 0.2:
		printerr("QA FAILED: live scene state roundtrip")
		quit(1)
		return
	if sm._valid_save({"chapter": 99, "player": {"position": [0, 1, 0]}}):
		quit(1)
		return
	# Deliberate save fixture: reload while standing in the exit volume.
	# This checks restore re-entry, not a physical traversal claim.
	player.global_position = Vector3(0, 0, -26)
	current_scene.transition_started = true
	if not sm.save_game(98) or not sm.load_game(98):
		quit(1)
		return
	gm.load_chapter(0, "res://levels/Prologue.tscn")
	await create_timer(6.0).timeout
	if gm.current_chapter != 1:
		printerr("QA FAILED: reload inside exit volume trapped chapter progression")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.save_path(98)))
	print("QA PASS: live player, objectives, spent skills, new-game reset, save validation and reload inside Prologue exit")
	root.get_node("AudioManager").stop_dialogue()
	change_scene_to_file("res://ui/MainMenu.tscn")
	await create_timer(12.0).timeout
	quit(0)
