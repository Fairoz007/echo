extends SceneTree
## Level A: load a level, report worst frame times. Args after --: --scene=res://... --secs=6
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://levels/Chapter7.tscn"
	var secs := 6.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="): path = a.substr(8)
		if a.begins_with("--secs="): secs = float(a.substr(7))
	var t0 := Time.get_ticks_usec()
	var ps := load(path) as PackedScene
	var t1 := Time.get_ticks_usec()
	var scene := ps.instantiate()
	root.add_child(scene)
	var t2 := Time.get_ticks_usec()
	print("LOAD %s load=%.0fms instantiate+ready=%.0fms" % [path, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
	var worst := 0.0
	var over := 0
	var last := Time.get_ticks_usec()
	var end := last + int(secs * 1e6)
	var n := 0
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		n += 1
		if dt > worst: worst = dt
		if dt > 100.0:
			over += 1
			print("  slow frame #%d %.0fms" % [n, dt])
	print("FRAMES n=%d worst=%.0fms over100=%d" % [n, worst, over])
	quit(0)
