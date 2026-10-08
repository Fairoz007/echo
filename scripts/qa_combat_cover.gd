extends SceneTree

## Physics fixture using production Player/Enemy code, shots and reload input.
## Fixture placement is deliberate; this is not a campaign playthrough.
func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr("QA FAILED: " + message)
	quit(1)

func _shot() -> void:
	Input.action_press("fire")
	await physics_frame
	await physics_frame
	Input.action_release("fire")
	await create_timer(0.4).timeout

func _run() -> void:
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SaveManager")
	sm.save_directory = "user://qa_combat"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.save_directory))
	gm.load_chapter(5, "res://levels/Chapter5.tscn")
	await create_timer(0.6).timeout
	var player = get_first_node_in_group("player")
	var enemy = current_scene.get_node("Enemies/EnemyMercenary1")
	for mercenary in get_nodes_in_group("enemies"):
		mercenary.set_physics_process(false)
	enemy.global_position = player.global_position + Vector3(0, 0, -10)
	var pivot = current_scene.get_node("CameraController")
	pivot.process_mode = Node.PROCESS_MODE_DISABLED
	var camera = root.get_camera_3d()
	camera.global_position = player.global_position + Vector3(0, 1.4, 1)
	camera.look_at(enemy.global_position + Vector3(0, 1.2, 0))
	await physics_frame
	await physics_frame
	var initial_ammunition: int = player.ammunition
	await _shot()
	if enemy.current_health != 30.0 or player.ammunition != initial_ammunition - 1:
		_fail("Fire input did not raycast-damage enemy or consume one round")
		return
	var cover = StaticBody3D.new()
	cover.collision_layer = 2
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	shape.shape = box
	cover.add_child(shape)
	current_scene.add_child(cover)
	cover.global_position = player.global_position + Vector3(0, 1.5, -5)
	await physics_frame
	await physics_frame
	await _shot()
	if enemy.current_health != 30.0:
		_fail("Player bullets passed through solid world cover")
		return
	enemy.target_player = player
	var health: float = player.current_health
	enemy._attack_player()
	if player.current_health != health:
		_fail("Enemy fire passed through solid world cover")
		return
	cover.queue_free()
	await physics_frame
	await physics_frame
	await _shot()
	if enemy.current_health > 0.0 or current_scene.enemies_remaining != 1:
		_fail("Second exposed shot did not defeat patrol and update mission counter")
		return
	var event = InputEventAction.new()
	event.action = "reload"
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(1.6).timeout
	if player.ammunition != player.magazine_capacity:
		_fail("Reload input did not fill magazine")
		return
	await create_timer(1.0).timeout
	if not sm.save_game(97) or not gm.continue_saved_game(97):
		_fail("Combat save/load failed")
		return
	await create_timer(0.3).timeout
	if current_scene.get_node_or_null("Enemies/EnemyMercenary1") or current_scene.enemies_remaining != 1:
		_fail("Defeated enemy respawned or restored patrol count changed")
		return
	print("QA PASS: fire/reload input, actual raycast hit, player/enemy cover occlusion, patrol death and save persistence")
	gm.return_to_menu()
	await create_timer(12.0).timeout
	quit(0)
