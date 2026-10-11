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
	# Optional fixed shot: --cam=x,y,z --look=x,y,z (detaches from the follow rig).
	var cam_at := ""
	var look_at := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="): cam_at = a.substr(6)
		if a.begins_with("--look="): look_at = a.substr(7)
	# --aim=PhotoDressing: frame the nth placed dressing prop (verifies what scatter put where).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--aim="):
			var parts := a.substr(6).split(":")
			var holder := lvl.get_node_or_null(parts[0])
			if holder and holder.get_child_count() > 0:
				var target := holder.get_child(int(parts[1]) % holder.get_child_count()) as Node3D
				var tp := target.global_position
				cam_at = "%f,%f,%f" % [tp.x + 3.5, tp.y + 2.2, tp.z + 3.5]
				look_at = "%f,%f,%f" % [tp.x, tp.y + 0.5, tp.z]
				print("AIM ", target.name, " at ", tp)
	if cam_at != "":
		var c := cam_at.split_floats(",")
		var l := look_at.split_floats(",")
		var shot := Camera3D.new()
		lvl.add_child(shot)
		shot.global_position = Vector3(c[0], c[1], c[2])
		shot.look_at(Vector3(l[0], l[1], l[2]))
		shot.current = true
		for i in 10:
			await process_frame
		cam = shot
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
