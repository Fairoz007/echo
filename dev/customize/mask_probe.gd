extends SceneTree
## Renders the customize preview with debug masks and several profiles. -s res://dev/customize/mask_probe.gd
func _shot(n: String) -> void:
	for i in 3: await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/customize"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/customize/%s.png" % n))
	print("[MASK] ", n)
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node("GraphicsSettings").apply_quality(1, false)
	var ma = root.get_node("MaraAppearance")
	ma.reset_profile()
	change_scene_to_file("res://ui/customize/CustomizeScreen.tscn")
	await create_timer(2.0).timeout
	var scr = current_scene
	ma.set_outfit_preset("Glacier")
	ma.profile.skin_tone = ma.SKIN_TONES[4]; ma.profile.skin_strength = 0.9
	ma.profile.hair_color = ma.HAIR_COLORS[3]; ma.set_value("hair_strength", 0.9)
	print("[MASK] profile ", ma.profile)
	await create_timer(0.5).timeout
	await _shot("probe_glacier")
	for mi in scr._model.find_children("*", "MeshInstance3D", true, false):
		print("[MASK] override ", mi.material_override)
		if mi.material_override is ShaderMaterial: mi.material_override.set_shader_parameter("debug_masks", 1.0)
	await _shot("probe_masks_front")
	scr._yaw += PI
	await create_timer(0.5).timeout
	await _shot("probe_masks_back")
	ma.reset_profile()
	quit()
