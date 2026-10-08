extends SceneTree

## Scoped render fixtures; camera staging is not a gameplay progression test.
func _init() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png("res://screenshots/" + name + ".png")
	if result != OK:
		push_error("Graphics screenshot failed: " + name)
		quit(1)
	print("VISUAL CAPTURE ", name, " fps=", Engine.get_frames_per_second())

func _run() -> void:
	var gm := root.get_node("GameManager")
	var graphics := root.get_node("GraphicsSettings")
	root.get_node("SaveManager").save_directory = "user://qa_graphics_visual"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_graphics_visual"))
	var chapters := [6] if OS.get_cmdline_user_args().has("--qa-water-only") else [1, 6]
	for chapter in chapters:
		gm.load_chapter(chapter, gm.chapter_scene(chapter))
		await create_timer(2.0).timeout
		if chapter == 1:
			get_first_node_in_group("player").global_position = Vector3(0, 1, 15)
		else:
			var camera := Camera3D.new()
			current_scene.add_child(camera)
			camera.global_position = Vector3(8, 8, 15)
			camera.look_at(Vector3(0, 0.6, -8))
			camera.current = true
		for quality in [0, 1, 2]:
			graphics.apply_preset(quality, false)
			await create_timer(2.0).timeout
			await _capture("graphics_C%d_%s" % [chapter, graphics.PRESETS[quality]])
			if chapter == 6 and quality == 1:
				await create_timer(0.7).timeout
				await _capture("graphics_C6_Balanced_wave_b")
		if chapter == 6:
			# Cosmetic/drain inspection; real input route is independently tested.
			current_scene._on_sluice_wheel_rotated(get_first_node_in_group("player"))
			await create_timer(4.4).timeout
			await _capture("graphics_C6_High_drained")
	graphics.apply_preset(0, false)
	gm.return_to_menu()
	await create_timer(14.0).timeout
	print("QA PASS: Compatibility water/wind/ground shader compilation and captures")
	quit(0)
