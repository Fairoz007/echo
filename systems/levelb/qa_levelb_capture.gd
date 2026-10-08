extends SceneTree

## Level B capture harness (Chapter 1/5/6/8/Epilogue).
## Usage (LOW preset, compat renderer, <=1280x720):
##   godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --resolution 1280x720 -s res://systems/levelb/qa_levelb_capture.gd -- --quality=1 --levels=1 --tag=iter1 [--seq] [--drain]
## Writes res://screenshots/levelb/<tag>_L<nn>_*.png and a per-run log.
const VIEWS := {
	1: [
		["camp_overview", Vector3(14, 7, 34), Vector3(0, 1, 4)],
		["camp_close", Vector3(5, 2.2, 13), Vector3(0, 1.2, 4)],
		["ground_blend", Vector3(-8, 2.5, 22), Vector3(-2, 0, 8)],
		["trail_ridge", Vector3(4, 4, -10), Vector3(0, 6, -60)],
		["ridge_portal", Vector3(5, 9.5, -46), Vector3(0, 9, -63)],
		["cliffline", Vector3(-12, 14, -30), Vector3(12, 12, -70)],
		["secondary_route", Vector3(-22, 3, -4), Vector3(-30, 3, -30)],
		["gorge", Vector3(40, 3.5, -20), Vector3(46, 5, -40)],
	],
	5: [
		["overview", Vector3(0, 22, 40), Vector3(0, 0, -10)],
		["approach", Vector3(0, 2.2, 30), Vector3(0, 1.5, 0)],
		["checkpoint", Vector3(10, 4, 10), Vector3(-2, 1, -6)],
		["tower", Vector3(-6, 3, 4), Vector3(-14, 6, -6)],
		["flank_route", Vector3(24, 3, 18), Vector3(18, 2, -16)],
		["overlook", Vector3(0, 8, -14), Vector3(0, -2, -40)],
	],
	6: [
		["entry", Vector3(0, 2.0, 22), Vector3(0, 0, 0)],
		["basin_overview", Vector3(8, 7, 22), Vector3(-6, -2, -2)],
		["hydraulics", Vector3(-3, 3, 4), Vector3(-14, 2, -2)],
		["underwater", Vector3(4, -2.4, 12), Vector3(-4, -3.6, 0)],
		["sanctum", Vector3(0, 3, -10), Vector3(0, 2, -26)],
	],
	8: [
		["sanctuary", Vector3(8, 4, 14), Vector3(0, 1, 0)],
		["staging", Vector3(4, 2.0, 5), Vector3(-1, 1.2, -1)],
		["passage", Vector3(0, 3, -12), Vector3(0, 2, -32)],
		["arena", Vector3(-12, 6, -16), Vector3(4, 1, -40)],
	],
	12: [
		["dawn", Vector3(0, 3, 16), Vector3(0, 2, -10)],
		["vista", Vector3(10, 6, 8), Vector3(-4, 4, -40)],
	],
}
var tag := "shot"
var dir := "res://screenshots/levelb"

func _init() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s_%s.png" % [dir, tag, name]
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)

func _run() -> void:
	var gm := root.get_node("GameManager")
	root.get_node("SaveManager").save_directory = "user://qa_levelb_capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_levelb_capture"))
	var levels := [1]
	var seq := false
	var drain := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			levels = Array(a.trim_prefix("--levels=").split(",")).map(func(x): return int(x))
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a == "--seq":
			seq = true
		elif a == "--drain":
			drain = true
	for chapter in levels:
		change_scene_to_file(gm.chapter_scene(chapter))
		await create_timer(3.0).timeout
		var am := root.get_node_or_null("AudioManager")
		if am and am.has_method("stop_dialogue"):
			am.stop_dialogue()
		var prefix := "L%02d" % chapter
		await _shot(prefix + "_gameplay")
		if not (current_scene is Node3D):
			await create_timer(4.0).timeout
			await _shot(prefix + "_t7")
			continue
		var cam := Camera3D.new()
		cam.far = 600.0
		current_scene.add_child(cam)
		cam.current = true
		for v in VIEWS.get(chapter, []):
			cam.global_position = v[1]
			cam.look_at(v[2])
			await create_timer(0.35).timeout
			await _shot("%s_%s" % [prefix, v[0]])
		if seq:
			# Frame sequence: wind / water / idle motion over ~2 s from the first view.
			var v0: Array = VIEWS[chapter][1 if VIEWS[chapter].size() > 1 else 0]
			cam.global_position = v0[1]
			cam.look_at(v0[2])
			for f in 6:
				await create_timer(0.33).timeout
				await _shot("%s_seq%02d" % [prefix, f])
		if drain and current_scene.has_method("debug_drain"):
			current_scene.debug_drain()
			await create_timer(9.0).timeout
			for v in VIEWS.get(chapter, []):
				cam.global_position = v[1]
				cam.look_at(v[2])
				await create_timer(0.3).timeout
				await _shot("%s_drained_%s" % [prefix, v[0]])
		cam.queue_free()
	gm.return_to_menu()
	await create_timer(0.8).timeout
	quit(0)
