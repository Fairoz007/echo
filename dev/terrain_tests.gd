extends SceneTree
## One locked rendered process. Optional --scenes=Chapter1,Prologue --skip-fixture.
const OUT := "res://screenshots/terrain/"
const TERRAIN_SHADERS := ["res://materials/cave_ground.gdshader", "res://systems/levelb/terrain_blend.gdshader", "res://materials/sediment_surface.gdshader"]
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("TERRAIN %s: %s" % [label, "PASS" if ok else "FAIL"])

func _quality(level: int) -> void:
	root.get_node("GraphicsSettings").apply_quality(level, false)
	Engine.max_fps = 60

func _run() -> void:
	root.get_node("SaveManager").save_directory = "user://qa_terrain"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_terrain"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_check("OpenGL Compatibility", not root.get_node("GraphicsSettings").is_forward_plus())
	var scenes := PackedStringArray(["Prologue", "Chapter1", "Chapter2", "Chapter3", "Chapter4", "Chapter5", "Chapter6", "Chapter7", "Chapter8", "Chapter9", "Chapter10", "Finale", "Epilogue"])
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--scenes="):
			scenes = argument.trim_prefix("--scenes=").split(",", false)
	if not "--skip-fixture" in arguments:
		await _imported_floor_fixture()
	for scene_name in scenes:
		_quality(4)
		var scene: Node = load("res://levels/%s.tscn" % scene_name).instantiate()
		root.add_child(scene)
		current_scene = scene
		var game := root.get_node("GameManager")
		game.current_state = game.GameState.GAMEPLAY
		await create_timer(4.0).timeout
		var ready := false
		for i in 600:
			ready = true
			for node in scene.find_children("*", "Node", true, false):
				if node.get_script() and node.get_script().resource_path == "res://systems/environment/CaveBuilder.gd" and not node.is_built:
					ready = false
			if ready:
				break
			await process_frame
		_check(scene_name + " terrain construction completed", ready)
		_quality(4)
		await create_timer(0.3).timeout
		root.get_node("AudioManager").stop_dialogue()
		var counts := _terrain_counts(scene)
		_check(scene_name + " upgraded main terrain", counts[0] + counts[1] > 0)
		if scene.get_node_or_null("CampaignExploration"):
			_check(scene_name + " optional floors included", counts[2] > 0)
		print("TERRAIN_COVERAGE %s cave=%d heightfield=%d imported=%d" % [scene_name, counts[0], counts[1], counts[2]])
		var before := _collision_signature(scene)
		var player := scene.get_node_or_null("Player") as Player
		if player:
			_check(scene_name + " existing Mara rig", player.get_skeleton().get_bone_count() == 41)
			var camera := Camera3D.new()
			camera.fov = 60.0
			scene.add_child(camera)
			camera.global_position = player.global_position + Vector3(2.0, 1.8, 2.8)
			camera.look_at(player.global_position + Vector3(0.0, -0.25, -1.8))
			camera.make_current()
		# Compare only terrain shading, at identical quality, camera and geometry.
		if scene_name in ["Prologue", "Chapter1"]:
			RenderingServer.global_shader_parameter_set("terrain_detail", 0.0)
			await _capture(scene_name + "_surface_before")
			RenderingServer.global_shader_parameter_set("terrain_detail", 1.0)
		await _capture(scene_name + "_surface_ultra")
		await _measure(scene_name)
		_quality(1)
		await process_frame
		_check(scene_name + " Low disables added relief", is_zero_approx(float(root.get_node("GraphicsSettings").settings.terrain_detail)))
		_check(scene_name + " Low restores imported materials", _terrain_counts(scene)[2] == 0)
		_quality(4)
		await process_frame
		_check(scene_name + " live Ultra restores material coverage", _terrain_counts(scene) == counts)
		_check(scene_name + " collision shapes unchanged", _collision_signature(scene) == before)
		current_scene = null
		scene.queue_free()
		await process_frame
		await process_frame
	print("TERRAIN_DONE checks=%d failures=%d scenes=%d" % [checks, failures, scenes.size()])
	quit(0 if failures == 0 else 1)

func _terrain_counts(scene: Node) -> PackedInt32Array:
	var result := PackedInt32Array([0, 0, 0])
	for item in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := item as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface) as ShaderMaterial
			if material and material.shader:
				var index := TERRAIN_SHADERS.find(material.shader.resource_path)
				if index >= 0:
					result[index] += 1
	return result

func _collision_signature(scene: Node) -> Array:
	var signature := []
	for node in scene.find_children("*", "CollisionShape3D", true, false):
		var collider := node as CollisionShape3D
		signature.append([collider.get_instance_id(), collider.shape.get_instance_id() if collider.shape else 0, collider.disabled, collider.transform])
	return signature

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check("capture " + label, root.get_texture().get_image().save_png(OUT + label + ".png") == OK)

func _measure(label: String) -> void:
	var times: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 700000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	var total := 0.0
	for value in times:
		total += value
	times.sort()
	print("TERRAIN_FRAME %s avg=%.2fms max=%.2fms draws=%d (0.7s stationary, cap60)" % [label, total / times.size(), times[-1], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])

func _imported_floor_fixture() -> void:
	_quality(1)
	var fixture := Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var floor_model: Node3D = load("res://assets/environment/cave/cave_floor_sediment.glb").instantiate()
	fixture.add_child(floor_model)
	var mesh := floor_model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var source := mesh.get_active_material(0) as BaseMaterial3D
	var original_mesh := mesh.mesh
	var detail: Node = load("res://systems/environment/TerrainSurfaceDetail.gd").new()
	floor_model.add_child(detail)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh.mesh.duplicate()
	batch.multimesh.instance_count = 1
	batch.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	fixture.add_child(batch)
	batch.add_child(load("res://systems/environment/TerrainSurfaceDetail.gd").new())
	for quality in [0, 1, 2, 3, 4, 1]:
		_quality(quality)
		var active := mesh.get_active_material(0)
		_check("imported floor quality %d swaps reversibly" % quality, (active is ShaderMaterial) if quality >= 2 else active == source)
		_check("sediment MultiMesh quality %d swaps reversibly" % quality, (batch.multimesh.mesh.surface_get_material(0) is ShaderMaterial) if quality >= 2 else batch.multimesh.mesh.surface_get_material(0) == source)
		_check("source floor geometry retained at %d" % quality, mesh.mesh == original_mesh)
		if quality == 4:
			var material := active as ShaderMaterial
			_check("imported albedo normal roughness atlases preserved", material.get_shader_parameter("albedo_tex") == source.albedo_texture and material.get_shader_parameter("normal_tex") == source.normal_texture and material.get_shader_parameter("roughness_tex") == source.roughness_texture)
			_check("source UV scale and offset preserved", material.get_shader_parameter("uv_scale") == source.uv1_scale and material.get_shader_parameter("uv_offset") == source.uv1_offset)
	fixture.queue_free()
	current_scene = null
	await process_frame
	await process_frame
