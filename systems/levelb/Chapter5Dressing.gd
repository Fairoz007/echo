extends Node3D
## Chapter 5 "Hunters": Meridian underground checkpoint in a limestone cavern.
## Routes: centre (crate cover lane), west (raised ledge + scaffold watchtower = vertical
## observation), east (flooded drainage channel, low cover). Overlook ledge at z=-20,
## descent ramp to the temple aqueduct entrance.

const KIT := preload("res://systems/levelb/LBKit.gd")
const TERRAIN := preload("res://systems/levelb/LBTerrain.gd")
const CRATE := "res://assets/models/optimized/prop_meridian_crate_LOD0.glb"
const TENT := "res://assets/models/optimized/prop_expedition_tent_LOD0.glb"
const RADIO := "res://assets/models/optimized/prop_expedition_radio_station_LOD0.glb"
const CLIFF := "res://assets/environment/cave/cave_wall_limestone.glb"
const CEIL := "res://assets/environment/cave/cave_ceiling_limestone.glb"
const STALAG := "res://assets/models/optimized/env_stalagmite_cluster_LOD0.glb"
const BOULDER := "res://assets/models/optimized/env_boulder_moss_LOD0.glb"
const PILLAR := "res://assets/models/optimized/ruin_pillar_vaelor_LOD0.glb"
const LEDGE_Y := 3.5
const BASIN_Y := -4.6

var terrain: TERRAIN
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var steel: StandardMaterial3D
var lamp_mat: StandardMaterial3D
var _blink: Array[OmniLight3D] = []
var _t := 0.0

func _init() -> void:
	name = "LevelBDressing"

func build(level: Node3D) -> void:
	rng.seed = 505
	noise.seed = 55
	noise.frequency = 0.03
	steel = KIT.std_mat(Color(0.2, 0.21, 0.22), 0.45, 0.7)
	lamp_mat = KIT.std_mat(Color(1, 0.95, 0.8), 0.3, 0.0, Color(1.0, 0.92, 0.75), 6.0)
	var ground := level.get_node_or_null("Ground")
	if ground:
		for c in ground.get_children():
			if c is CollisionShape3D:
				c.disabled = true
			elif c is GeometryInstance3D:
				c.visible = false
	terrain = TERRAIN.new()
	terrain.name = "CavernFloor"
	add_child(terrain)
	terrain.build(Vector2(-60, -80), Vector2(120, 130), 1.0, _height, _mask)
	var m := terrain.material
	m.set_shader_parameter("grass_a", Vector3(0.2, 0.18, 0.15))
	m.set_shader_parameter("grass_b", Vector3(0.26, 0.23, 0.19))
	m.set_shader_parameter("soil_a", Vector3(0.17, 0.14, 0.11))
	m.set_shader_parameter("soil_b", Vector3(0.22, 0.18, 0.14))
	m.set_shader_parameter("litter", Vector3(0.14, 0.12, 0.1))
	m.set_shader_parameter("rock_tint", Vector3(0.42, 0.4, 0.37))
	m.set_shader_parameter("slope_rock_start", 0.18)
	var entrance := level.get_node_or_null("TempleEntrance") as Node3D
	if entrance:
		entrance.position.y = BASIN_Y
	_cavern()
	_checkpoint(level)
	_west_route()
	_east_route()
	_overlook()
	_discoveries()
	_lighting(level)
	_hero_props(level)

func _height(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := 0.0 + noise.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	# Cavern walls.
	var wall := smoothstep(23.0, 30.0, absf(x) + n * 4.0)
	h = maxf(h, wall * (14.0 + 6.0 * n))
	var back := smoothstep(34.0, 40.0, z + n * 3.0)
	h = maxf(h, back * 14.0)
	# West ledge (observation route) with an access ramp from the south.
	var lx := 1.0 - smoothstep(6.5, 8.0, absf(x + 16.0))
	var lz := 1.0 - smoothstep(13.0, 15.0, absf(z))
	h = maxf(h, LEDGE_Y * lx * lz)
	if absf(x + 14.5) < 2.2 and z > 13.0 and z < 24.0:
		h = maxf(h, lerpf(LEDGE_Y, 0.0, (z - 13.0) / 11.0))
	# East drainage channel.
	var ch := 1.0 - smoothstep(2.0, 3.2, absf(x - 15.0))
	if z > -22.0 and z < 30.0:
		h = minf(h, lerpf(h, -0.9, ch))
	# Drop to the temple basin beyond the overlook; central ramp down to the aqueduct.
	if z < -23.0:
		var drop := smoothstep(-23.0, -26.0, z)
		var ramp := 1.0 - smoothstep(3.0, 4.5, absf(x))
		var ramp_y := lerpf(0.0, BASIN_Y, clampf((-23.0 - z) / 11.0, 0.0, 1.0))
		h = lerpf(h, BASIN_Y - 3.0, drop * (1.0 - ramp))
		h = lerpf(h, ramp_y, ramp)
		if z < -34.0:
			h = lerpf(h, BASIN_Y, 1.0 - smoothstep(5.0, 7.0, absf(x)))
	return h

func _mask(x: float, z: float) -> Color:
	var path := (1.0 - smoothstep(2.5, 5.0, absf(x))) * 0.8
	var wet := (1.0 - smoothstep(2.5, 4.5, absf(x - 15.0))) * 0.9
	if z < -24.0:
		wet = maxf(wet, 0.5)
	return Color(path, 0.0, wet, 0.0)

func _cavern() -> void:
	var root := Node3D.new()
	root.name = "CavernShell"
	add_child(root)
	var mat := KIT.rock_material(Color(0.4, 0.39, 0.36), 0.15)
	for side in [-1.0, 1.0]:
		var z := 34.0
		var i := 0
		while z > -60.0:
			var x: float = side * rng.randf_range(25.0, 29.0)
			var piece := KIT.place(root, CLIFF, Vector3(x, terrain.height_at(x, z) - 3.0, z), rng.randf_range(16.0, 24.0), rng.randf_range(-0.5, 0.5) + (PI if i % 2 else 0.0), Vector3(rng.randf_range(0.8, 1.3), 1, rng.randf_range(0.8, 1.4)), true, "Wall%s%02d" % ["W" if side < 0 else "E", i])
			if piece:
				KIT.override_material(piece, mat)
			z -= rng.randf_range(8.0, 12.0)
			i += 1
	# Ceiling slabs.
	for k in 14:
		var p := Vector3(rng.randf_range(-22, 22), rng.randf_range(17.0, 21.0), rng.randf_range(-55, 32))
		var c := KIT.place(root, CEIL, p, rng.randf_range(16.0, 24.0), rng.randf() * TAU, Vector3.ONE, false, "Ceiling%02d" % k)
		if c:
			KIT.override_material(c, mat)
			c.set_meta("collision", "none")
	# Stalagmite clusters off the routes.
	for k in 12:
		var x := rng.randf_range(-22, 22)
		var z := rng.randf_range(-20, 30)
		if absf(x) < 6.0 or absf(x - 15.0) < 4.0 or (absf(x + 16.0) < 8.0 and absf(z) < 15.0):
			continue
		var s := KIT.place(root, STALAG, Vector3(x, terrain.height_at(x, z) - 0.2, z), rng.randf_range(1.5, 3.5), rng.randf() * TAU, Vector3.ONE, true, "Stalag%02d" % k)

func _checkpoint(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MeridianCheckpoint"
	add_child(root)
	# Barricade lines: crate walls at chest height with gaps (centre lane cover).
	var crates := [Vector3(-7, 0, 4), Vector3(-8.2, 0, 4.4), Vector3(7.5, 0, 0), Vector3(8.6, 0, -0.6), Vector3(-2.5, 0, -8), Vector3(3.5, 0, -11), Vector3(-6, 0, -14), Vector3(9, 0, -15)]
	for i in crates.size():
		KIT.place(root, CRATE, crates[i], rng.randf_range(0.9, 1.25), rng.randf_range(-0.4, 0.4), Vector3(1.3, 1, 1), true, "CoverCrate%02d" % i)
	# Sandbag walls (procedural stacked bags).
	var bag_mat := KIT.std_mat(Color(0.36, 0.33, 0.25), 0.95)
	for wall in [[Vector3(-1.5, 0, -2), 0.2], [Vector3(6, 0, -7), -0.4], [Vector3(-9, 0, -9), 0.5]]:
		_sandbags(root, wall[0], wall[1], bag_mat)
	# Command tent + radio + generator.
	var tent := KIT.place(root, TENT, Vector3(10, 0, -20), 3.0, PI + 0.3, Vector3.ONE, true, "CommandTent")
	if tent:
		for mi in tent.find_children("*", "MeshInstance3D", true, false):
			var src := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			if src:
				var dark := src.duplicate() as StandardMaterial3D
				dark.albedo_color = Color(0.45, 0.47, 0.45)
				(mi as MeshInstance3D).material_override = dark
	KIT.place(root, RADIO, Vector3(7.6, 0, -18.5), 1.1, 2.6, Vector3.ONE, true, "MeridianRadio")
	var gen := BoxMesh.new()
	gen.size = Vector3(1.4, 1.0, 0.9)
	KIT.mesh(root, gen, Transform3D(Basis(Vector3.UP, 0.2), Vector3(-10, 0.5, 17)), KIT.std_mat(Color(0.14, 0.16, 0.15), 0.5, 0.5), "Generator")
	KIT.box_body(root, Vector3(-10, 0.5, 17), Vector3(1.4, 1.0, 0.9), 0.2, "GeneratorBody")
	# Cable runs from the generator to the floodlights.
	var cable := CylinderMesh.new()
	cable.top_radius = 0.03
	cable.bottom_radius = 0.03
	cable.height = 1.0
	var cable_mat := KIT.std_mat(Color(0.04, 0.04, 0.04), 0.6)
	var fl := [Vector3(-11, 0, 8), Vector3(11, 0, 10), Vector3(-5, 0, -18), Vector3(6, 0, -24)]
	for target in fl:
		var a := Vector3(-10, 0.04, 17)
		var b: Vector3 = target + Vector3(0, 0.04, 0)
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var basis := Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z)) * Basis(Vector3.RIGHT, PI / 2)
		KIT.mesh(root, cable, Transform3D(basis.scaled(Vector3(1, len, 1)), mid), cable_mat).set_meta("collision", "none")
		_floodlight(root, target, Vector3(0, 0, 0))

func _sandbags(root: Node3D, origin: Vector3, yaw: float, mat: Material) -> void:
	var bag := CapsuleMesh.new()
	bag.radius = 0.17
	bag.height = 0.7
	var basis := Basis(Vector3.UP, yaw)
	for row in 3:
		for k in 6:
			var off := Vector3(-1.6 + k * 0.62 + (0.31 if row % 2 else 0.0), 0.16 + row * 0.28, 0)
			KIT.mesh(root, bag, Transform3D(basis * Basis(Vector3.FORWARD, PI / 2) * Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), origin + basis * off), mat).set_meta("collision", "none")
	KIT.box_body(root, origin + Vector3(0, 0.45, 0), Vector3(3.8, 0.9, 0.45), yaw, "SandbagCover")

func _floodlight(root: Node3D, pos: Vector3, _unused: Vector3) -> void:
	var leg := CylinderMesh.new()
	leg.top_radius = 0.03
	leg.bottom_radius = 0.04
	leg.height = 2.6
	for k in 3:
		var a := TAU * k / 3.0
		var tilt := Basis(Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)), 0.25)
		KIT.mesh(root, leg, Transform3D(tilt, pos + Vector3(cos(a) * 0.3, 1.25, sin(a) * 0.3)), steel).set_meta("collision", "none")
	var head := BoxMesh.new()
	head.size = Vector3(0.6, 0.45, 0.25)
	var look := Vector3(0, 0, 0) - pos
	var yaw := atan2(-look.x, -look.z)
	KIT.mesh(root, head, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.35), pos + Vector3(0, 2.6, 0)), steel).set_meta("collision", "none")
	var lens := BoxMesh.new()
	lens.size = Vector3(0.5, 0.35, 0.02)
	KIT.mesh(root, lens, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.35), pos + Vector3(0, 2.6, 0) + Basis(Vector3.UP, yaw) * Vector3(0, -0.04, -0.14)), lamp_mat).set_meta("collision", "none")
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.94, 0.82)
	spot.light_energy = 5.0
	spot.spot_range = 30.0
	spot.spot_angle = 38.0
	spot.shadow_enabled = false
	root.add_child(spot)
	spot.global_position = pos + Vector3(0, 2.6, 0)
	spot.look_at(Vector3(pos.x * 0.2, 0, pos.z * 0.5 - 2.0))
	KIT.box_body(root, pos + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.7), 0.0, "FloodlightBody")

func _west_route() -> void:
	var root := Node3D.new()
	root.name = "WestLedgeRoute"
	add_child(root)
	# Scaffold watchtower on the ledge: 4 m deck reached by a stair ramp (vertical observation point).
	var base := Vector3(-16, LEDGE_Y, -6)
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 4.0, 0.12)
	for c in [Vector3(-1.5, 2, -1.5), Vector3(1.5, 2, -1.5), Vector3(-1.5, 2, 1.5), Vector3(1.5, 2, 1.5)]:
		KIT.mesh(root, post, Transform3D(Basis(), base + c), steel, "ScaffoldPost").set_meta("collision", "none")
		KIT.box_body(root, base + c, Vector3(0.14, 4.0, 0.14), 0.0, "PostBody")
	var deck := BoxMesh.new()
	deck.size = Vector3(3.4, 0.12, 3.4)
	var plank := KIT.std_mat(Color(0.33, 0.27, 0.2), 0.9)
	KIT.mesh(root, deck, Transform3D(Basis(), base + Vector3(0, 4.0, 0)), plank, "ScaffoldDeck").set_meta("collision", "none")
	KIT.box_body(root, base + Vector3(0, 3.95, 0), Vector3(3.4, 0.2, 3.4), 0.0, "DeckBody")
	var rail := BoxMesh.new()
	rail.size = Vector3(3.4, 0.06, 0.06)
	for zz in [-1.65, 1.65]:
		KIT.mesh(root, rail, Transform3D(Basis(), base + Vector3(0, 5.0, zz)), steel).set_meta("collision", "none")
	# Stair ramp up to the deck (from the east side of the tower, rising toward -z).
	var ramp_len := 6.5
	var rise := 4.0
	var ang := atan2(rise, ramp_len)
	var ramp_center := base + Vector3(2.6, rise * 0.5, ramp_len * 0.5 + 1.2)
	var rb := Basis(Vector3.RIGHT, ang)
	var ramp := BoxMesh.new()
	ramp.size = Vector3(1.1, 0.1, sqrt(ramp_len * ramp_len + rise * rise))
	KIT.mesh(root, ramp, Transform3D(rb, ramp_center), plank, "StairRamp").set_meta("collision", "none")
	var body := StaticBody3D.new()
	body.name = "StairRampBody"
	body.collision_layer = 3
	root.add_child(body)
	body.global_transform = Transform3D(rb, ramp_center)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.12, sqrt(ramp_len * ramp_len + rise * rise))
	cs.shape = box
	body.add_child(cs)
	var landing := BoxMesh.new()
	landing.size = Vector3(1.4, 0.12, 1.4)
	KIT.mesh(root, landing, Transform3D(Basis(), base + Vector3(2.4, 3.95, 0.6)), plank).set_meta("collision", "none")
	KIT.box_body(root, base + Vector3(2.4, 3.92, 0.6), Vector3(1.4, 0.16, 1.4), 0.0, "LandingBody")
	# Searchlight on the tower sweeping the checkpoint.
	var sweep := SpotLight3D.new()
	sweep.name = "TowerSearchlight"
	sweep.light_color = Color(0.85, 0.92, 1.0)
	sweep.light_energy = 4.0
	sweep.spot_range = 40.0
	sweep.spot_angle = 14.0
	root.add_child(sweep)
	sweep.global_position = base + Vector3(0, 5.2, 0)
	_sweeper = sweep

var _sweeper: SpotLight3D

func _east_route() -> void:
	var water := preload("res://systems/water/WaterBody.tscn").instantiate()
	water.name = "DrainageChannelWater"
	water.set("preset_name", "UNDERGROUND_STREAM")
	water.set("size", Vector2(5.0, 50.0))
	water.set("depth", 1.0)
	water.set("surface_level", 0.0)
	add_child(water)
	water.global_position = Vector3(15, -0.45, 4)
	# Drainage pipes and grates along the channel (low cover).
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.45
	pipe.bottom_radius = 0.45
	pipe.height = 4.0
	var rust := KIT.std_mat(Color(0.3, 0.2, 0.14), 0.7, 0.5)
	for k in 4:
		var p := Vector3(12.2 if k % 2 == 0 else 17.8, 0.35, 20.0 - k * 11.0)
		KIT.mesh(self, pipe, Transform3D(Basis(Vector3.FORWARD, PI / 2) * Basis(Vector3.RIGHT, 0.0), p), rust, "DrainPipe%d" % k)
		KIT.box_body(self, p, Vector3(4.0, 0.9, 0.9), 0.0, "DrainPipeBody%d" % k)

func _overlook() -> void:
	var root := Node3D.new()
	root.name = "TempleOverlook"
	add_child(root)
	# Flooded temple basin below the overlook (visual landmark; chapter 6 continues here).
	var basin := preload("res://systems/water/WaterBody.tscn").instantiate()
	basin.name = "TempleBasinVista"
	basin.set("preset_name", "FLOODED_TEMPLE")
	basin.set("size", Vector2(60.0, 30.0))
	basin.set("depth", 4.0)
	basin.set("splashes", false)
	add_child(basin)
	basin.global_position = Vector3(0, BASIN_Y - 0.6, -52)
	# Vaelor pillars rising out of the water: the temple facade landmark.
	for k in 6:
		var x := -15.0 + k * 6.0
		var p := KIT.place(root, PILLAR, Vector3(x, BASIN_Y - 3.0, -48.0 - absf(x) * 0.15), rng.randf_range(9.0, 12.0), rng.randf_range(-0.2, 0.2), Vector3.ONE, true, "TemplePillar%d" % k)
	KIT.omni(root, Vector3(0, BASIN_Y + 4.0, -48.0), Color(0.45, 0.75, 0.85), 2.0, 26.0)
	# Rope rail along the overlook lip.
	var rope := BoxMesh.new()
	rope.size = Vector3(10, 0.04, 0.04)
	KIT.mesh(root, rope, Transform3D(Basis(), Vector3(-9, 1.0, -22.6)), KIT.std_mat(Color(0.5, 0.4, 0.25), 0.9)).set_meta("collision", "none")
	KIT.mesh(root, rope, Transform3D(Basis(), Vector3(9, 1.0, -22.6)), KIT.std_mat(Color(0.5, 0.4, 0.25), 0.9)).set_meta("collision", "none")

func _discoveries() -> void:
	var d := Node3D.new()
	d.name = "Discoveries"
	add_child(d)
	KIT.collectible(d, "c05_meridian_order", "document", "Meridian Requisition Order 7-C",
		"PRIORITY: Secure aqueduct access before the Vale team.\nSOURCE: survey coordinates relayed by 'A.K.' (field asset).\nEQUIPMENT: 4x pumps, 2x floodlight rigs, breaching charges.\nAUTHORISED: L. Drake.\n\nSomeone inside the expedition gave them our route.",
		Vector3(12.0, 1.3, -18.6), 0.3)
	KIT.collectible(d, "c05_tower_logbook", "journal", "Watch Log, Tower 2",
		"0200: Lights on the ridge again. Vale's people?\n0340: Drake says no shooting unless they touch the water gates.\n0410: Something in the channel. Rats, probably. Too big for rats.",
		Vector3(-16.6, LEDGE_Y + 4.08, -6.4), 0.8)

func _lighting(level: Node3D) -> void:
	var env_node := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		env.background_color = Color(0.015, 0.018, 0.022)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.3, 0.32, 0.36)
		env.ambient_light_energy = 1.1
		env.fog_light_color = Color(0.1, 0.11, 0.12)
		env.fog_density = 0.012
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env_node.environment = env
	# Fill: the Compatibility renderer caps per-mesh lights at 8, so the big cavern floor
	# gets a dim overhead key standing in for the floodlight bounce.
	var key := DirectionalLight3D.new()
	key.name = "FloodlightBounceKey"
	key.light_color = Color(0.85, 0.88, 0.95)
	key.light_energy = 0.55
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	add_child(key)
	key.rotation = Vector3(deg_to_rad(-62), deg_to_rad(20), 0)
	# Warm work lamps strung along the centre lane + red beacons.
	for k in 5:
		var p := Vector3(-3.5 if k % 2 else 3.5, 3.2, 20.0 - k * 9.0)
		KIT.omni(self, p, Color(1.0, 0.75, 0.45), 1.2, 9.0)
		var bulb := SphereMesh.new()
		bulb.radius = 0.09
		bulb.height = 0.18
		KIT.mesh(self, bulb, Transform3D(Basis(), p), lamp_mat).set_meta("collision", "none")
	for p in [Vector3(-16, LEDGE_Y + 5.3, -6), Vector3(10, 3.2, -20)]:
		var b := KIT.omni(self, p, Color(1, 0.15, 0.1), 1.0, 4.0)
		_blink.append(b)

func _process(delta: float) -> void:
	_t += delta
	for b in _blink:
		b.visible = fmod(_t, 1.4) < 0.3
	if _sweeper:
		var target := Vector3(sin(_t * 0.35) * 10.0, 0.0, -2.0 + cos(_t * 0.27) * 10.0)
		_sweeper.look_at(target)

func hook_audio(sc: Node) -> void:
	if sc == null:
		return
	sc.add_emitter("res://audio/ambience/meridian/AMB_MERIDIAN_POWER.ogg", Vector3(-10, 1, 17), 0.0, 30.0)
	sc.add_emitter("res://audio/ambience/cave/AMB_PRO_CAVE_WATER.ogg", Vector3(15, 0.2, 4), -4.0, 22.0)
	sc.add_emitter("res://audio/ambience/temple/AMB_DROWNED_TEMPLE.wav", Vector3(0, BASIN_Y, -45), 0.0, 40.0)
	sc.add_reverb_zone(Vector3(0, 8, 2), Vector3(50, 18, 60), "cave")
	sc.add_reverb_zone(Vector3(0, 0, -42), Vector3(40, 16, 30), "temple")

# ------------------------------------------------------------------ phase-2 hero assets
const H5 := "res://assets/models/hero/ch5/lod/"
const H4 := "res://assets/models/hero/ch4/lod/"
const CAVE := "res://assets/models/cave/lod/"

func _hero_props(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MeridianHeroProps"
	add_child(root)
	# Drill rig at the overlook: Meridian is boring toward the aqueduct (landmark).
	var drill := KIT.place(root, H5 + "ch5_meridian_excavation_drill_LOD0.glb", Vector3(-9.0, 0, -21.0), 7.0, 0.5, Vector3.ONE, false, "DrillRig")
	if drill:
		drill.set_meta("collision", "convex")
	# Barricades: chest-high cover on all three lanes.
	var bars := [[Vector3(3.8, 0, 14.0), 0.1], [Vector3(-14.0, LEDGE_Y, 4.0), 1.4], [Vector3(15.0, -0.9, -6.0), PI / 2], [Vector3(-4.0, 0, -4.5), -0.3], [Vector3(6.5, 0, -16.0), 0.2]]
	for i in bars.size():
		var b := KIT.place(root, H5 + "ch5_meridian_cover_barricade_LOD0.glb", bars[i][0], 4.0, bars[i][1], Vector3.ONE, false, "Barricade%d" % i)
		if b:
			b.set_meta("collision", "box")
	var mast := KIT.place(root, H5 + "ch5_meridian_comms_mast_LOD0.glb", Vector3(12.0, 0, -23.0), 7.0, 0.0, Vector3.ONE, true, "CommsMast")
	KIT.place(root, H4 + "ch4_meridian_generator_LOD0.glb", Vector3(-12.0, 0, 18.5), 2.2, 0.4, Vector3.ONE, false, "HeroGenerator")
	KIT.place(root, H4 + "ch4_meridian_crate_stack_LOD0.glb", Vector3(-17.5, LEDGE_Y, -12.0), 2.6, 0.3, Vector3.ONE, false, "CrateStackLedge")
	KIT.place(root, H4 + "ch4_meridian_crate_stack_LOD0.glb", Vector3(8.5, 0, 16.0), 2.4, -0.6, Vector3.ONE, false, "CrateStackSouth")
	KIT.place(root, H4 + "ch4_meridian_field_tent_LOD0.glb", Vector3(-6.0, 0, -24.5) + Vector3(18, 0, 6), 5.0, PI, Vector3.ONE, false, "FieldTent")
	KIT.place(root, H4 + "ch4_mobile_light_tower_LOD0.glb", Vector3(-1.0, 0, 18.0), 6.0, 0.8, Vector3.ONE, true, "LightTower")
	KIT.omni(root, Vector3(-1.0, 6.0, 17.0), Color(1, 0.95, 0.85), 2.0, 18.0)
	# Cave set dressing: flowstone columns + stalactite clusters.
	for k in 6:
		var x := rng.randf_range(-21, 21)
		var z := rng.randf_range(-20, 30)
		if absf(x) < 6.0 or absf(x - 15.0) < 4.0 or (absf(x + 16.0) < 8.5 and absf(z) < 16.0):
			continue
		KIT.place(root, CAVE + "cav_flowstone_column_LOD0.glb", Vector3(x, terrain.height_at(x, z) - 0.3, z), rng.randf_range(10.0, 17.0), rng.randf() * TAU, Vector3.ONE, true, "Column%d" % k)
	for k in 10:
		var c := KIT.place(root, CAVE + "cav_stalactite_ceiling_cluster_LOD0.glb", Vector3(rng.randf_range(-20, 20), 13.5, rng.randf_range(-30, 30)), rng.randf_range(5.0, 8.0), rng.randf() * TAU, Vector3.ONE, false, "Stalactites%d" % k)
		if c:
			c.set_meta("collision", "none")
	for side in [-1.0, 1.0]:
		for k in 3:
			var z := 20.0 - k * 18.0
			var cl := KIT.place(root, CAVE + ("cav_limestone_cliff_a_LOD0.glb" if k % 2 == 0 else "cav_limestone_cliff_b_overhang_LOD0.glb"), Vector3(side * 21.5, terrain.height_at(side * 21.5, z) - 1.0, z), 12.0, (PI / 2) * -side, Vector3.ONE, false, "HeroCliff%s%d" % ["W" if side < 0 else "E", k])
			if cl:
				cl.set_meta("collision", "trimesh")
	# Mercenary variants via bone-attached gear.
	var gear := preload("res://systems/levelb/LBMeridianGear.gd")
	var variants := ["rifleman", "radio", "heavy"]
	var i := 0
	for e in level.get_tree().get_nodes_in_group("enemies"):
		if level.is_ancestor_of(e):
			gear.equip(e, variants[i % variants.size()])
			i += 1