extends SceneTree

## Windowed environment captures: gameplay camera + staged review cameras.
## Usage: godot --path . -s res://scripts/qa_environment_capture.gd -- --levels=0 --tag=after
const VIEWS := {
	0: [[Vector3(0, 1.7, 3.0), Vector3(0, 1.2, -8)], [Vector3(-2.0, 2.2, -6.5), Vector3(1.0, 0.8, -14)], [Vector3(1.5, 1.8, -16), Vector3(0, 2.0, -29)], [Vector3(0, 0.6, -10), Vector3(0, 5.5, -13)], [Vector3(1.5, 1.6, -9.5), Vector3(-4.2, 2.0, -13.2)], [Vector3(0.5, 1.4, 1.5), Vector3(-0.5, 0, -5)], [Vector3(3.0, 1.7, -17.5), Vector3(-1.5, 4.0, -13.5)]],
}

func _init() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := "res://screenshots/environment"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	root.get_texture().get_image().save_png(dir + "/" + name + ".png")
	print("CAPTURE ", dir, "/", name, ".png")

func _run() -> void:
	var gm := root.get_node("GameManager")
	root.get_node("SaveManager").save_directory = "user://qa_env_capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_env_capture"))
	var levels := [0]
	var tag := "shot"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			levels = Array(a.trim_prefix("--levels=").split(",")).map(func(x): return int(x))
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	for chapter in levels:
		gm.load_chapter(chapter, gm.chapter_scene(chapter))
		await create_timer(2.5).timeout
		root.get_node("AudioManager").stop_dialogue()
		await _shot("%s_L%02d_gameplay" % [tag, chapter])
		var cam := Camera3D.new()
		current_scene.add_child(cam)
		cam.current = true
		var views: Array = VIEWS.get(chapter, [[Vector3(0, 6, 14), Vector3(0, 1, -6)], [Vector3(10, 4, -4), Vector3(-6, 1, -20)]])
		for i in views.size():
			cam.global_position = views[i][0]
			cam.look_at(views[i][1])
			await create_timer(0.4).timeout
			await _shot("%s_L%02d_view%d" % [tag, chapter, i])
	gm.return_to_menu()
	await create_timer(1.0).timeout
	quit(0)
