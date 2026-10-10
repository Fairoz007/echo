extends Node3D
## Per-level cave set dressing for chapter levels that were flat blockout planes.
## Builds a CaveBuilder hall (shell, ground, chasms, speleothems), rock masses that
## shape the route and screen the optional rooms, lamps, Vaelor glow, water bodies,
## landmark lights and a LOW-safe environment (no glow / SSAO / volumetrics).
## Configure entirely from the level .tscn via exports.

const CaveBuilder := preload("res://systems/environment/CaveBuilder.gd")
const WATER_BODY := preload("res://systems/water/WaterBody.tscn")

@export var profile_z := PackedFloat32Array([48, 30, 10, -10, -30, -52])
@export var profile_w := PackedFloat32Array([44, 46, 45, 46, 44, 40])
@export var profile_h := PackedFloat32Array([12, 16, 18, 16, 14, 10])
@export var seed_value := 1000
@export var stalactites := 160
@export var stalagmites := 60
@export var pebbles := 2500
@export var vein_start_z := -1000.0
@export var hole_rects: Array[Rect2] = []
@export var pit_depth := 22.0
@export var avoid_rects: Array[Rect2] = []
## Rock masses: x, z, radius, height (floor-to-ceiling columns / partitions)
@export var rock_masses: Array[Vector4] = []
@export var lamps: PackedVector3Array = PackedVector3Array()
@export var vaelor_lights: PackedVector3Array = PackedVector3Array()
## Water pools: x, z, size (square), surface y
@export var water_pools: Array[Vector4] = []
@export var water_preset := "CALM_CAVE_POOL"
## Existing CSG/mesh nodes that stand in for water: a WaterBody of the same footprint
## is added as a child (inherits visibility) and the proxy is made invisible.
@export var water_proxies: Array[NodePath] = []
@export var water_proxy_preset := "UNDERGROUND_STREAM"
@export var ambient_color := Color(0.12, 0.13, 0.15)
@export var ambient_energy := 0.9
@export var fog_color := Color(0.07, 0.08, 0.09)
@export var fog_density := 0.022
@export var exposure := 1.1
@export var hide_paths: Array[NodePath] = [] ## blockout visuals to hide (any Node3D)
## Blockout solids replaced by hero art: made invisible but keep their collision.
@export var ghost_paths: Array[NodePath] = []
@export var soundscape_key := "" ## e.g. "C02"; attaches systems/audio/Soundscape
@export var hall_reverb := "vast"
## Extra reverb zones: x, z, half-length along Z, preset index into REVERB_NAMES
@export var reverb_zones: Array[Vector4] = []
const REVERB_NAMES := ["tunnel", "cave", "ruin", "temple", "vast", "vault", "outdoor"]
const WATER_LOOP := "res://audio/ambience/cave/AMB_PRO_CAVE_WATER.ogg"
const DAYLIGHT_WIND := "res://audio/ambience/jungle/AMB_DAYLIGHT_RIDGE_WIND.ogg"
@export var daylight_exit := false ## open far end with a daylight portal

var cave: Node3D
var _lighting_environment: Environment

func _ready() -> void:
	# Chapter scripts add exploration rooms in their _ready; wait so they can be avoided.
	await get_tree().process_frame
	var level := get_parent()
	var avoid := avoid_rects.duplicate()
	var exploration := level.get_node_or_null("CampaignExploration")
	if exploration:
		for room in exploration.get_children():
			if room is Node3D and room.get_child_count() > 0:
				var p: Vector3 = room.global_position
				avoid.append(Rect2(p.x - 7.0, p.z - 7.0, 14.0, 14.0))
	for r in rock_masses:
		avoid.append(Rect2(r.x - r.z, r.y - r.z, r.z * 2.0, r.z * 2.0))
	cave = CaveBuilder.new()
	cave.name = "LevelCaveBuilder"
	cave.profile_z = profile_z
	cave.profile_w = profile_w
	cave.profile_h = profile_h
	cave.start_z = profile_z[0]
	cave.end_z = profile_z[profile_z.size() - 1]
	cave.slice_step = clampf((cave.start_z - cave.end_z) / 260.0, 0.33, 0.6)
	cave.seed_value = seed_value
	cave.stalactite_count = stalactites
	cave.stalagmite_count = stalagmites
	cave.pebble_count = pebbles
	cave.vein_start_z = vein_start_z
	cave.hole_rects = hole_rects
	cave.pit_depth = pit_depth
	cave.avoid_rects = avoid
	cave.route_clear = 3.0
	cave.cap_far = not daylight_exit
	var prof := OS.get_cmdline_user_args().has("--profile-build")
	var t := Time.get_ticks_usec()
	add_child(cave)
	if prof: print("[LevelCave] cave add %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	# Let the builder's heavy stages run on their own frames first.
	if not cave.is_built:
		await cave.built
	if not is_inside_tree():
		return
	await _rock_masses()
	if not is_inside_tree():
		return
	t = Time.get_ticks_usec()
	if daylight_exit:
		_daylight()
	_lights()
	_water()
	_environment()
	_audio()
	if prof: print("[LevelCave] lights/water/env/audio %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	for path in hide_paths:
		var n := level.get_node_or_null(path)
		if n is Node3D:
			n.visible = false
			n.set_meta("collision", "none")
	for path in ghost_paths:
		var g := level.get_node_or_null(path) as GeometryInstance3D
		if g:
			var clear := StandardMaterial3D.new()
			clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			clear.albedo_color = Color(0, 0, 0, 0)
			g.material_override = clear
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.set_meta("keep_material", true)
	# The shared sediment multimesh from CampaignEnvironmentArt would z-fight the new ground.
	var art := level.get_node_or_null("CampaignEnvironmentArt")
	if art:
		art.set_meta("hide_ground", true) # its ground may still be loading on a thread
		var ground := art.get_node_or_null("SedimentGroundInstances")
		if ground:
			ground.visible = false

func _rock_masses() -> void:
	var root := Node3D.new()
	root.name = "RockMasses"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 9
	for m in rock_masses:
		if not is_inside_tree():
			return
		var t := Time.get_ticks_usec()
		# Stack of overlapping irregular rocks from floor to (near) the ceiling.
		var radius := m.z
		var height := m.w
		var y := 0.0
		while y < height:
			var r := radius * rng.randf_range(0.75, 1.05) * (1.0 - 0.25 * y / maxf(height, 1.0))
			var body: StaticBody3D = cave.add_rock(root, Vector3(m.x + rng.randf_range(-0.4, 0.4) * radius, y + r * 0.45, m.y + rng.randf_range(-0.4, 0.4) * radius), r, Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4))
			y += r * 0.9
		if OS.get_cmdline_user_args().has("--profile-build"):
			print("[LevelCave] rock mass %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
		await get_tree().process_frame

func _lamp(pos: Vector3) -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.09
	cyl.height = 0.22
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.42)
	mat.emission_energy_multiplier = 2.5
	body.material_override = mat
	body.set_meta("collision", "none")
	add_child(body)
	body.position = Vector3(pos.x, cave.ground_y(pos.x, pos.z) + 0.11 + pos.y, pos.z)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 1.6
	light.omni_range = 11.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false # LOW-safe; GraphicsSettings may enable on higher tiers
	add_child(light)
	light.position = body.position + Vector3.UP * 0.3

func _lights() -> void:
	for p in lamps:
		_lamp(p)
	for p in vaelor_lights:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 0.85, 1.0)
		l.light_energy = 1.8
		l.omni_range = 12.0
		add_child(l)
		l.position = p

func _water() -> void:
	var level := get_parent()
	for i in water_pools.size():
		var w: Vector4 = water_pools[i]
		var body := WATER_BODY.instantiate()
		body.name = "Pool_%d" % i
		body.preset_name = water_preset
		body.size = Vector2(w.z, w.z)
		body.depth = 1.2
		add_child(body)
		body.global_position = Vector3(w.x, w.w, w.y)
	for path in water_proxies:
		var proxy := level.get_node_or_null(path) as GeometryInstance3D
		if proxy == null:
			continue
		var box: AABB = proxy.get_aabb()
		var body := WATER_BODY.instantiate()
		body.name = "WaterSurface"
		body.preset_name = water_proxy_preset
		body.size = Vector2(box.size.x, box.size.z)
		body.depth = maxf(box.size.y, 0.3)
		proxy.add_child(body)
		body.position = Vector3(box.get_center().x, box.end.y, box.get_center().z)
		var clear := StandardMaterial3D.new()
		clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		clear.albedo_color = Color(0, 0, 0, 0)
		proxy.material_override = clear
		proxy.set_meta("keep_material", true)
		proxy.set_meta("collision", "none")

func _environment() -> void:
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	var env := world.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	# GPU safety (user hard rule): nothing expensive.
	for prop in ["glow_enabled", "ssao_enabled", "ssil_enabled", "ssr_enabled", "sdfgi_enabled", "volumetric_fog_enabled"]:
		env.set(prop, false)
		if world.has_meta(prop):
			world.set_meta(prop, false)
	_lighting_environment = env
	# The cave is built asynchronously, after the initial GraphicsSettings scene pass.
	# Apply the current balance here as well as on later live quality switches.
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	if graphics:
		set_quality_settings(graphics.settings)

func set_quality_settings(settings: Dictionary) -> void:
	if _lighting_environment == null:
		return
	var detail := clampf(float(settings.get("natural_lighting", 0.0)), 0.0, 1.0)
	# Soft reflected fill reveals limestone in the city without washing out local
	# warm lamps/cool mineral lights. Keep authored brighter caves at their baseline.
	var fill := Color(maxf(ambient_color.r, 0.30), maxf(ambient_color.g, 0.32), maxf(ambient_color.b, 0.35), ambient_color.a)
	_lighting_environment.ambient_light_color = ambient_color.lerp(fill, detail)
	_lighting_environment.ambient_light_energy = lerpf(ambient_energy, maxf(ambient_energy, 1.05), detail)

func _daylight() -> void:
	var z: float = cave.end_z
	var sky := MeshInstance3D.new()
	sky.name = "DaylightOpening"
	var q := QuadMesh.new()
	q.size = Vector2(cave.width_at(z) * 2.0 + 8.0, cave.height_at(z) + 8.0)
	sky.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.86, 0.9, 0.95)
	sky.material_override = m
	sky.set_meta("collision", "none")
	sky.set_meta("keep_material", true)
	add_child(sky)
	sky.position = Vector3(0, q.size.y * 0.5 - 2.0, z - 1.5)
	var day := OmniLight3D.new()
	day.light_color = Color(1.0, 0.95, 0.85)
	day.light_energy = 3.0
	day.omni_range = 28.0
	day.omni_attenuation = 1.2
	add_child(day)
	day.position = Vector3(0, 4.0, z + 1.0)

func _audio() -> void:
	if soundscape_key == "":
		return
	var sc = preload("res://systems/audio/Soundscape.gd").attach(get_parent(), soundscape_key)
	if sc == null:
		return
	var zs: float = cave.start_z
	var ze: float = cave.end_z
	var max_w := 0.0
	var max_h := 0.0
	for v in profile_w:
		max_w = maxf(max_w, v)
	for v in profile_h:
		max_h = maxf(max_h, v)
	sc.add_reverb_zone(Vector3(0, max_h * 0.5, (zs + ze) * 0.5), Vector3(max_w * 2.0, max_h + 4.0, zs - ze), hall_reverb)
	for r in reverb_zones:
		var hl: float = r.z
		sc.add_reverb_zone(Vector3(r.x, 4.0, r.y), Vector3(cave.width_at(r.y) * 2.0, 10.0, hl * 2.0), REVERB_NAMES[clampi(int(r.w), 0, REVERB_NAMES.size() - 1)])
	for w in water_pools:
		sc.add_emitter(WATER_LOOP, Vector3(w.x, w.w + 0.3, w.y), -8.0, 18.0)
	if daylight_exit:
		sc.add_emitter(DAYLIGHT_WIND, Vector3(0, 3.0, ze), -2.0, 45.0)
