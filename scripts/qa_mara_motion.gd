extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveManager").save_directory = "user://qa_mara"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_mara"))
	root.get_node("GameManager").start_new_game()
	await create_timer(0.8).timeout
	var player = get_first_node_in_group("player")
	var skeleton: Skeleton3D = player.visual_mesh.find_child("Skeleton3D", true, false)
	if not skeleton or not player.anim_player:
		printerr("QA FAILED: Mara rig or animation player missing")
		quit(1)
		return
	var checked_hip_track := false
	print("MARA skeleton origin=", skeleton.global_position, " player=", player.global_position)
	for clip in ["idle", "walk"]:
		var animation: Animation = player.anim_player.get_animation(clip)
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
				print(clip, " position track ", animation.track_get_path(track), " first=", animation.track_get_key_value(track, 0), " last=", animation.track_get_key_value(track, animation.track_get_key_count(track) - 1))
				if clip == "walk" and "Hip" in str(animation.track_get_path(track)):
					checked_hip_track = true
					var first: Vector3 = animation.track_get_key_value(track, 0)
					for key in range(animation.track_get_key_count(track)):
						var value: Vector3 = animation.track_get_key_value(track, key)
						if absf(value.x - first.x) > 0.0001 or absf(value.y - first.y) > 0.0001:
							printerr("QA FAILED: walk clip Hip X/Y drift remains")
							quit(1)
							return
	if not checked_hip_track:
		printerr("QA FAILED: walk Hip translation track not inspected")
		quit(1)
		return
	Input.action_press("move_forward")
	for frame in range(120):
		await physics_frame
	Input.action_release("move_forward")
	print("MARA walk skeleton origin=", skeleton.global_position, " player=", player.global_position, " root pose=", skeleton.get_bone_global_pose(0).origin)
	print("QA PASS: Mara walk Hip translation remains in-place at every key")
	root.get_node("AudioManager").stop_dialogue()
	change_scene_to_file("res://ui/MainMenu.tscn")
	await create_timer(12.0).timeout
	quit()
