extends Node3D
## DEV ONLY. Water / waterfall / buoyancy / wind / grass test bed.
## Interactive: run dev/WaterTest.tscn. Keys: 1-6 cameras, L toggle low-quality water,
## R raise pool, F drain pool, C drop crate, W cycle wind strength.
## Automated: godot --path . res://dev/WaterTest.tscn -- --capture  (screenshots + checks
## written to screenshots/water/ and printed as WATER_TEST lines).

const CRATE := preload("res://systems/water/BuoyantCrate.tscn")
var pool: WaterBody
var river: WaterBody
var waterfall: Waterfall
var grass: GrassScatter
var cam: Camera3D
var crates: Array[RigidBody3D] = []
var markers: Array[MeshInstance3D] = []
var log_lines: PackedStringArray = []
var signal_log := []

const CAMS := {
	"pool_close": [Vector3(-13.5, 1.6, 6.5), Vector3(-9.5, -0.6, 0.5)],
	"pool_grazing": [Vector3(-16.5, 0.5, 0.0), Vector3(-6, -0.3, 0)],
	"waterfall": [Vector3(13.5, 1.5, -12.5), Vector3(7, -0.5, -22.5)],
	"river": [Vector3(10.5, 2.5, 4.0), Vector3(6.5, -1.6, -6.0)],
	"grass_trees": [Vector3(-2.0, 2.2, 18.0), Vector3(-10.0, 0.5, 8.0)],
	"markers_side": [Vector3(-9.6, 0.0, 3.6), Vector3(-9.8, -0.3, 0.0)],
	"waterfall_close": [Vector3(9.5, -0.6, -17.5), Vector3(7, 0.6, -24)],
	"overview": [Vector3(-24, 16, 24), Vector3(-2, -2, -4)],
}

func _ready() -> void:
	var gs := get_node_or_null("/root/GraphicsSettings")
	if gs:
		gs.apply_preset(2, false)
	_build_world()
	_set_cam("pool_close")
	if "--capture" in OS.get_cmdline_user_args():
		_run_capture()

# ------------------------------------------------------------------ world

func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.45, 0.62)
	sm.sky_horizon_color = Color(0.68, 0.72, 0.74)
	sm.ground_bottom_color = Color(0.2, 0.18, 0.15)
	sm.ground_horizon_color = Color(0.5, 0.5, 0.48)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.6, 0.66, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 300
	add_child(cam)

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_texture = load("res://assets/environment/cave/cave_floor_sediment_Color_9ebda37d-24d2-422f-b7e2-13565bd3ab05.jpg")
	ground_mat.uv1_triplanar = true
	ground_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	ground_mat.albedo_color = Color(0.75, 0.72, 0.62)
	ground_mat.roughness = 0.9
	var stone_mat := Waterfall.make_wet_rock_material(0.0, Color(0.42, 0.40, 0.36))

	# Ground blocks (top y=0) around a pool hole (x -14..-6, z -4..4) and a valley (x 2..12).
	_box(Vector3(-30, -4, -30), Vector3(-14, 0, 30), ground_mat, true)
	_box(Vector3(-6, -4, -30), Vector3(2, 0, 30), ground_mat, true)
	_box(Vector3(-14, -4, -30), Vector3(-6, 0, -4), ground_mat, true)
	_box(Vector3(-14, -4, 4), Vector3(-6, 0, 30), ground_mat, true)
	_box(Vector3(12, -6, -30), Vector3(30, 0, 30), ground_mat)
	# Pool floor + valley floor are wettable stone.
	_box(Vector3(-14, -4, -4), Vector3(-6, -2.5, 4), stone_mat, true)
	_box(Vector3(2, -6, -30), Vector3(12, -3.2, 30), stone_mat, true)
	# Pool walls visual inner faces are the ground blocks: mark them wettable too.
	# Slopes for grass rejection: steep (45 deg) and gentle (12 deg) ramps.
	_ramp(Vector3(-22, 0, -14), 45.0, ground_mat)
	_ramp(Vector3(-22, 0, -4), 12.0, ground_mat)
	# Rocks (static, zero wind, block grass via overlap test).
	var rock_mat := Waterfall.make_wet_rock_material(0.05, Color(0.45, 0.43, 0.40))
	for p in [Vector3(-18, 0.3, 10), Vector3(-4, 0.4, 12), Vector3(-12, 0.25, 16), Vector3(-2, 0.5, -10)]:
		_rock(p, rock_mat)

	pool = WaterBody.new()
	pool.name = "Pool"
	pool.preset_name = "RISING_PUZZLE_WATER"
	pool.size = Vector2(8, 8)
	pool.depth = 2.4
	pool.surface_level = -0.3
	pool.quality_override = 0
	pool.position = Vector3(-10, 0, 0)
	var audio := AudioStreamPlayer3D.new()
	audio.name = "FlowLoop"
	audio.stream = load("res://audio/ambience/cave/AMB_PRO_CAVE_WATER.wav")
	audio.volume_db = -12.0
	audio.autoplay = true
	pool.add_child(audio)
	pool.flow_audio = NodePath("FlowLoop")
	add_child(pool)
	for s in ["level_changed", "level_target_reached", "rise_started", "drain_started", "body_entered_water"]:
		pool.connect(s, func(a = null, b = null): signal_log.append(s))

	waterfall = Waterfall.new()
	waterfall.name = "Waterfall"
	waterfall.position = Vector3(7, -1.6, -24)
	waterfall.fall_height = 5.0
	waterfall.width = 3.0
	waterfall.basin_size = Vector2(10, 8)
	waterfall.downstream_length = 44.0
	waterfall.downstream_width = 10.0
	add_child(waterfall)
	river = waterfall.downstream

	for i in 4:
		_spawn_crate(Vector3(-11.5 + i * 1.3, 2.0 + i * 0.8, -1.5 + i))
	_spawn_crate(Vector3(7, -0.5, -10))
	_spawn_crate(Vector3(5.5, -0.5, -6))

	# Trees + ferns with tiered wind.
	for p in [Vector3(-20, 0, 20), Vector3(-8, 0, 22), Vector3(-25, 0, 6)]:
		_plant("res://assets/environment/jungle/jungle_tree.glb", p, 8.0)
	for p in [Vector3(-15, 0, 12), Vector3(-6, 0, 16), Vector3(-1, 0, 6)]:
		_plant("res://assets/environment/jungle/jungle_fern.glb", p, 1.5)

	grass = GrassScatter.new()
	grass.name = "Grass"
	grass.area_size = Vector2(30, 40)
	grass.density = 5.0
	grass.position = Vector3(-14, 0, 4)
	add_child(grass)

	# Surface markers: spheres placed at get_surface_height() every frame. If the
	# GDScript formula matches the shader they ride exactly on the waves.
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1, 0.25, 0.1)
	mm.emission_enabled = true
	mm.emission = Color(1, 0.2, 0.05)
	for i in 7:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.12
		m.mesh = s
		m.material_override = mm
		add_child(m)
		markers.append(m)

func _box(a: Vector3, b: Vector3, mat: Material, wettable := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	var size := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = (a + b) * 0.5
	add_child(body)
	if wettable:
		mi.add_to_group("wettable")
	return body

func _ramp(base: Vector3, deg: float, mat: Material) -> void:
	var body := _box(Vector3(-3, -0.5, -3), Vector3(3, 0.5, 3), mat)
	body.position = base + Vector3(0, 1.0, 0)
	body.rotation_degrees.x = deg

func _rock(p: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.1
	mi.mesh = sm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.8
	cs.shape = sh
	body.add_child(cs)
	body.position = p
	add_child(body)

func _plant(path: String, p: Vector3, h: float) -> void:
	var plant := (load(path) as PackedScene).instantiate() as Node3D
	plant.position = p
	add_child(plant)
	var wind := preload("res://systems/FoliageWind.gd").new()
	plant.add_child(wind)
	var aabb := AABB()
	for vi in plant.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = vi.global_transform * vi.get_aabb()
		aabb = a if aabb.size == Vector3.ZERO else aabb.merge(a)
	var scale_f := h / maxf(aabb.size.y, 0.01)
	plant.scale = Vector3.ONE * scale_f
	plant.position.y -= (aabb.position.y - p.y) * scale_f
	wind.configure(plant, h, 0.0, "tree" if h > 2.0 else "fern")
	wind.set_graphics_quality(2)

func _spawn_crate(p: Vector3) -> RigidBody3D:
	var c := CRATE.instantiate() as RigidBody3D
	c.position = p
	c.rotation_degrees = Vector3(randf() * 30, randf() * 90, randf() * 30)
	add_child(c)
	crates.append(c)
	return c

func _set_cam(n: String) -> void:
	var v: Array = CAMS[n]
	cam.global_position = v[0]
	cam.look_at(v[1])
	cam.current = true

func _process(_delta: float) -> void:
	for i in markers.size():
		var p := Vector3(-12.5 + i * 0.8, 0, 0.0)
		p.y = pool.get_surface_height(p)
		markers[i].global_position = p

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		var k: int = e.keycode
		if k >= KEY_1 and k <= KEY_8:
			_set_cam(CAMS.keys()[k - KEY_1])
		elif k == KEY_L:
			pool.quality_override = 1 if pool.quality_override == 0 else 0
			pool.set_graphics_quality(2)
		elif k == KEY_R:
			pool.set_level(-0.1, 3.0)
		elif k == KEY_F:
			pool.set_level(-1.8, 4.0)
		elif k == KEY_C:
			_spawn_crate(cam.global_position + -cam.global_basis.z * 4.0)
		elif k == KEY_W:
			WindSystem.set_wind(WindSystem.direction, fmod(WindSystem.strength + 1.0, 4.0))

# ------------------------------------------------------------------ automated capture

func _log(s: String) -> void:
	print("WATER_TEST ", s)
	log_lines.append(s)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://screenshots/water")
	img.save_png("res://screenshots/water/%s.png" % n)
	_log("screenshot %s.png" % n)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _measure(label: String) -> void:
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _frames(30)
	var cpu := 0.0
	var gpu := 0.0
	var wall := Time.get_ticks_usec()
	for i in 90:
		await get_tree().process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var frame_ms := (Time.get_ticks_usec() - wall) / 1000.0 / 90.0
	_log("perf %s frame_ms=%.2f render_cpu_ms=%.2f render_gpu_ms=%.2f" % [label, frame_ms, cpu / 90.0, gpu / 90.0])

func _run_capture() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(20)
	await get_tree().create_timer(5.0).timeout  # crates fall + settle

	# 1. Contract: height formula vs vertex shader (static sanity: same time base).
	var p := Vector3(-10, 0, 0)
	_log("contract surface_height=%.4f level=%.3f underwater(-1)=%s underwater(+1)=%s flow_river=%s" % [
		pool.get_surface_height(p), pool.get_level(), pool.is_point_underwater(Vector3(-10, -1, 0)),
		pool.is_point_underwater(Vector3(-10, 1, 0)), river.get_flow_velocity(river.global_position)])
	# 2. Buoyancy settle
	for i in 4:
		var c := crates[i]
		var surf := pool.get_surface_height(c.global_position)
		_log("buoyancy crate%d y=%.3f surface=%.3f draft=%.3f expected_draft~%.3f vel=%.3f submerged=%.2f" % [i, c.global_position.y, surf,
			surf - (c.global_position.y - 0.4), 0.8 * 160.0 / (1000.0 * 0.512 * 0.85) * 0.85, c.linear_velocity.length(), c.get_node("Buoyancy").submerged])
	var river_start := crates[4].global_position
	for n in CAMS.keys():
		_set_cam(n)
		await _frames(8)
		await _shot(n)
	await _measure("high_overview")
	_set_cam("pool_close")
	await _measure("high_pool_close")
	pool.quality_override = 1
	pool.set_graphics_quality(2)
	for b in [waterfall.basin, waterfall.downstream]:
		b.quality_override = 1
		b.set_graphics_quality(2)
	await _frames(5)
	await _shot("pool_close_LOW")
	await _measure("low_pool_close")
	_set_cam("waterfall")
	await _frames(5)
	await _shot("waterfall_LOW")
	pool.quality_override = 0
	pool.set_graphics_quality(2)
	for b in [waterfall.basin, waterfall.downstream]:
		b.quality_override = 0
		b.set_graphics_quality(2)
	_log("river crate moved %s in ~%.1fs (flow %s)" % [crates[4].global_position - river_start, 4.0, river.preset.flow_velocity])

	# 3. Rising / draining + wetness
	signal_log.clear()
	_set_cam("pool_close")
	pool.set_level(-0.2, 2.0)
	await get_tree().create_timer(2.3).timeout
	_log("rise level=%.3f signals=%s" % [pool.get_level(), _count(signal_log)])
	await _shot("pool_raised")
	signal_log.clear()
	pool.set_level(-1.9, 3.0)
	await get_tree().create_timer(1.5).timeout
	await _shot("pool_draining")
	await get_tree().create_timer(1.8).timeout
	_log("drain level=%.3f signals=%s wet_targets=%d" % [pool.get_level(), _count(signal_log), pool._wet_targets.size()])
	for i in 4:
		_log("after drain crate%d y=%.3f" % [i, crates[i].global_position.y])
	await _shot("pool_drained_wet")
	var saved := {}
	for gi in pool._wet_targets:
		saved[gi] = gi.material_overlay
		gi.material_overlay = null
	await _frames(2)
	await _shot("pool_drained_wet_OFF")
	for gi in saved:
		gi.material_overlay = saved[gi]
	_set_cam("pool_grazing")
	await _frames(4)
	await _shot("pool_drained_wet_grazing")
	# 4. Splash on drop
	pool.set_level(-0.3, 0.0)
	_set_cam("pool_close")
	await get_tree().create_timer(3.0).timeout
	var dc := _spawn_crate(Vector3(-8.0, 2.5, 2.5))
	await get_tree().create_timer(0.85).timeout
	await _shot("splash")
	# 5. Grass stats
	_log("grass %s" % [grass.stats])
	var high := 0
	for mmi in grass.find_children("*", "MultiMeshInstance3D", false, false):
		for j in mmi.multimesh.instance_count:
			var o: Vector3 = mmi.global_transform * mmi.multimesh.get_instance_transform(j).origin
			if o.y > 2.2:
				high += 1
				if high < 4: _log("grass_high_instance %s" % [o])
	_log("grass instances above 2.2m: %d" % high)
	# 6. Wind
	WindSystem.set_wind(Vector2(1, 0.3), 3.0, 0.8, 0.3)
	_set_cam("grass_trees")
	await get_tree().create_timer(1.0).timeout
	await _shot("grass_trees_strong_wind")
	await _measure("grass_trees")
	var f := FileAccess.open("res://screenshots/water/results.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	_log("DONE")
	get_tree().quit()

func _count(arr: Array) -> Dictionary:
	var d := {}
	for s in arr:
		d[s] = d.get(s, 0) + 1
	return d
