extends SceneTree
func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 3.1, 10)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true
	camera.fov = 30.0
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.15, 0.19)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	environment.ambient_light_energy = 0.8
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.6
	stage.add_child(light)
	var models := ["elias/source/CHR_Elias_Rig", "nadiya/source/CHR_Nadiya_Rig", "tomas/source/CHR_Tomas_Rig", "adrian/source/CHR_Adrian_Rig", "drake/source/CHR_Drake_Rig", "meridian/base/source/CHR_Meridian_Rig"]
	var heights := [1.8, 1.67, 1.84, 1.78, 1.86, 1.82]
	for i in range(models.size()):
		var actor := load("res://systems/ProductionCharacter.gd").new() as Node3D
		actor.model_path = "res://assets/characters/" + models[i] + ".glb"
		actor.character_height = heights[i]
		actor.position.x = float(i) * 1.5 - 3.75
		actor.rotation.y = PI
		stage.add_child(actor)
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	print("GALLERY_CAPTURE result=",root.get_texture().get_image().save_png("res://screenshots/production_character_gallery.png"))
	stage.queue_free()
	await process_frame
	quit()
