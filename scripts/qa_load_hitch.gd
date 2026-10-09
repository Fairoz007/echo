extends SceneTree
## Measures the worst frame during a chapter load (headless). -- --level=9
var worst := 0.0
var last := 0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var level := 9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): level = int(a.trim_prefix("--level="))
	var gm := root.get_node("GameManager")
	await create_timer(0.5).timeout
	gm.load_chapter(level, gm.chapter_scene(level))
	last = Time.get_ticks_usec()
	var worst_at := 0
	for f in 600:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		if dt > worst:
			worst = dt
			worst_at = f
		last = now
	print("LOAD HITCH level=%d worst_frame_ms=%.1f at frame %d" % [level, worst, worst_at])
	quit()
