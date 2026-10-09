extends Node3D
## Prologue water + shaft-light pass. Runs after NaturalCavernArt (CaveBuilder) is built.
## - Puddles: CALM_CAVE_POOL WaterBody nodes on clustered water_placeholder markers.
## - Seep waterfall: water emerges from a fracture on the chamber's upper ledge (visible
##   source channel on a wet rock shelf), falls ~5 m into a shallow plunge pool.
## - Shaft light: visible skylight crack, stronger beam, brighter dust shaft.
## Water bodies are never rotated or scaled (WaterBody contract).

const WATERFALL := preload("res://systems/water/Waterfall.tscn")
const WATER_BODY := preload("res://systems/water/WaterBody.tscn")
const FOG_SHADER := preload("res://materials/fog_card.gdshader")

@export var cave_path := NodePath("../NaturalCavernArt/ProceduralCave")
@export var fall_origin := Vector3(-4.6, 0.1, -14.0) ## foot of the fall (pool lip)
@export var fall_height := 5.0
@export var shaft_xz := Vector2(-1.5, -13.5)

var cave: Node
const FERN_SPOTS := [Vector2(-1.3, -12.1), Vector2(-1.0, -15.2), Vector2(-1.5, -15.8), Vector2(-1.1, -12.8)]

func _ready() -> void:
	await get_tree().process_frame
	cave = get_node_or_null(cave_path)
	if cave == null:
		push_warning("[PrologueWater] cave not found")
		return
	if not cave.is_built:
		await cave.built
	_puddles()
	# Relic sits off the walking line (x=2.2); move its Vaelor light from CavernArt with it.
	var art := get_node_or_null("../NaturalCavernArt")
	if art:
		for l in art.get_children():
			if l is OmniLight3D and l.position.is_equal_approx(Vector3(0, 1.4, -12)):
				l.position.x = 2.2
	# Real WaterBody puddles replace the ground shader's painted puddles (keep the wet darkening).
	cave.ground_material.set_shader_parameter("puddle_enabled", 0.0)
	_waterfall()
	_shaft()
	_shaft_ferns()
	_audio()

func _audio() -> void:
	var sc = preload("res://systems/audio/Soundscape.gd").attach(get_parent(), "PRO")
	if sc == null:
		return
	# Squeeze tunnels are tight, the shaft chamber is vast, the portal hall is a cave.
	sc.add_reverb_zone(Vector3(0, 1.5, 1.0), Vector3(7, 4, 12), "tunnel")
	sc.add_reverb_zone(Vector3(0, 5.0, -12.5), Vector3(14, 12, 11), "vast")
	sc.add_reverb_zone(Vector3(0, 1.5, -20.5), Vector3(7, 4, 5), "tunnel")
	sc.add_reverb_zone(Vector3(0, 3.0, -28.0), Vector3(11, 7, 10), "cave")
	for p in get_tree().get_nodes_in_group("water_placeholder").slice(0, 3):
		sc.add_emitter("res://audio/ambience/cave/AMB_PRO_CAVE_WATER.ogg", p.global_position + Vector3.UP * 0.2, -14.0, 10.0)

## Ferns only where the skylight reaches (light-fed growth is the geological excuse).
## They sway via FoliageWind; rocks never get a wind component.
func _shaft_ferns() -> void:
	var WindSystem = load("res://systems/nature/WindSystem.gd")
	WindSystem.set_wind(Vector2(0.6, -0.8).normalized(), 0.35, 0.4, 0.25) # gentle cave draft
	var packed := load("res://assets/environment/jungle/jungle_fern.glb") as PackedScene
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var spots := FERN_SPOTS
	for i in spots.size():
		var xz: Vector2 = spots[i]
		var fern := packed.instantiate() as Node3D
		fern.name = "ShaftFern_%d" % i
		fern.set_meta("collision", "none")
		add_child(fern)
		var bounds := AABB()
		var started := false
		for m in fern.find_children("*", "MeshInstance3D", true, false):
			bounds = bounds.merge(m.get_aabb()) if started else m.get_aabb()
			started = true
		var h := rng.randf_range(0.6, 0.95)
		var f := Vector3(h * 1.3, h, h * 1.3) / bounds.size
		fern.scale = f
		fern.rotation.y = rng.randf() * TAU
		var gy: float = cave.ground_y(xz.x, xz.y)
		fern.position = Vector3(xz.x, gy, xz.y) - fern.basis * Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var wind := preload("res://systems/FoliageWind.gd").new()
		wind.name = "FoliageWind"
		fern.add_child(wind)
		wind.configure(fern, h, gy, "fern")

func _puddles() -> void:
	var points: Array[Vector3] = []
	for m in get_tree().get_nodes_in_group("water_placeholder"):
		var p: Vector3 = m.global_position
		# Skip markers already inside the plunge pool footprint.
		if Vector2(p.x - fall_origin.x, p.z - fall_origin.z).length() < 3.5:
			continue
		if FERN_SPOTS.any(func(f): return Vector2(p.x, p.z).distance_to(f) < 1.3):
			continue
		var merged := false
		for i in points.size():
			if points[i].distance_to(p) < 1.6:
				points[i] = (points[i] + p) * 0.5
				merged = true
				break
		if not merged:
			points.append(p)
	var root := Node3D.new()
	root.name = "Puddles"
	add_child(root)
	for i in points.size():
		var p := points[i]
		var water := WATER_BODY.instantiate()
		water.name = "Puddle_%d" % i
		water.preset_name = "CALM_CAVE_POOL"
		water.size = Vector2(1.3, 1.1) if i % 2 == 0 else Vector2(1.0, 1.4)
		water.depth = 0.12
		water.subdivisions = 8
		water.splashes = true
		root.add_child(water)
		# Surface just above the dipped ground so the waterline sits inside the depression.
		water.global_position = Vector3(p.x, cave.ground_y(p.x, p.z) + 0.012, p.z)

func _waterfall() -> void:
	var fall := WATERFALL.instantiate()
	fall.name = "SeepFall"
	fall.fall_height = fall_height
	fall.width = 1.1
	fall.throw_distance = 0.6
	fall.basin_size = Vector2(3.0, 3.0) # square: the fall faces +X (rotated 90 deg about Y)
	fall.basin_depth = 0.25
	fall.downstream_length = 0.6
	fall.downstream_width = 0.8
	fall.downstream_flow_speed = 0.6
	fall.mist_amount = 24
	fall.audio_volume_db = -4.0
	fall.build_lip_rock = true
	fall.position = fall_origin
	fall.rotation.y = PI / 2.0 # Y-only rotation is allowed for Waterfall; it faces +X
	add_child(fall)
	await get_tree().process_frame
	# Replace the box lip with an irregular wet limestone shelf tucked into the wall.
	var lip := fall.get_node_or_null("Lip")
	if lip:
		var mi := lip.get_child(0) as MeshInstance3D
		var box_size: Vector3 = (mi.mesh as BoxMesh).size
		mi.mesh = cave._rock_mesh(0.5, 0.35)
		mi.scale = Vector3(box_size.x * 1.1, box_size.y / 0.7, box_size.z * 1.2)
		mi.material_override = Waterfall.make_wet_rock_material(0.9)
	var downstream := fall.get_node_or_null("Downstream")
	if downstream:
		downstream.queue_free() # the plunge pool drains into the gravel; no stream across the relic
	# Wet rock tumble around the plunge pool rim.
	var rim := Node3D.new()
	rim.name = "PoolRim"
	add_child(rim)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var basin_center := fall_origin + Vector3(1.6, 0, 0)
	for i in 11:
		var a := -PI * 0.5 + PI * float(i) / 10.0
		var p := basin_center + Vector3(cos(a) * 1.75, 0, sin(a) * 1.75)
		var r: StaticBody3D = cave.add_rock(rim, Vector3(p.x, cave.ground_y(p.x, p.z) + 0.02, p.z), rng.randf_range(0.18, 0.38), Vector3(0, rng.randf() * TAU, 0))
		(r.get_child(0) as MeshInstance3D).material_override = Waterfall.make_wet_rock_material(0.75)
	# Drip trail below the source on the wall: a wet zone marker documents it for CaveBuilder.

func _shaft() -> void:
	var cy: float = cave._ceil_y(shaft_xz.x, shaft_xz.y)
	# Daylight crack: a narrow emissive slot just under the chamber roof.
	var crack := MeshInstance3D.new()
	crack.name = "SkylightCrack"
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 0.5)
	crack.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.85, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.7, 0.82, 1.0)
	m.emission_energy_multiplier = 3.0
	crack.material_override = m
	crack.position = Vector3(shaft_xz.x, cy - 0.05, shaft_xz.y)
	crack.rotation = Vector3(PI / 2.0, 0.4, 0) # faces down
	crack.set_meta("collision", "none")
	add_child(crack)
	# Stronger beam from the crack.
	var shaft := SpotLight3D.new()
	shaft.name = "ShaftBeam"
	shaft.light_color = Color(0.68, 0.78, 0.92)
	shaft.light_energy = 6.0
	shaft.spot_range = cy + 2.0
	shaft.spot_angle = 18.0
	shaft.spot_attenuation = 0.6
	shaft.shadow_enabled = true
	shaft.position = Vector3(shaft_xz.x, cy - 0.2, shaft_xz.y)
	shaft.rotation = Vector3(-PI / 2.0, 0, 0)
	add_child(shaft)
	# Visible beam: two crossed additive cards, brighter than the general mist.
	var noise := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	noise.noise = n
	noise.seamless = true
	for k in 2:
		var card := MeshInstance3D.new()
		card.name = "ShaftBeamCard_%d" % k
		var quad := QuadMesh.new()
		quad.size = Vector2(1.4, cy)
		card.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = FOG_SHADER
		mat.set_shader_parameter("noise_tex", noise)
		mat.set_shader_parameter("tint", Color(0.55, 0.65, 0.8))
		mat.set_shader_parameter("density", 0.22)
		mat.set_shader_parameter("drift", Vector2(0.0, -0.03))
		card.material_override = mat
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.position = Vector3(shaft_xz.x, cy * 0.5, shaft_xz.y)
		card.rotation.y = k * PI / 2.0 + 0.3
		card.set_meta("collision", "none")
		add_child(card)
		card.add_to_group("mist_card")
	# The old faint shaft from CavernArt is superseded.
	var art := get_node_or_null("../NaturalCavernArt")
	if art:
		for c in art.get_children():
			if c is SpotLight3D:
				c.visible = false

func set_graphics_quality(preset: int) -> void:
	for c in get_children():
		if c.is_in_group("mist_card"):
			c.visible = preset > 0
