extends SubViewportContainer
## Epilogue "Daylight": a calm sunrise vista rendered behind the narrative/credits text.
## Survivors on the ridge outcrop above the mist valley, wind in the trees, river below,
## slow camera drift. Built entirely at runtime; the Epilogue Control flow is unchanged.

const KIT := preload("res://systems/levelb/LBKit.gd")
const TERRAIN := preload("res://systems/levelb/LBTerrain.gd")
const OUTCROP := "res://assets/models/hero/epilogue/lod/epi_mist_ridge_rock_outcrop_LOD0.glb"
const J := "res://assets/models/jungle/lod/"
const TREES := [[J + "jun_kapok_tree_buttress_LOD0.glb", 18.0], [J + "jun_strangler_fig_tree_LOD0.glb", 14.0], [J + "jun_leaning_palm_cluster_LOD0.glb", 10.0], ["res://assets/environment/jungle/jungle_tree.glb", 13.0]]

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var terrain: TERRAIN
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	name = "EpilogueVista"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	rng.seed = 1212
	noise.seed = 12
	noise.frequency = 0.02
	_environment()
	terrain = TERRAIN.new()
	world.add_child(terrain)
	terrain.build(Vector2(-120, -160), Vector2(240, 200), 2.0, _height, _mask)
	_dress()
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 800.0
	world.add_child(camera)
	camera.current = true
	WindSystem.set_wind(Vector2(0.6, -0.8), 0.5, 0.4, 0.2)
	_update_camera()

func _height(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	# Valley floor with a river channel; ridge outcrop where the survivors stand (0,~12,0).
	var h := 4.0 + n * 6.0 + absf(x) * 0.08
	var river := absf(z + 45.0 + sin(x * 0.03) * 8.0)
	h = lerpf(h, -1.0, 1.0 - smoothstep(4.0, 14.0, river))
	var ridge := 1.0 - smoothstep(8.0, 22.0, Vector2(x, z).length())
	h = lerpf(h, 12.0 + n * 1.5, ridge)
	# Far mountains (the collapsed ridge) on the horizon.
	h = maxf(h, smoothstep(-90.0, -150.0, z) * (40.0 + 30.0 * n))
	return h

func _mask(x: float, z: float) -> Color:
	var river := absf(z + 45.0 + sin(x * 0.03) * 8.0)
	return Color(0.0, 0.0, (1.0 - smoothstep(4.0, 9.0, river)) * 0.8, 0.3)

func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.98, 0.78, 0.55)
	sky_mat.ground_horizon_color = Color(0.7, 0.6, 0.5)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.2)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.82, 0.68)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(160.0), 0)

func _dress() -> void:
	var rock := KIT.rock_material(Color(0.55, 0.52, 0.47), 0.7)
	var outcrop := KIT.place(world, OUTCROP, Vector3(2.0, terrain.height_at(2, -6) - 4.0, -6.0), 12.0, 0.4, Vector3.ONE, false, "RidgeOutcrop")
	if outcrop == null:
		var b := KIT.place(world, "res://assets/models/optimized/env_boulder_moss_LOD0.glb", Vector3(2.0, 8.0, -6.0), 7.0, 0.4)
		if b:
			KIT.override_material(b, rock)
	# Trees on the valley slopes, swaying.
	for k in 45:
		var p := Vector2(rng.randf_range(-100, 100), rng.randf_range(-100, 30))
		if p.length() < 16.0 or absf(p.y + 45.0 + sin(p.x * 0.03) * 8.0) < 10.0:
			continue
		var spec: Array = TREES[k % TREES.size()]
		var h := terrain.height_at(p.x, p.y)
		var tall: float = spec[1] * rng.randf_range(0.85, 1.15)
		var tree := KIT.place(world, spec[0], Vector3(p.x, h - 0.3, p.y), tall, rng.randf() * TAU, Vector3.ONE, true)
		if tree:
			KIT.sway(tree, tall, h, "tree")
	# River.
	var river := preload("res://systems/water/WaterBody.tscn").instantiate()
	river.set("preset_name", "RIVER")
	river.set("size", Vector2(240.0, 22.0))
	river.set("depth", 2.0)
	river.set("splashes", false)
	world.add_child(river)
	river.global_position = Vector3(0, 0.0, -45.0)
	# Survivors: Mara, Nadiya and Tomas on the outcrop looking at the dawn.
	var top := terrain.height_at(0, 0)
	_person("res://assets/characters/nadiya/source/CHR_Nadiya_Rig.glb", Vector3(-1.4, top, 1.0), 0.3, 1.67)
	_person("res://assets/characters/tomas/source/CHR_Tomas_Rig.glb", Vector3(1.6, top, 1.4), -0.2, 1.84)
	var mara := "res://assets/characters/mara/optimized/CHR_Mara_Animated.glb"
	_person(mara, Vector3(0.1, top, 0.2), 0.0, 1.7)

func _person(path: String, pos: Vector3, yaw: float, height: float) -> void:
	var n := Node3D.new()
	n.set_script(KIT.CHARACTER)
	n.set("model_path", path)
	n.set("character_height", height)
	n.set("animated_idle", true)
	world.add_child(n)
	n.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)

func _process(delta: float) -> void:
	_t += delta
	_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	# Slow pull-back from behind the survivors toward the sunrise valley.
	var top := terrain.height_at(0, 0)
	var k := clampf(_t / 40.0, 0.0, 1.0)
	var pos := Vector3(lerpf(3.5, 7.0, k), top + lerpf(2.2, 5.0, k), lerpf(7.0, 14.0, k))
	camera.global_position = pos
	camera.look_at(Vector3(-2.0, top + 1.0 - k * 2.0, -40.0))
