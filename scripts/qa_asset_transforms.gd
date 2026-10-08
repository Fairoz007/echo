extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene_path := "res://levels/Prologue.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("scene="):
			scene_path = argument.trim_prefix("scene=")
	var scene := load(scene_path) as PackedScene
	var level := scene.instantiate()
	root.add_child(level)
	current_scene = level
	var player := level.get_node("Player")
	player.toggle_flashlight()
	for i in range(90):
		await process_frame
	if "walk" in OS.get_cmdline_user_args():
		Input.action_press("move_forward")
		for i in range(55):
			await physics_frame
		print("WALK_CAPTURE position=", player.position, " animation=", player.anim_player.current_animation if player.anim_player else "NO_ANIMATION_PLAYER")
	print("RENDER_STATS scene=", scene_path, " fps=", Engine.get_frames_per_second(), " primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	await RenderingServer.frame_post_draw
	var tag := "after"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("tag="):
			tag = argument.trim_prefix("tag=")
	var output := "res://screenshots/prologue_asset_transform_" + tag + ".png"
	var result := root.get_texture().get_image().save_png(output)
	print("ASSET_CAPTURE ", output, " result=", result)
	Input.action_release("move_forward")
	# Keep the level alive until its opening dialogue sequence and HUD timers settle.
	await create_timer(12.0).timeout
	root.get_node("AudioManager").stop_dialogue()
	level.queue_free()
	await process_frame
	quit(result)
