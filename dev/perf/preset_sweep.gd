extends SceneTree
## Graphics preset sweep. Run once per preset (GraphicsSettings reads --quality=N):
##   godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --resolution 1280x720 -s res://dev/perf/preset_sweep.gd -- --quality=2 [--scenes=Prologue,Chapter9]
## For each level: load spike window (first 6 s after add_child: max frame, frames >100 ms),
## steady window (6 s: avg / 1%-low frame ms, draw calls, objects), memory, a screenshot
## (screenshots/perf/q<N>_<level>.png) and a live quality_changed round-trip check.
## Prints one "SWEEP|" line per level; grep the log for ERROR afterwards.
## FPS cap is lifted (240) during measurement so frame time reflects real cost.
const DEFAULT_SCENES := ["Prologue", "Chapter1", "Chapter6", "Chapter7", "Chapter9", "Finale"]
const LOAD_WINDOW := 6.0
const STEADY_WINDOW := 6.0

func _init() -> void:
	call_deferred("_run")

func _frames(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var end := Time.get_ticks_usec() + int(seconds * 1e6)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		out.append((now - last) / 1000.0)
		last = now
	return out

func _run() -> void:
	var scenes: Array = DEFAULT_SCENES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenes="):
			scenes = a.substr(9).split(",")
	var gs = root.get_node("GraphicsSettings")
	var q: int = gs.quality_level
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/perf"))
	print("SWEEP_BEGIN quality=%d (%s) forward_plus=%s" % [q, gs.QUALITY_NAMES[q], gs.is_forward_plus()])
	for s in scenes:
		var path := "res://levels/%s.tscn" % s
		var t0 := Time.get_ticks_usec()
		var packed := load(path) as PackedScene
		var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		var scene := packed.instantiate()
		root.add_child(scene)
		current_scene = scene
		var add_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var gm = root.get_node_or_null("GameManager")
		if gm:
			gm.current_state = gm.GameState.GAMEPLAY
		gs._on_scene_changed() # change_scene_* would emit scene_changed; -s mode does not
		Engine.max_fps = 240
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var load_frames := await _frames(LOAD_WINDOW)
		var spike := 0.0
		var hitches := 0
		for f in load_frames:
			spike = maxf(spike, f)
			if f > 100.0:
				hitches += 1
		var steady := await _frames(STEADY_WINDOW)
		var sorted := steady.duplicate()
		sorted.sort()
		var sum := 0.0
		for f in steady:
			sum += f
		var avg := sum / maxf(steady.size(), 1)
		var n1 := maxi(1, int(sorted.size() * 0.01))
		var low1 := 0.0
		for i in n1:
			low1 += sorted[sorted.size() - 1 - i]
		low1 /= n1
		var steady_max := sorted[sorted.size() - 1] if sorted.size() > 0 else 0.0
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/perf/q%d_%s.png" % [q, s])
		# Live switch round-trip: must not error and must restore the table values.
		var got := []
		var cb := func(level: int, st: Dictionary): got.append([level, st.get("foliage_density")])
		gs.quality_changed.connect(cb)
		gs.apply_quality((q + 2) % 5, false)
		await process_frame
		gs.apply_quality(q, false)
		await process_frame
		gs.quality_changed.disconnect(cb)
		var live_ok: bool = got.size() == 2 and got[1][0] == q and gs.settings.get("foliage_density") == gs.TABLE.foliage_density[q]
		print("SWEEP|q=%d|%s|load=%.0f|add=%.0f|spike=%.0f|hitch100=%d|avg=%.2f|low1=%.2f|steadymax=%.1f|draws=%d|objs=%d|prims=%d|mem=%.0f|vmem=%.0f|live=%s" % [q, s, load_ms, add_ms, spike, hitches, avg, low1, steady_max, draws, objs, prims, mem, vmem, live_ok])
		scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	print("SWEEP_END quality=%d" % q)
	quit(0)
