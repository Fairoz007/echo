extends SceneTree
## LOW-safe level captures. Launch ONLY with:
## --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720
## Args: -- --level=2 --tag=name --views=x,y,z>x,y,z;...
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var level := 2
	var tag := "lvl"
	var views := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): level = int(a.trim_prefix("--level="))
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		if a.begins_with("--views="):
			for v in a.trim_prefix("--views=").split(";"):
				var parts := v.split(">")
				var p0 := parts[0].split_floats(","); var p1 := parts[1].split_floats(",")
				views.append([Vector3(p0[0], p0[1], p0[2]), Vector3(p1[0], p1[1], p1[2])])
	var gs := root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_preset"):
		gs.apply_preset(0, false)
	var gm := root.get_node("GameManager")
	var scene := (load(gm.chapter_scene(level)) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(4.0).timeout
	root.get_node("AudioManager").stop_dialogue()
	var dir := "res://screenshots/environment"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_gameplay.png" % [dir, tag])
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.far = 300.0
	for i in views.size():
		cam.global_position = views[i][0]
		cam.look_at(views[i][1])
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_view%d.png" % [dir, tag, i])
	print("CAPTURED ", tag, " views=", views.size())
	scene.queue_free()
	await process_frame
	quit(0)
