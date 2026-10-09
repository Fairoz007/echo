extends SceneTree

## Controller integration: no teleport, direct interaction call or scene switching
## after New Game. This does not certify visual or human gameplay quality.
func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	Input.action_release("move_forward")
	printerr("QA FAILED: " + message)
	quit(1)

func _run() -> void:
	root.get_node("SaveManager").save_directory = "user://qa_prologue"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_prologue"))
	root.get_node("GameManager").start_new_game()
	# New Game plays the intro story card (CINEMATIC) before the Prologue spawns Mara.
	var player = null
	for i in 150:
		await create_timer(0.1).timeout
		player = get_first_node_in_group("player")
		if player and root.get_node("GameManager").current_state == root.get_node("GameManager").GameState.GAMEPLAY:
			break
	if not player:
		_fail("New Game did not create player")
		return
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for frame in range(300):
		await physics_frame
		if player.nearby_interactable:
			break
	Input.action_release("move_forward")
	await create_timer(0.1).timeout
	print("QA movement distance: ", start.distance_to(player.global_position))
	if not player.nearby_interactable:
		_fail("Forward input cannot reach artifact interaction area within 5 simulated seconds")
		return
	if start.distance_to(player.global_position) < 5.0:
		_fail("Player did not physically traverse tunnel")
		return
	var interaction = InputEventAction.new()
	interaction.action = "interact"
	interaction.pressed = true
	Input.parse_input_event(interaction)
	await process_frame
	interaction = InputEventAction.new()
	interaction.action = "interact"
	interaction.pressed = false
	Input.parse_input_event(interaction)
	await create_timer(0.2).timeout
	var mm = root.get_node("MissionManager")
	if not mm.completed_objectives.has("obj_prologue_explore"):
		_fail("E input did not complete artifact objective")
		return
	Input.action_press("move_forward")
	for frame in range(480):
		await physics_frame
		if root.get_node("GameManager").current_chapter == 1:
			break
	Input.action_release("move_forward")
	if root.get_node("GameManager").current_chapter != 1:
		_fail("Forward input did not reach Chapter 1 through exit trigger")
		return
	print("QA PASS: New Game, physical forward movement, interaction input and natural exit transition")
	await process_frame
	root.get_node("AudioManager").stop_dialogue()
	change_scene_to_file("res://ui/MainMenu.tscn")
	await create_timer(12.0).timeout
	quit(0)
