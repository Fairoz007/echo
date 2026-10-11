extends SceneTree
## Captures a level's opening frame (default Chapter 6; --level=res://...) and reports what the camera ray hits.
## Usage: godot --path . --rendering-method gl_compatibility -s res://dev/ch6_spawn_capture.gd -- --out=<png>

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := "user://ch6_spawn.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var level := "res://levels/Chapter6.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
	var lvl: Node = load(level).instantiate()
	root.add_child(lvl)
	for i in 90:
		await process_frame
	var cam := root.get_viewport().get_camera_3d()
	var player := lvl.get_node("Player") as Node3D
	print("CAM ", cam.global_position, " PLAYER ", player.global_position)
	# List visual meshes whose AABB contains the camera (foliage has no collision).
	for n in lvl.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi.is_visible_in_tree():
			var box := vi.global_transform * vi.get_aabb()
			if box.grow(0.3).has_point(cam.global_position) and box.size.length() < 60.0:
				print("CAM_INSIDE ", vi.get_path(), " ", box)
	root.get_viewport().get_texture().get_image().save_png(out)
	print("SAVED ", out)
	quit(0)
