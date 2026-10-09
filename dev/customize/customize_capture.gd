extends SceneTree
## Usage: -s res://dev/customize/customize_capture.gd -- --quality=1 [--level=res://levels/Chapter1.tscn]
var out_dir := "res://screenshots/customize"
var level := "res://levels/Chapter1.tscn"

func _shot(n: String) -> void:
	for i in 3:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var p := ProjectSettings.globalize_path(out_dir.path_join(n + ".png"))
	root.get_texture().get_image().save_png(p)
	print("[CUSTCAP] ", p)

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): level = a.get_slice("=", 1)
	root.get_node("GraphicsSettings").apply_quality(1, false)
	root.get_node("SaveManager").save_directory = "user://qa_customize"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_customize"))
	var ma = root.get_node("MaraAppearance")
	ma.reset_profile()
	change_scene_to_file("res://ui/MainMenu.tscn")
	await _wait(1.5)
	await _shot("main_menu")
	current_scene.get_node("VBoxContainer/BtnCustomize").pressed.emit()
	await _wait(2.0)
	await _shot("cust_default")
	var scr = current_scene
	# Non-default profile
	ma.set_outfit_preset("Glacier")
	ma.profile.skin_tone = ma.SKIN_TONES[4]; ma.profile.skin_strength = 0.9
	ma.profile.hair_color = ma.HAIR_COLORS[3]; ma.profile.hair_strength = 0.9
	for a in ma.ACCESSORIES: ma.profile[a] = true
	ma.profile.height = 1.0
	ma.profile.build = 1.04
	ma.set_value("hat", true)
	await _wait(0.8)
	await _shot("cust_custom_front")
	for t in range(1, 4):
		scr._tabs.current_tab = t
		await _wait(0.3)
		await _shot("cust_tab%d" % t)
	scr._yaw += PI; scr._target_dist = 2.0
	await _wait(1.0)
	await _shot("cust_custom_back")
	scr._yaw -= PI * 0.5; scr._target_dist = 1.0
	await _wait(1.0)
	await _shot("cust_custom_side_close")
	scr._yaw += PI * 0.5; scr._target_dist = 1.0
	await _wait(1.0)
	await _shot("cust_custom_face")
	var dbg = OS.get_cmdline_user_args().has("--masks")
	if dbg:
		for mi in scr._model.find_children("*", "MeshInstance3D", true, false):
			if mi.material_override is ShaderMaterial: mi.material_override.set_shader_parameter("debug_masks", 1.0)
		scr._target_dist = 2.3
		await _wait(1.0)
		await _shot("cust_masks")
	ma.save_profile()
	scr._save()
	# In-game with the saved non-default profile
	change_scene_to_file(level)
	await _wait(7.0)
	var gm = root.get_node("GameManager")
	gm.change_state(gm.GameState.GAMEPLAY)
	await _wait(1.5)
	await _shot("ingame_" + level.get_file().get_basename())
	var player = get_first_node_in_group("player")
	if player:
		var sk = ma.skeleton_of(player)
		print("[CUSTCAP] skeleton ", sk, " scale ", sk.scale if sk else null, " accs ", get_nodes_in_group(ma.ATTACH_GROUP).size())
		var cam = root.get_camera_3d()
		if cam:
			# side close-up from a temporary camera
			var c := Camera3D.new()
			player.get_parent().add_child(c)
			c.global_position = player.global_position + player.global_basis * Vector3(2.2, 1.4, 0.8)
			c.look_at(player.global_position + Vector3.UP * 1.0)
			c.current = true
			await _wait(0.5)
			await _shot("ingame_side")
			var forward := Vector3(0, 0, -1)
			if player.get("facing_yaw") is float:
				forward = Vector3(sin(player.facing_yaw), 0, cos(player.facing_yaw))
			c.global_position = player.global_position + forward * 2.0 + Vector3.UP * 1.5
			c.look_at(player.global_position + Vector3.UP * 1.1)
			await _wait(0.5)
			await _shot("ingame_front")
	ma.reset_profile()
	ma.save_profile()
	quit()
