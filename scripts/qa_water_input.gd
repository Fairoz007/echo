extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr("QA FAILED: " + message)
	quit(1)

func _run() -> void:
	var gm = root.get_node("GameManager")
	root.get_node("SaveManager").save_directory = "user://qa_water"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_water"))
	gm.load_chapter(6, "res://levels/Chapter6.tscn")
	await create_timer(1.2).timeout
	var player = get_first_node_in_group("player")
	for i in 600:
		if player:
			break
		await physics_frame
		player = get_first_node_in_group("player")
	if player == null:
		_fail("Chapter 6 player never spawned")
		return
	# Chapter 6 now spawns Mara on a dry landing; place her in the flooded hall first
	# (after the chapter card / spawn placement has settled).
	while paused:
		await process_frame
	await create_timer(2.0).timeout
	player.global_position = Vector3(0, 0.3, 10)
	player.velocity = Vector3.ZERO
	await create_timer(1.0).timeout
	if player.current_state != player.State.SWIM:
		_fail("Production water volume did not place player in SWIM")
		return
	var height: float = player.global_position.y
	# Rebuilt swim dives at ~1.1 m/s; hold long enough for 1.5 m (floor is ~2.9 m below).
	Input.action_press("dive")
	await create_timer(1.6).timeout
	Input.action_release("dive")
	if player.global_position.y > height - 1.5 or not player.underwater or player.current_oxygen >= player.max_oxygen:
		print("dive debug: start_y=", height, " y=", player.global_position.y, " underwater=", player.underwater, " o2=", player.current_oxygen, "/", player.max_oxygen, " state=", player.current_state)
		_fail("Dive input cannot descend beneath water surface or oxygen does not drain")
		return
	var position: Vector3 = player.global_position
	Input.action_press("move_forward")
	await create_timer(1.2).timeout
	Input.action_release("move_forward")
	var swum := Vector2(player.global_position.x - position.x, player.global_position.z - position.z).length()
	print("swim debug: moved ", swum, " m, state=", player.current_state, " pos=", player.global_position)
	if swum < 1.0:
		_fail("Underwater forward input did not swim")
		return
	# Low-oxygen fixture verifies the real drowning path without waiting 30 seconds.
	player.current_oxygen = 0.1
	var health: float = player.current_health
	await create_timer(0.5).timeout
	if player.current_health >= health:
		_fail("Exhausted underwater oxygen did not damage player")
		return
	Input.action_press("jump")
	await create_timer(2.0).timeout
	Input.action_release("jump")
	await create_timer(0.4).timeout
	if player.underwater or player.current_oxygen <= 0.5:
		_fail("Surface input did not recover breathing")
		return
	print("QA PASS: actual Temple water entry, dive/swim/surface input, oxygen depletion/drowning/recovery")
	gm.return_to_menu()
	await create_timer(15.0).timeout
	quit(0)
