extends SceneTree
## DEV ONLY: Player start-up and per-frame cost (headless).
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var c0 := Time.get_ticks_usec()
	var first = (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	var c1 := Time.get_ticks_usec()
	root.add_child(first)
	var c2 := Time.get_ticks_usec()
	print("PERF cold load+instantiate=%.1fms cold _ready=%.1fms" % [(c1 - c0) / 1000.0, (c2 - c1) / 1000.0])
	first.queue_free()
	await physics_frame
	var course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 30:
		await physics_frame
	var p = course.player
	var ps: PackedScene = load("res://scenes/Player.tscn")
	var t0 := Time.get_ticks_usec()
	var p2 = ps.instantiate()
	var t1 := Time.get_ticks_usec()
	p2.position = Vector3(0, 0.1, 30)
	course.add_child(p2)
	var t2 := Time.get_ticks_usec()
	print("PERF instantiate=%.1fms add_child(_ready)=%.1fms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
	p2.queue_free()
	await physics_frame
	p.global_position = course.lane_start("flat") + Vector3(-34, 0, 0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 30:
		await physics_frame
	var tf := Time.get_ticks_usec()
	for i in 120:
		await physics_frame
	print("EQUIP sidearm=", p.sidearm_visual != null, " pick=", p.pick_visual != null)
	print("PERF frame=%.2fms (wall, sprinting) physics_process=%.2fms" % [(Time.get_ticks_usec() - tf) / 120000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	quit()
