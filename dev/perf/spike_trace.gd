extends SceneTree
## Load-spike tracer. Prints every frame > 30 ms during the first 8 s after the level is
## added, interleaved with --profile-build stage prints (CaveBuilder, LevelCave,
## CampaignEnvironmentArt, EnvironmentCollision), so each spike can be attributed.
## usage: ... -s res://dev/perf/spike_trace.gd -- --quality=1 --profile-build --scene=Chapter7
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var s := "Chapter7"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			s = a.substr(8)
	var t := Time.get_ticks_usec()
	var scene := (load("res://levels/%s.tscn" % s) as PackedScene).instantiate()
	print("TRACE load+instantiate %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	print("TRACE add_child(_ready) %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var gm = root.get_node_or_null("GameManager")
	if gm:
		gm.current_state = gm.GameState.GAMEPLAY
	root.get_node("GraphicsSettings")._on_scene_changed()
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var last := Time.get_ticks_usec()
	var end := last + 8000000
	var n := 0
	var worst := 0.0
	while Time.get_ticks_usec() < end:
		await process_frame
		n += 1
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		worst = maxf(worst, ms)
		if ms > 30.0:
			print("TRACE frame %d: %.0f ms (process %.0f ms, physics %.0f ms)" % [n, ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		last = now
	print("TRACE worst %.0f ms over %d frames" % [worst, n])
	quit(0)
