extends SceneTree
## Rendered GL regression/capture for natural lighting and retained rock PBR maps.
## Run through dev/run_recovery_test.ps1 with --quality=4; saves are isolated below.
const OUT := "res://screenshots/lighting/"
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("LIGHTING %s: %s" % [label, "PASS" if ok else "FAIL"])

func _run() -> void:
	root.get_node("SaveManager").save_directory = "user://qa_lighting_materials"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_lighting_materials"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var graphics := root.get_node("GraphicsSettings")
	_check("Compatibility renderer", not graphics.is_forward_plus())
	var arguments := OS.get_cmdline_user_args()
	if not "--skip-material-contract" in arguments:
		_material_contract()
	var chapters := PackedStringArray(["Chapter1", "Chapter7"])
	for argument in arguments:
		if argument.begins_with("--chapters="):
			chapters = argument.trim_prefix("--chapters=").split(",", false)
	for chapter in chapters:
		graphics.apply_quality(4, false)
		Engine.max_fps = 60
		var level := (load("res://levels/%s.tscn" % chapter) as PackedScene).instantiate()
		root.add_child(level)
		current_scene = level
		var game := root.get_node("GameManager")
		game.current_state = game.GameState.GAMEPLAY
		# Allow asynchronous cave/dressing/collision construction to finish.
		await create_timer(6.0).timeout
		graphics.apply_quality(4, false)
		Engine.max_fps = 60
		await create_timer(1.0).timeout
		root.get_node("AudioManager").stop_dialogue()
		var holder := level.get_node("WorldEnvironment") as WorldEnvironment
		var environment := holder.environment
		var lighting: Node = level.get_node("LevelBDressing" if chapter == "Chapter1" else "LevelCave")
		_check(chapter + " lighting initialized after asynchronous build", lighting.get("_lighting_environment") == environment)
		var player := level.get_node("Player") as Player
		_check(chapter + " existing Mara rig", player.get_skeleton().get_bone_count() == 41)
		var collision_count := level.find_children("*", "CollisionShape3D", true, false).size()
		var ultra_color := environment.ambient_light_color
		var ultra_energy := environment.ambient_light_energy
		var ultra_sun_energy := 0.0
		if chapter == "Chapter1":
			ultra_sun_energy = level.get_node("SunLight").light_energy
		# Compare only the new lighting at identical Ultra geometry, AA and camera.
		lighting.set_quality_settings({"natural_lighting": 0.0})
		await create_timer(0.6).timeout
		var baseline_energy := environment.ambient_light_energy
		var baseline_color := environment.ambient_light_color
		await _capture(chapter + "_authored_lighting")
		lighting.set_quality_settings(graphics.settings)
		await create_timer(0.6).timeout
		_check(chapter + " lighting changes rendered scene", not is_equal_approx(baseline_energy, environment.ambient_light_energy) or baseline_color != environment.ambient_light_color)
		_check(chapter + " lighting restoration does not accumulate", is_equal_approx(ultra_energy, environment.ambient_light_energy) and ultra_color == environment.ambient_light_color)
		await _capture(chapter + "_ultra")
		await _measure(chapter)
		# Full live downgrade then upgrade checks consumer propagation and restores.
		graphics.apply_quality(1, false)
		await create_timer(0.6).timeout
		_check(chapter + " Low preserves authored lighting", is_equal_approx(environment.ambient_light_energy, baseline_energy) and environment.ambient_light_color == baseline_color)
		_check(chapter + " Low disables costly environment effects", not environment.ssao_enabled and not environment.ssil_enabled and not environment.ssr_enabled and not environment.volumetric_fog_enabled)
		graphics.apply_quality(4, false)
		Engine.max_fps = 60
		await create_timer(0.6).timeout
		_check(chapter + " live Ultra restores lighting", is_equal_approx(environment.ambient_light_energy, ultra_energy) and environment.ambient_light_color == ultra_color)
		if chapter == "Chapter1":
			_check("sun balance restored", is_equal_approx(level.get_node("SunLight").light_energy, ultra_sun_energy))
		_check(chapter + " collision shapes preserved", collision_count == level.find_children("*", "CollisionShape3D", true, false).size())
		_check(chapter + " player supported by floor", player.is_on_floor())
		current_scene = null
		level.queue_free()
		await process_frame
		await process_frame
	print("LIGHTING_DONE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _material_contract() -> void:
	# Loading after autoload initialization avoids compiling LBCollectible before
	# MissionManager exists when this harness is launched with Godot's -s flag.
	var kit: GDScript = load("res://systems/levelb/LBKit.gd")
	var mesh := ArrayMesh.new()
	var quad := QuadMesh.new()
	var source: Array[StandardMaterial3D] = []
	var albedo := _texture(Color(0.4, 0.35, 0.3))
	for i in 2:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
		var material := StandardMaterial3D.new()
		material.albedo_texture = albedo
		material.normal_enabled = true
		material.normal_texture = _texture(Color(0.5, 0.5, 1.0))
		material.normal_scale = 0.3 + i * 0.5
		material.roughness = 0.6 + i * 0.3
		material.roughness_texture = _texture(Color(0.2, 0.7, 0.4))
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN if i == 0 else BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		source.append(material)
		mesh.surface_set_material(i, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var style: ShaderMaterial = kit.rock_material()
	style = style.duplicate()
	style.set_shader_parameter("specular_amount", 0.23)
	kit.override_material(instance, style)
	_check("multi-surface rock is not flattened to surface zero", instance.material_override == null and instance.get_surface_override_material(0) != instance.get_surface_override_material(1))
	for i in 2:
		var material := instance.get_surface_override_material(i) as ShaderMaterial
		var channel := Vector4(0, 1, 0, 0) if i == 0 else Vector4(0, 0, 1, 0)
		_check("surface %d retains PBR atlas and strength" % i,
			material.get_shader_parameter("rock_tex") == albedo
			and material.get_shader_parameter("rock_nrm") == source[i].normal_texture
			and is_equal_approx(material.get_shader_parameter("normal_strength"), source[i].normal_scale)
			and material.get_shader_parameter("rock_roughness") == source[i].roughness_texture
			and is_equal_approx(material.get_shader_parameter("source_roughness"), source[i].roughness)
			and material.get_shader_parameter("roughness_channel") == channel)
		_check("surface %d specular style survives default contrast" % i, is_equal_approx(material.get_shader_parameter("specular_amount"), 0.23))
	var orm := ORMMaterial3D.new()
	orm.orm_texture = _texture(Color(0.7, 0.3, 0.0))
	var orm_result: ShaderMaterial = kit.rock_material(Color.WHITE, 0.0, -1000.0, albedo, null, orm)
	_check("packed ORM roughness uses green", orm_result.get_shader_parameter("rock_roughness") == orm.orm_texture and orm_result.get_shader_parameter("roughness_channel") == Vector4(0, 1, 0, 0))
	_check("disabled source normals remain disabled", not orm_result.get_shader_parameter("has_normal"))
	_check("identical source reuses cache", orm_result == kit.rock_material(Color.WHITE, 0.0, -1000.0, albedo, null, orm))
	var close_tint: ShaderMaterial = kit.rock_material(Color(0.999, 1, 1), 0.0, -1000.0, albedo, null, orm)
	_check("nearby tints do not collide in cache", orm_result != close_tint)
	instance.free()

func _texture(color: Color) -> ImageTexture:
	var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(color)
	return ImageTexture.create_from_image(pixels)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + label + ".png")
	_check("capture " + label, result == OK)

func _measure(label: String) -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 1500000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var total := 0.0
	for value in samples:
		total += value
	samples.sort()
	print("LIGHTING_FRAME %s avg=%.2fms p99=%.2fms draws=%d (stationary 1.5s, cap 60)" % [label, total / samples.size(), samples[mini(samples.size() - 1, int(samples.size() * 0.99))], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
