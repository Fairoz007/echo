extends SceneTree
## Input-driven Prologue walk: holds movement toward centreline waypoints (natural steering,
## camera-relative input like a player), interacts with the relic, reaches the exit.
## Fails if Mara makes < 0.5 m progress in any 2 s window. Headless:
##   godot --headless --path . -s res://scripts/qa_prologue_walk.gd
const WAYPOINTS := [Vector3(0, 0, -6), Vector3(0.6, 0, -10.6), Vector3(1.4, 0, -12), Vector3(0.4, 0, -16), Vector3(0, 0, -20), Vector3(0, 0, -25.5)]

func _init() -> void:
	call_deferred("_run")

func _release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)

func _run() -> void:
	root.get_node("SaveManager").save_directory = "user://qa_prologue_walk"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_prologue_walk"))
	var gm := root.get_node("GameManager")
	gm.load_chapter(0, gm.chapter_scene(0))
	var player = null
	for i in 60:
		await create_timer(0.25).timeout
		player = get_first_node_in_group("player")
		if player and player.is_inside_tree():
			break
	await create_timer(2.0).timeout
	if player == null:
		print("WALK FAIL: no player")
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var window_pos: Vector3 = player.global_position
	var window_t := 0
	for wi in WAYPOINTS.size():
		var target: Vector3 = WAYPOINTS[wi]
		for frame in range(1200):
			var off: Vector3 = target - player.global_position
			off.y = 0
			if off.length() < 0.6:
				break
			var dir: Vector3 = player.camera_pivot.global_basis.inverse() * off.normalized()
			_release()
			Input.action_press("move_right" if dir.x > 0.0 else "move_left", absf(dir.x))
			Input.action_press("move_back" if dir.z > 0.0 else "move_forward", absf(dir.z))
			await physics_frame
			window_t += 1
			if window_t >= 120:
				if player.global_position.distance_to(window_pos) < 0.5:
					_release()
					print("WALK FAIL: stuck at ", player.global_position, " heading to ", target)
					var col = player.get_last_slide_collision()
					if col:
						print("  last collider: ", col.get_collider().get_path() if col.get_collider() else "?")
					quit(1)
					return
				window_pos = player.global_position
				window_t = 0
		print("WALK reached waypoint %d %s at %s" % [wi, target, player.global_position])
		if wi == 2:
			_release()
			await create_timer(0.2).timeout
			if player.nearby_interactable:
				var e := InputEventAction.new()
				e.action = "interact"
				e.pressed = true
				Input.parse_input_event(e)
				await process_frame
				e = InputEventAction.new()
				e.action = "interact"
				e.pressed = false
				Input.parse_input_event(e)
				print("WALK interacted with relic")
			else:
				print("WALK FAIL: relic not interactable from route")
				quit(1)
				return
	_release()
	for f in 600:
		await physics_frame
		if gm.current_chapter == 1:
			break
	print("WALK %s chapter=%d elapsed=%.1fs" % ["PASS" if gm.current_chapter == 1 else "FAIL (no transition)", gm.current_chapter, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if gm.current_chapter == 1 else 1)
