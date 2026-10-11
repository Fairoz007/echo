extends SceneTree
## Unified-world prototype: Ch5 -> Ch6 without a scene swap card, respawn or camera reset.
## Run with a window (xvfb-run) for screenshots: -s res://dev/region_handoff_test.gd -- --out=<dir>

var fails := 0

func _check(label: String, ok: bool, info := "") -> void:
	print("HANDOFF ", "PASS " if ok else "FAIL ", label, " ", info)
	if not ok:
		fails += 1

func _snap(out: String, name: String) -> void:
	if out != "":
		root.get_viewport().get_texture().get_image().save_png(out.path_join(name))

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	change_scene_to_file("res://levels/Chapter5.tscn")
	for i in 60:
		await physics_frame
	var ch5 := current_scene
	var player = ch5.get_node("Player")
	# Story state as if the patrol was ghosted and Drake observed.
	player.global_position = ch5.get_node("ObservationPerch/DrakeTrigger").global_position
	for i in 20:
		await physics_frame
	_check("drake observed", ch5.has_seen_drake)
	# Real players spend several seconds walking from the perch to the entrance (~15 m);
	# give the background prefetch the same time.
	for i in 300:
		await physics_frame
	player.current_health = 63.0
	player.set("ammunition", 7)
	# Stand just short of the entrance, facing it.
	var entrance: Vector3 = ch5.get_node("TempleEntrance").global_position
	var probe := entrance + Vector3(0, 40.0, 5.0)
	var hit: Dictionary = ch5.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 120.0, 2))
	print("HANDOFF ground probe ", hit.get("position", "none"), " ", hit.get("collider", null))
	player.global_position = (hit.position as Vector3 if hit else entrance) + Vector3(0, 0.3, 0)
	for i in 40:
		await physics_frame
	var cam_offset_before: Vector3 = player.camera_pivot.global_position - player.global_position
	var yaw_before: float = player.camera_pivot.yaw
	_snap(out, "handoff_before.png")
	var player_id: int = player.get_instance_id()
	# Walk forward into the trigger with real input.
	var max_jump := 0.0
	var last: Vector3 = player.global_position
	var cam_last: Vector3 = player.camera_pivot.global_position - player.global_position
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_usec()
	var worst_frame := 0.0
	for i in 240:
		var f0 := Time.get_ticks_usec()
		await physics_frame
		worst_frame = maxf(worst_frame, (Time.get_ticks_usec() - f0) / 1000.0)
		if not is_instance_valid(player):
			break
		var rel: Vector3 = player.camera_pivot.global_position - player.global_position
		max_jump = maxf(max_jump, rel.distance_to(cam_last))
		cam_last = rel
		if current_scene and current_scene.name == "Chapter6":
			Input.action_release("move_forward")
			for k in 30:
				await physics_frame
				var r2: Vector3 = player.camera_pivot.global_position - player.global_position
				max_jump = maxf(max_jump, r2.distance_to(cam_last))
				cam_last = r2
			break
	Input.action_release("move_forward")
	_snap(out, "handoff_after.png")
	_check("now in Chapter6 region", current_scene != null and current_scene.name == "Chapter6", str(current_scene.name if current_scene else "none"))
	_check("same Player instance kept", is_instance_valid(player) and player.get_instance_id() == player_id and player.get_parent() == current_scene)
	_check("health preserved", is_equal_approx(player.current_health, 63.0), str(player.current_health))
	_check("ammo preserved", player.get("ammunition") == 7, str(player.get("ammunition")))
	_check("camera yaw preserved", absf(wrapf(player.camera_pivot.yaw - yaw_before, -PI, PI)) < 0.05, "%.3f -> %.3f" % [yaw_before, player.camera_pivot.yaw])
	_check("camera pivot never jumped (arm pull-in excluded) >0.5m in a frame", max_jump < 0.5, "%.3f" % max_jump)
	_check("chapter is 6", root.get_node("GameManager").current_chapter == 6)
	_check("Ch6 objective active", root.get_node("MissionManager").active_objectives.size() > 0, str(root.get_node("MissionManager").active_objectives.keys()))
	_check("player on Ch6 landing floor", player.is_on_floor() and player.global_position.y > 0.5 and player.global_position.y < 1.6, str(player.global_position))
	_check("old region freed", not is_instance_valid(ch5))
	_check("single player in tree", get_nodes_in_group("player").size() == 1)
	print("HANDOFF worst physics frame during walk %.1f ms" % worst_frame)
	print("HANDOFF RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
