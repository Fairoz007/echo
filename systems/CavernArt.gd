extends Node3D
## Prologue cave dressing: procedural limestone cave (systems/environment/CaveBuilder.gd)
## plus rockfall, expedition storytelling props, lamps, Vaelor glow, mist and environment.
## Gameplay collision is produced by CaveBuilder / EnvironmentCollision.
const CaveBuilder := preload("res://systems/environment/CaveBuilder.gd")
const FOG_SHADER := preload("res://materials/fog_card.gdshader")
const WALL := "res://assets/environment/cave/cave_wall_limestone.glb"
const BOULDER := "res://assets/models/optimized/env_boulder_moss_LOD0.glb"
const STALAG := "res://assets/models/optimized/env_stalagmite_cluster_LOD0.glb"
const CRATE := "res://assets/models/optimized/prop_meridian_crate_LOD0.glb"
const RADIO := "res://assets/models/optimized/prop_expedition_radio_station_LOD0.glb"
const VAELOR_WALL := "res://assets/models/optimized/arch_wall_vaelor_LOD0.glb"

const LAMP_WARM := Color(1.0, 0.72, 0.42)
const VAELOR := Color(0.3, 0.85, 1.0)

var cave: Node3D
var fog_cards: Array[MeshInstance3D] = []
var flicker_lamp: OmniLight3D
var flicker_t := 0.0

func _ready() -> void:
	preload("res://systems/environment/EnvironmentCollision.gd").attach(get_parent())
	cave = CaveBuilder.new()
	cave.name = "ProceduralCave"
	add_child(cave)
	var pedestal := get_parent().get_node_or_null("ResonantArtifact/Pedestal") as CSGShape3D
	if pedestal:
		pedestal.material = cave.plain_rock_material
	_rockfall()
	_story_props()
	_lights()
	_fog_cards()
	_environment()
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	set_graphics_quality(int(graphics.preset) if graphics else 0)

func set_graphics_quality(preset: int) -> void:
	# Low preset: no mist cards, fewer pebbles visible; called by GraphicsSettings.
	for card in fog_cards:
		card.visible = preset > 0
	var pebbles := cave.get_node_or_null("PebbleScatter") as MultiMeshInstance3D
	if pebbles:
		pebbles.multimesh.visible_instance_count = [300, -1, -1][clampi(preset, 0, 2)]

func _process(delta: float) -> void:
	if flicker_lamp:
		flicker_t += delta
		var f := 0.85 + 0.15 * sin(flicker_t * 23.0) * sin(flicker_t * 7.3)
		if fmod(flicker_t, 6.0) < 0.12:
			f = 0.25
		flicker_lamp.light_energy = 1.1 * f

func _model(path: String, parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO, meta := "") -> Node3D:
	var piece := (load(path) as PackedScene).instantiate() as Node3D
	parent.add_child(piece)
	var bounds := AABB()
	var started := false
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.get_aabb()
		bounds = bounds.merge(box) if started else box
		started = true
	piece.rotation = rot
	piece.scale = size / bounds.size
	piece.position = pos - piece.basis * bounds.get_center()
	if meta != "":
		piece.set_meta("collision", meta)
	return piece

# Collapse behind the start: the reason Mara cannot go back.
func _rockfall() -> void:
	var pile := Node3D.new()
	pile.name = "Rockfall"
	add_child(pile)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 26:
		var x := rng.randf_range(-3.0, 3.0)
		var z := rng.randf_range(4.2, 6.8)
		var y := rng.randf_range(0.0, 2.6) * (1.0 - absf(x) / 4.0) * clampf((z - 4.0) / 2.0, 0.3, 1.0)
		cave.add_rock(pile, Vector3(x, y, z), rng.randf_range(0.35, 0.9), Vector3(rng.randf(), rng.randf() * TAU, rng.randf()))
	# Large slabs of fallen limestone (Tripo wall pieces as broken ceiling slabs).
	_model(WALL, pile, Vector3(0.7, 2.6, 3.4), Vector3(-1.6, 1.0, 5.0), Vector3(0.3, 0.9, 0.5), "convex")
	_model(WALL, pile, Vector3(0.6, 2.2, 3.0), Vector3(1.8, 0.9, 5.4), Vector3(-0.2, -0.7, -0.6), "convex")
	_model(BOULDER, pile, Vector3(1.6, 1.2, 1.5), Vector3(0.4, 0.6, 4.6), Vector3(0, 1.2, 0), "convex")
	# Smaller fallen debris trailing into the start area.
	for i in 8:
		cave.add_rock(pile, Vector3(rng.randf_range(-2.0, 2.0), 0.05, rng.randf_range(2.2, 4.0)), rng.randf_range(0.12, 0.3))

func _story_props() -> void:
	var props := Node3D.new()
	props.name = "Storytelling"
	add_child(props)
	# Crushed supply crate half-buried at the rockfall.
	_model(CRATE, props, Vector3(0.9, 0.6, 0.7), Vector3(-1.9, 0.25, 3.4), Vector3(0.35, 0.6, -0.2), "convex")
	# Mara's field radio thrown clear (ties into "Radio... Nadiya?").
	_model(RADIO, props, Vector3(0.6, 0.45, 0.4), Vector3(1.3, 0.22, 1.6), Vector3(0.1, -0.5, 0.15), "convex")
	# Rope dangling from the shaft in the tall chamber: the team's descent line.
	var rope := MeshInstance3D.new()
	rope.name = "DescentRope"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 9.5
	rope.mesh = cyl
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.55, 0.36, 0.12)
	rope_mat.roughness = 0.9
	rope.material_override = rope_mat
	rope.position = Vector3(-3.2, 4.75, -14.5)
	rope.rotation.z = 0.04
	rope.set_meta("collision", "none")
	props.add_child(rope)
	# Coiled rope end + broken lamp on the chamber floor.
	var coil := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.3
	coil.mesh = torus
	coil.material_override = rope_mat
	coil.position = Vector3(-3.0, cave.ground_y(-3.0, -14.2) + 0.05, -14.2)
	coil.set_meta("collision", "none")
	props.add_child(coil)
	# Survey flags marking the old expedition route.
	for p in [Vector3(-1.4, 0, -3.0), Vector3(1.6, 0, -9.0), Vector3(-1.5, 0, -19.5), Vector3(1.8, 0, -24.5)]:
		_flag(props, p)
	# Vaelor carved panel embedded in the chamber wall; veins of the cave lead to it.
	_model(VAELOR_WALL, props, Vector3(0.5, 3.4, 2.6), Vector3(5.5, 2.4, -12.5), Vector3(0, 0, 0), "none")
	# Tripo stalagmite clusters and boulders flank the chamber (convex collision).
	_model(STALAG, props, Vector3(1.6, 2.2, 1.6), Vector3(-4.3, 1.0, -11.0), Vector3(0, 0.7, 0), "convex")
	_model(STALAG, props, Vector3(1.2, 1.8, 1.2), Vector3(3.6, 0.85, -16.0), Vector3(0, 2.1, 0), "convex")
	_model(BOULDER, props, Vector3(1.8, 1.3, 1.7), Vector3(2.6, 0.55, -7.8), Vector3(0, 0.4, 0), "convex")
	_model(BOULDER, props, Vector3(2.2, 1.5, 2.0), Vector3(-2.9, 0.7, -21.5), Vector3(0, 2.0, 0), "convex")

func _flag(parent: Node3D, base: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.9
	pole.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	mat.metallic = 0.6
	pole.material_override = mat
	pole.position = base + Vector3(0, cave.ground_y(base.x, base.z) + 0.45, 0)
	pole.set_meta("collision", "none")
	parent.add_child(pole)
	var tag := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.12)
	tag.mesh = quad
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.95, 0.4, 0.08)
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tmat.emission_enabled = true
	tmat.emission = Color(0.5, 0.18, 0.03)
	tmat.emission_energy_multiplier = 0.3
	tag.material_override = tmat
	tag.position = Vector3(0.09, 0.38, 0)
	pole.add_child(tag)

func _lamp(pos: Vector3, energy: float, rng_range: float, broken := false) -> OmniLight3D:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.09
	cyl.height = 0.22
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.6)
	mat.emission_enabled = true
	mat.emission = LAMP_WARM
	mat.emission_energy_multiplier = 2.5
	body.material_override = mat
	body.position = pos
	if broken:
		body.rotation.z = PI / 2.2
	body.set_meta("collision", "none")
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = LAMP_WARM
	light.light_energy = energy
	light.omni_range = rng_range
	light.omni_attenuation = 1.6
	light.shadow_enabled = true
	light.position = pos + Vector3(0, 0.2, 0)
	add_child(light)
	return light

func _lights() -> void:
	# Expedition lamps: dropped lamp at the start (flickering), lamp on the chamber ledge, lamp at the portal camp.
	flicker_lamp = _lamp(Vector3(-1.1, cave.ground_y(-1.1, 2.0) + 0.1, 2.0), 1.1, 5.5, true)
	_lamp(Vector3(-4.6, 2.75, -10.5), 1.6, 9.0)
	_lamp(Vector3(2.6, cave.ground_y(2.6, -24.5) + 0.12, -24.5), 0.9, 6.0)
	# Vaelor glow: relic pedestal and portal.
	var relic := OmniLight3D.new()
	relic.light_color = VAELOR
	relic.light_energy = 1.4
	relic.omni_range = 6.5
	relic.omni_attenuation = 2.0
	relic.position = Vector3(0, 1.4, -12)
	add_child(relic)
	for x in [-2.2, 2.2]:
		var portal := OmniLight3D.new()
		portal.light_color = VAELOR
		portal.light_energy = 1.1
		portal.omni_range = 7.0
		portal.position = Vector3(x, 2.5, -27.0)
		add_child(portal)
	# Cold shaft light down the vertical chamber (faint surface light far above).
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(0.6, 0.72, 0.85)
	shaft.light_energy = 2.0
	shaft.spot_range = 14.0
	shaft.spot_angle = 22.0
	shaft.shadow_enabled = true
	shaft.position = Vector3(-1.5, 10.0, -13.5)
	shaft.rotation = Vector3(-PI / 2.0, 0, 0)
	add_child(shaft)

func _fog_cards() -> void:
	var noise := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	noise.noise = n
	noise.seamless = true
	var specs := [
		[Vector3(0, 0.5, -4), Vector2(7, 1.4), 0.0, Color(0.32, 0.36, 0.4)],
		[Vector3(0, 0.6, -12), Vector2(12, 1.6), 0.0, Color(0.3, 0.45, 0.5)],
		[Vector3(-1.5, 5.0, -13.5), Vector2(3.5, 10.0), PI / 2.0, Color(0.42, 0.5, 0.58)],
		[Vector3(0, 0.6, -22), Vector2(6, 1.2), 0.0, Color(0.32, 0.36, 0.4)],
		[Vector3(0, 1.8, -27.5), Vector2(8, 4), 0.0, Color(0.25, 0.6, 0.7)],
	]
	for s in specs:
		var card := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = s[1]
		card.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = FOG_SHADER
		mat.set_shader_parameter("noise_tex", noise)
		mat.set_shader_parameter("tint", s[3])
		mat.set_shader_parameter("density", 0.06)
		card.material_override = mat
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.position = s[0]
		if s[2] == 0.0:
			card.rotation.x = -PI / 2.0 + 0.0 # ground-hugging sheet
		card.set_meta("collision", "none")
		card.name = "MistCard"
		add_child(card)
		fog_cards.append(card)

func _environment() -> void:
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	var env := world.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.11, 0.12, 0.14)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.055, 0.065)
	env.fog_density = 0.035
	env.fog_height = 0.7
	env.fog_height_density = 0.25
	env.glow_enabled = false # GPU safety: no glow (user hard rule)
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	# Volumetric fog only takes effect on Forward+; GraphicsSettings keeps it High-only.
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.6, 0.65, 0.7)
	if world.has_meta("glow_enabled"):
		world.set_meta("glow_enabled", false)
	if world.has_meta("volumetric_fog_enabled"):
		world.set_meta("volumetric_fog_enabled", false)
