extends SceneTree
## Ch5 stealth route: reaching the perch undetected must progress without killing the patrol.
## Also checks the combat route still gates on detection.

func _init() -> void:
	call_deferred("_run")

func _case(detected: bool) -> bool:
	var lvl: Node = load("res://levels/Chapter5.tscn").instantiate()
	root.add_child(lvl)
	for i in 30:
		await physics_frame
	if detected:
		lvl.was_detected = true
	var player: Node3D = lvl.get_node("Player")
	player.global_position = lvl.get_node("ObservationPerch/DrakeTrigger").global_position
	for i in 20:
		await physics_frame
	var ok: bool = lvl.has_seen_drake == (not detected) and lvl.enemies_remaining == 2
	print("CH5_STEALTH detected=", detected, " has_seen_drake=", lvl.has_seen_drake, " enemies=", lvl.enemies_remaining, " -> ", "PASS" if ok else "FAIL")
	lvl.queue_free()
	await process_frame
	return ok

func _run() -> void:
	var a := await _case(false)
	var b := await _case(true)
	print("CH5_STEALTH RESULT ", "PASS" if a and b else "FAIL")
	quit(0 if a and b else 1)
