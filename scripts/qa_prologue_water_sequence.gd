extends SceneTree

## LOW-preset frame sequences of Prologue water, waterfall and fern wind.
## Launch ONLY with: --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720
## Writes screenshots/environment/seq_<view>_<n>.png (6 frames over ~2.5 s per view).
const OUT := "res://screenshots/environment"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var gs := root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_preset"):
		gs.apply_preset(0, false)
	var scene := (load("res://levels/Prologue.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(3.0).timeout
	for n in scene.find_children("*", "Node", true, false):
		if n.has_method("set_graphics_quality"):
			n.set_graphics_quality(0)
	var am := root.get_node_or_null("AudioManager")
	if am:
		am.stop_dialogue()
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.current = true
	var views := {
		"waterfall": [Vector3(1.8, 1.8, -11.0), Vector3(-4.2, 2.0, -14.0)],
		"pool": [Vector3(-0.8, 1.3, -12.2), Vector3(-3.4, 0.0, -14.2)],
		"ferns": [Vector3(1.6, 1.2, -12.4), Vector3(-0.5, 0.3, -13.8)],
	}
	var puddles := scene.find_children("Puddle_*", "Node3D", true, false)
	if puddles.size() > 0:
		var p: Vector3 = puddles[min(1, puddles.size() - 1)].global_position
		views["puddle"] = [p + Vector3(1.2, 1.1, 1.4), p]
	for key in views:
		cam.global_position = views[key][0]
		cam.look_at(views[key][1])
		await create_timer(0.5).timeout
		for i in 6:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/seq_%s_%d.png" % [OUT, key, i])
			await create_timer(0.45).timeout
		print("SEQ ", key, " done")
	scene.queue_free()
	await process_frame
	quit(0)
