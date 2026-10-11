extends Node3D
## Chapter 6 "The Drowned Temple": flooded Vaelor hall (WaterBody FLOODED_TEMPLE),
## underwater ruins, large hydraulic machinery driving the drain, wet stone after
## draining, and an east cistern with a RISING_PUZZLE_WATER valve puzzle (secondary
## route + optional tablet on the high ledge).

const KIT := preload("res://systems/levelb/LBKit.gd")
const TERRAIN := preload("res://systems/levelb/LBTerrain.gd")
const WALL := "res://assets/models/optimized/arch_wall_vaelor_LOD0.glb"
const PILLAR := "res://assets/models/optimized/ruin_pillar_vaelor_LOD0.glb"
const FLOORSTONE := "res://assets/models/optimized/arch_floor_stone_LOD0.glb"
const STALAG := "res://assets/models/optimized/env_stalagmite_cluster_LOD0.glb"
const BOULDER := "res://assets/models/optimized/env_boulder_moss_LOD0.glb"
const CEIL := "res://assets/environment/cave/cave_ceiling_limestone.glb"
const CLIFF := "res://assets/environment/cave/cave_wall_limestone.glb"
const FLOOR_Y := -3.8
const WATER_Y := 0.6       # basin surface (world)
const DRAINED_Y := -3.62   # a few cm of standing water remain
const CISTERN := Vector3(30, FLOOR_Y, -5)

var terrain: TERRAIN
var basin: Node3D
var cistern_water: Node3D
var rng := RandomNumberGenerator.new()
var bronze: StandardMaterial3D
var gears: Array[Node3D] = []
var sluice_gates: Array[Node3D] = []
var _spin := 0.0
var _spin_target := 0.0
var cistern_raised := false
var sc: Node

## Set by Chapter6 when staged by RegionHandoff: build() yields a frame between steps.
var step_yield := false
var aqueduct_stone: Material

func _init() -> void:
	name = "LevelBDressing"

var _step_t := 0

func _step() -> void:
	if step_yield and is_inside_tree():
		var now := Time.get_ticks_msec()
		if _step_t > 0:
			print("[REGION] Ch6 dressing step %d ms" % (now - _step_t))
		await get_tree().process_frame
		_step_t = Time.get_ticks_msec()

func build(level: Node3D) -> void:
	rng.seed = 606
	bronze = KIT.std_mat(Color(0.42, 0.3, 0.16), 0.38, 0.85)
	var floor_body := level.get_node_or_null("TempleStructure/Floor")
	if floor_body:
		for c in floor_body.get_children():
			if c is GeometryInstance3D:
				c.visible = false
	var plane := level.get_node_or_null("FloodedBasin/WaterPlane") as Node3D
	if plane:
		plane.visible = false # legacy presentation; the WaterBody below renders and simulates
		plane.set_process(false)
	terrain = TERRAIN.new()
	terrain.name = "TempleFloor"
	add_child(terrain)
	await _step()
	terrain.build(Vector2(-40, -45), Vector2(85, 80), 0.8, _height, _mask)
	await _step()
	var m := terrain.material
	m.set_shader_parameter("grass_a", Vector3(0.24, 0.26, 0.22))
	m.set_shader_parameter("grass_b", Vector3(0.3, 0.31, 0.27))
	m.set_shader_parameter("soil_a", Vector3(0.2, 0.2, 0.18))
	m.set_shader_parameter("soil_b", Vector3(0.27, 0.26, 0.23))
	m.set_shader_parameter("litter", Vector3(0.16, 0.2, 0.12))
	m.set_shader_parameter("rock_tint", Vector3(0.45, 0.46, 0.44))
	terrain.mesh_instance.add_to_group("wettable")
	_water()
	await _step()
	_architecture()
	await _step()
	_machinery(level)
	await _step()
	_cistern()
	await _step()
	_underwater()
	await _step()
	_discoveries()
	await _step()
	_lighting(level)
	await _step()
	_hero_props()
	await _step()

func _height(x: float, z: float) -> float:
	var h := FLOOR_Y
	if absf(x) < 3.6 and z > 24.0:
		return FLOOR_Y # trench for the Ch5 aqueduct ramp (roofed by Ch5Ch6Aqueduct)
	# Flagstone steps rising to dry terraces outside the hall.
	var outside := maxf(smoothstep(23.0, 26.0, absf(x - 0.0)), smoothstep(25.0, 28.0, z))
	if CISTERN.x - 6.0 < x and x < CISTERN.x + 6.0 and absf(z - CISTERN.z) < 6.0:
		return FLOOR_Y # cistern shaft floor
	h = lerpf(h, 9.0, outside)
	# Rubble mounds on the hall floor (underwater exploration relief).
	var n := sin(x * 0.45) * cos(z * 0.38) * 0.25
	return h + maxf(n, 0.0)

func _mask(x: float, z: float) -> Color:
	var aisle := 1.0 - smoothstep(2.0, 3.5, absf(x))
	# Terraces outside the hall show above/through the wall tops: dark cave rock there, not
	# the pale flagstone grey (it read as white specks along the wall line).
	var outside := maxf(smoothstep(22.0, 25.0, absf(x)), smoothstep(24.0, 27.0, z))
	return Color(aisle * 0.4 * (1.0 - outside), outside * 0.9, 0.6 * (1.0 - outside), 0.5)

func _water() -> void:
	basin = preload("res://systems/water/WaterBody.tscn").instantiate()
	basin.name = "TempleBasinWater"
	basin.set("preset_name", "FLOODED_TEMPLE")
	basin.set("size", Vector2(46.0, 38.0))
	basin.set("depth", WATER_Y - FLOOR_Y + 0.4)
	basin.set("surface_level", 0.0)
	basin.set("wet_dry_time", 90.0)
	basin.set("quality_override", 0) # force the full shader (depth/refraction/foam) even on Low
	# Level-B grade of the temple preset: the stock FLOODED_TEMPLE goes near-black over a 6 m
	# deep, dim hall. Clearer green-teal body so the sunken floor/pillars read through it.
	var wp: Resource = WaterPreset.make("FLOODED_TEMPLE").duplicate()
	wp.shallow_color = Color(0.2, 0.4, 0.36)
	wp.deep_color = Color(0.035, 0.12, 0.115)
	wp.absorption = Vector3(0.32, 0.12, 0.13)
	wp.clarity = 0.8
	wp.normal_strength = 0.55
	wp.roughness_base = 0.04
	wp.specular_amount = 0.7
	basin.set("preset", wp)
	add_child(basin)
	basin.global_position = Vector3(-1.0, WATER_Y, 6.0)

func drain(seconds: float) -> void:
	if basin and basin.has_method("set_level"):
		basin.set_level(DRAINED_Y - WATER_Y, seconds)
	_spin_target = 1.0
	for g in sluice_gates:
		var tw := create_tween()
		tw.tween_property(g, "position:y", g.position.y + 3.2, seconds * 0.8).set_trans(Tween.TRANS_SINE)
	if sc:
		sc.set_water_state("draining", Vector3(-20, 0, 0))
		sc.play_oneshot("res://audio/vaelor/SFX_STONE_MECHANISM_GRIND.wav", Vector3(-18, 2, 0), -2.0, 40.0)
		get_tree().create_timer(seconds + 1.0).timeout.connect(func():
			if sc:
				sc.set_water_state("idle"))
	get_tree().create_timer(seconds).timeout.connect(func(): _spin_target = 0.15)

func _process(delta: float) -> void:
	_tt += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.0 + sin(_tt * 11.0 + i) * 0.15 + sin(_tt * 6.7 + i * 2.0) * 0.2
	_spin = move_toward(_spin, _spin_target, delta * 0.4)
	if waterwheel:
		waterwheel.rotate_object_local(Vector3.RIGHT, delta * (_spin * 0.6 + 0.04))
	for i in gears.size():
		var g := gears[i]
		g.rotate_object_local(Vector3.UP, delta * _spin * (1.6 if i % 2 == 0 else -2.4))

# ------------------------------------------------------------------ architecture

func _architecture() -> void:
	var root := Node3D.new()
	root.name = "TempleHall"
	add_child(root)
	var stone := KIT.rock_material(Color(0.66, 0.68, 0.64), 0.35).duplicate() as ShaderMaterial
	stone.set_shader_parameter("detail_contrast", 0.3)
	stone.set_shader_parameter("specular_amount", 0.12)
	# Perimeter walls (Vaelor carved), leaving the north gate and east walkway open.
	var spans := []
	for z in [20.0, 12.0, 4.0, -4.0]:
		spans.append([Vector3(-24.5, FLOOR_Y - 0.5, z), 0.0])
		if z > 0.0 or z < -8.0:
			spans.append([Vector3(22.5, FLOOR_Y - 0.5, z), PI])
	for x in [-19.5, -11.5, 11.5, 19.5, -7.0, 7.0]:
		spans.append([Vector3(x, FLOOR_Y - 0.5, -12.5), PI / 2])
	for x in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
		spans.append([Vector3(x, FLOOR_Y - 0.5, 25.5), -PI / 2])
	for i in spans.size():
		if absf(spans[i][0].z - 25.5) < 0.1 and absf(spans[i][0].x) < 5.0:
			continue # centre south spans replaced by the aqueduct doorway below
		# Wall model: long axis Z (1.0), height 0.42, thin X; fit 8.2 m long, stretch to ~11 m tall.
		var w := KIT.place(root, WALL, spans[i][0], 8.2, spans[i][1], Vector3(1.0, 3.2, 1.0), false, "HallWall%02d" % i)
		if w:
			KIT.override_material(w, stone)
			w.set_meta("collision", "trimesh")
			w.add_to_group("wettable")
	# The wall trimesh is one-sided from the hall, so the camera spring arm passed
	# through it at spawn. Back the south wall with a solid box on the world layer.
	# Leaves a 5 m doorway (x -2.5..2.5, up to y 5.0) for the Meridian aqueduct from Ch5.
	for seg in [[Vector3(-13.25, 1.2, 25.6), Vector3(21.5, 11.0, 1.2)], [Vector3(13.25, 1.2, 25.6), Vector3(21.5, 11.0, 1.2)], [Vector3(0, 5.9, 25.6), Vector3(5.0, 1.8, 1.2)]]:
		var south_back := StaticBody3D.new()
		south_back.name = "SouthWallBacking"
		south_back.collision_layer = 2
		south_back.collision_mask = 0
		root.add_child(south_back)
		south_back.position = seg[0]
		var south_shape := CollisionShape3D.new()
		var south_box := BoxShape3D.new()
		south_box.size = seg[1]
		south_shape.shape = south_box
		south_back.add_child(south_shape)
	# Door frame: carved stone infill either side of the opening, Vaelor pillars and a lintel.
	for x in [-5.25, 5.25]:
		var infill := BoxMesh.new()
		infill.size = Vector3(5.5, 11.0, 1.2)
		KIT.mesh(root, infill, Transform3D(Basis(), Vector3(x, 1.2, 25.5)), stone, "DoorInfill").add_to_group("wettable")
	var lintel := BoxMesh.new()
	lintel.size = Vector3(6.0, 1.8, 1.4)
	KIT.mesh(root, lintel, Transform3D(Basis(), Vector3(0, 5.9, 25.5)), stone, "DoorLintel").add_to_group("wettable")
	for x in [-2.9, 2.9]:
		var p := KIT.place(root, PILLAR, Vector3(x, 1.0, 24.9), 4.6, 0.0, Vector3.ONE, true, "DoorPillar")
		if p:
			KIT.override_material(p, stone)
	aqueduct_stone = stone
	# Dry entry landing (spawn) at the south wall: Mara starts on stone, steps into the flood.
	var landing := BoxMesh.new()
	landing.size = Vector3(8.0, 4.8, 5.0)
	KIT.mesh(root, landing, Transform3D(Basis(), Vector3(0, -1.4, 23.0)), stone, "EntryLanding").add_to_group("wettable")
	KIT.box_body(root, Vector3(0, -1.4, 23.0), Vector3(8.0, 4.8, 5.0), 0.0, "EntryLandingBody")
	var step := BoxMesh.new()
	step.size = Vector3(4.0, 4.4, 1.2)
	KIT.mesh(root, step, Transform3D(Basis(), Vector3(0, -1.6, 19.9)), stone, "EntryStep")
	KIT.box_body(root, Vector3(0, -1.6, 19.9), Vector3(4.0, 4.4, 1.2), 0.0, "EntryStepBody")
	# Colonnade pillars standing in the water.
	for side in [-1.0, 1.0]:
		for z in [18.0, 10.0, 2.0, -6.0]:
			var p := KIT.place(root, PILLAR, Vector3(side * 16.5, FLOOR_Y, z), 11.0, rng.randf_range(-0.1, 0.1), Vector3.ONE, true, "Colonnade%s%d" % ["W" if side < 0 else "E", int(z)])
			if p:
				KIT.override_material(p, stone)
				p.add_to_group("wettable")
	# Cavern ceiling and outer rock beyond the hall.
	var cave := KIT.rock_material(Color(0.36, 0.37, 0.36), 0.25).duplicate() as ShaderMaterial
	cave.set_shader_parameter("detail_contrast", 0.5)
	for k in 10:
		var c := KIT.place(root, CEIL, Vector3(rng.randf_range(-22, 22), rng.randf_range(13.0, 15.0), rng.randf_range(-12, 24)), rng.randf_range(16, 22), rng.randf() * TAU, Vector3.ONE, false, "Vault%02d" % k)
		if c:
			KIT.override_material(c, cave)
			c.set_meta("collision", "none")
	# Light shaft from the collapsed roof (the existing AqueductSkylight direction).
	var shaft := CylinderMesh.new()
	shaft.top_radius = 2.2
	shaft.bottom_radius = 3.4
	shaft.height = 16.0
	shaft.cap_top = false
	shaft.cap_bottom = false
	var beam := ShaderMaterial.new()
	beam.shader = preload("res://systems/levelb/light_shaft.gdshader")
	var b := KIT.mesh(root, shaft, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(3, 6, 8)), beam, "LightShaft")
	b.set_meta("collision", "none")
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Dust motes drifting in the shaft.
	var motes := GPUParticles3D.new()
	motes.name = "ShaftDust"
	motes.amount = 60
	motes.lifetime = 8.0
	motes.visibility_aabb = AABB(Vector3(-4, -8, -4), Vector3(8, 16, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 6.0, 2.0)
	pm.gravity = Vector3(0, -0.02, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.direction = Vector3(0.3, 0.2, 0.1)
	pm.spread = 180.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
	dm.albedo_texture = KIT.grain()
	q.material = dm
	motes.draw_pass_1 = q
	root.add_child(motes)
	motes.global_position = Vector3(3, 5, 8)
# ------------------------------------------------------------------ hydraulic machinery

func _machinery(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "HydraulicMachinery"
	add_child(root)
	# Sanctum arch: face the aqueduct ramp and frame it (was side-on and blocked the ramp).
	var arch := level.get_node_or_null("TempleSanctum/SanctumPortal") as Node3D
	if arch:
		arch.transform = Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * 7.5), Vector3(0, -2.4, 0))
		arch.set_meta("collision", "none")
		for side in [-1.0, 1.0]:
			KIT.box_body(root, Vector3(side * 3.1, 0.5, -25.0), Vector3(1.0, 7.0, 2.5), 0.0, "ArchJamb")
	# Scale the existing turbine (the interactable stays where QA/players expect it).
	var turbine := level.get_node_or_null("TempleMechanisms/SluiceWheel/TurbineWheelModel") as Node3D
	if turbine:
		turbine.scale = Vector3.ONE * 3.0
		turbine.position = Vector3(-1.9, -0.6, 0)
		turbine.set_meta("collision", "none")
		KIT.box_body(root, Vector3(-14.0, 0.6, 0), Vector3(1.4, 4.2, 3.6), 0.0, "TurbineBody")
		gears.append(turbine)
	# Great gear train against the west wall: three meshing bronze wheels + axle.
	var specs := [[Vector3(-21.0, 1.5, -2.0), 3.2], [Vector3(-21.0, 5.6, 2.2), 2.0], [Vector3(-21.0, 1.0, 5.2), 1.4]]
	for i in specs.size():
		var g := Node3D.new()
		g.name = "Gear%d" % i
		root.add_child(g)
		g.global_transform = Transform3D(Basis(Vector3.FORWARD, PI / 2), specs[i][0])
		var r: float = specs[i][1]
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.45
		disc.radial_segments = 32
		var dm := MeshInstance3D.new()
		dm.mesh = disc
		dm.material_override = bronze
		g.add_child(dm)
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.35, 0.42, 0.5)
		var teeth := int(r * 9)
		for t in teeth:
			var a := TAU * t / teeth
			var tm := MeshInstance3D.new()
			tm.mesh = tooth
			tm.material_override = bronze
			tm.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * (r + 0.15), 0, sin(a) * (r + 0.15)))
			g.add_child(tm)
		var spoke := BoxMesh.new()
		spoke.size = Vector3(r * 2.0, 0.5, 0.3)
		for s in 3:
			var sm := MeshInstance3D.new()
			sm.mesh = spoke
			sm.material_override = bronze
			sm.rotation.y = s * PI / 3.0
			g.add_child(sm)
		g.set_meta("collision", "none")
		gears.append(g)
		KIT.box_body(root, specs[i][0], Vector3(0.6, r * 2.0, r * 2.0), 0.0, "GearBody%d" % i)
	# Axle from the turbine to the gear train.
	var axle := CylinderMesh.new()
	axle.top_radius = 0.25
	axle.bottom_radius = 0.25
	axle.height = 9.0
	KIT.mesh(root, axle, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(-16.5, 1.5, -2.0)), bronze, "DriveAxle").set_meta("collision", "none")
	# Hydraulic pistons (stone cylinders with bronze rams).
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.6
	cyl.height = 5.0
	var stone := KIT.rock_material(Color(0.62, 0.64, 0.6), 0.2)
	for z in [-8.0, 9.0]:
		KIT.mesh(root, cyl, Transform3D(Basis(), Vector3(-22.0, FLOOR_Y + 2.5, z)), stone, "PistonHousing").add_to_group("wettable")
		KIT.box_body(root, Vector3(-22.0, FLOOR_Y + 2.5, z), Vector3(1.2, 5.0, 1.2), 0.0, "PistonBody")
	# Sluice gates in the west wall: rise as the basin drains (outflow).
	var gate_mesh := BoxMesh.new()
	gate_mesh.size = Vector3(0.6, 3.6, 3.2)
	for z in [-6.0, 12.0, 18.0]:
		var gate := Node3D.new()
		gate.name = "SluiceGate"
		root.add_child(gate)
		gate.global_position = Vector3(-23.6, FLOOR_Y + 1.8, z)
		if ResourceLoader.exists(H6 + "ch6_sluice_gate_LOD0.glb"):
			var gmodel := KIT.place(gate, H6 + "ch6_sluice_gate_LOD0.glb", Vector3(0, -1.8, 0), 4.0, PI / 2, Vector3.ONE, false)
			if gmodel:
				gmodel.add_to_group("wettable")
		else:
			var gm := MeshInstance3D.new()
			gm.mesh = gate_mesh
			gm.material_override = stone
			gm.add_to_group("wettable")
			gate.add_child(gm)
		gate.set_meta("collision", "none")
		sluice_gates.append(gate)
		var frame := BoxMesh.new()
		frame.size = Vector3(0.8, 0.5, 4.0)
		KIT.mesh(root, frame, Transform3D(Basis(), Vector3(-23.6, FLOOR_Y + 3.9, z)), bronze).set_meta("collision", "none")
	KIT.omni(root, Vector3(-19, 4.5, 2), Color(1.0, 0.75, 0.45), 1.6, 14.0)

# ------------------------------------------------------------------ cistern puzzle

func _cistern() -> void:
	var root := Node3D.new()
	root.name = "EastCistern"
	add_child(root)
	var stone := KIT.rock_material(Color(0.47, 0.49, 0.47), 0.3)
	# Walkway from the hall's east opening (x 22.5) to the cistern lip, just above basin water.
	var walk := BoxMesh.new()
	walk.size = Vector3(4.0, 0.5, 4.0)
	for k in 2:
		var p := Vector3(22.5 + k * 1.5, 0.45, -5)
		KIT.mesh(root, walk, Transform3D(Basis(), p), stone, "Walkway%d" % k)
		KIT.box_body(root, p, Vector3(4.0, 0.5, 4.0), 0.0, "WalkwayBody%d" % k)
	# Shaft walls (12 x 12, 10 m tall) with the opening facing west at the top.
	var wall := BoxMesh.new()
	for side in [[Vector3(6.2, 1.2, 0), Vector3(0.6, 10.0, 12.4)], [Vector3(0, 1.2, 6.2), Vector3(12.4, 10.0, 0.6)], [Vector3(0, 1.2, -6.2), Vector3(12.4, 10.0, 0.6)], [Vector3(-6.2, -2.1, 0), Vector3(0.6, 3.4, 12.4)], [Vector3(-6.2, 4.6, 0), Vector3(0.6, 3.2, 12.4)]]:
		wall.size = side[1]
		var mesh_copy := wall.duplicate() as BoxMesh
		var c: Vector3 = CISTERN + Vector3(0, 3.8, 0) + side[0]
		KIT.mesh(root, mesh_copy, Transform3D(Basis(), c), stone, "CisternWall").add_to_group("wettable")
		KIT.box_body(root, c, side[1], 0.0, "CisternWallBody")
	# High ledge on the east wall holding the tablet (reachable only by swimming up).
	var ledge := BoxMesh.new()
	ledge.size = Vector3(2.4, 0.4, 5.0)
	var lp := CISTERN + Vector3(4.6, 8.0, 0)
	KIT.mesh(root, ledge, Transform3D(Basis(), lp), stone, "HighLedge")
	KIT.box_body(root, lp, Vector3(2.4, 0.4, 5.0), 0.0, "HighLedgeBody")
	cistern_water = preload("res://systems/water/WaterBody.tscn").instantiate()
	cistern_water.name = "CisternWater"
	cistern_water.set("preset_name", "RISING_PUZZLE_WATER")
	cistern_water.set("size", Vector2(11.6, 11.6))
	cistern_water.set("depth", 9.0)
	cistern_water.set("surface_level", -7.6)
	cistern_water.set("quality_override", 0) # nearly dry until the valve is opened
	add_child(cistern_water)
	cistern_water.global_position = CISTERN + Vector3(0, 7.8, 0)
	# Valve wheel at the shaft floor.
	var valve := Node3D.new()
	valve.name = "CisternValve"
	root.add_child(valve)
	valve.global_position = CISTERN + Vector3(-4.8, 1.2, 3.5)
	var vw := TorusMesh.new()
	vw.inner_radius = 0.35
	vw.outer_radius = 0.5
	var vm := MeshInstance3D.new()
	vm.mesh = vw
	vm.material_override = bronze
	vm.rotation.z = PI / 2
	valve.add_child(vm)
	var area := KIT.interaction(valve, Vector3.ZERO, Vector3(2.0, 2.4, 2.0), "[E] Open the cistern intake valve")
	area.interacted.connect(_on_valve.bind(vm))
	# Feed pipe spilling in when open.
	KIT.omni(root, CISTERN + Vector3(0, 6, 0), Color(0.5, 0.75, 0.85), 1.3, 12.0)

func _on_valve(_p: Node, wheel: Node3D) -> void:
	if cistern_raised:
		return
	cistern_raised = true
	var tw := create_tween()
	tw.tween_property(wheel, "rotation:x", TAU * 2.0, 3.0)
	cistern_water.set_level(0.6, 10.0) # surface to world ~8.4, level with the high ledge
	MissionManager.register_objective("obj_c06_opt_cistern", "Swim up the flooding cistern to the high ledge")
	if sc:
		sc.set_water_state("rising", CISTERN + Vector3(0, 2, 0))
		get_tree().create_timer(11.0).timeout.connect(func():
			if sc:
				sc.set_water_state("idle"))
	cistern_water.level_target_reached.connect(func(_y): MissionManager.complete_objective("obj_c06_opt_cistern"), CONNECT_ONE_SHOT)
	AudioManager.play_story_line("Mara", "Intake's open. If the Vaelor built this right, the water will carry me up.", 4.0)

# ------------------------------------------------------------------ underwater

func _underwater() -> void:
	var root := Node3D.new()
	root.name = "SunkenRuins"
	add_child(root)
	var stone := KIT.rock_material(Color(0.6, 0.63, 0.6), 0.5)
	# Toppled pillars and floor slabs on the hall floor.
	for k in 6:
		var p := Vector3(rng.randf_range(-20, 18), FLOOR_Y - 0.4, rng.randf_range(-8, 22))
		if absf(p.x) < 4.0 or Vector2(p.x + 12, p.z).length() < 5.0:
			continue
		var pil := KIT.place(root, PILLAR, p, 6.0, rng.randf() * TAU, Vector3.ONE, true, "FallenPillar%d" % k)
		if pil:
			pil.rotation.x = PI / 2 - 0.15
			pil.global_position.y = FLOOR_Y + 0.4
			KIT.override_material(pil, stone)
			pil.add_to_group("wettable")
	for k in 10:
		var p := Vector3(rng.randf_range(-22, 20), FLOOR_Y - 0.1, rng.randf_range(-10, 24))
		# Floor-stone model stands upright (thin X): lay it flat as a broken slab.
		var s := KIT.place(root, FLOORSTONE, p, rng.randf_range(2.0, 3.0), rng.randf() * TAU, Vector3.ONE, true, "Flagstone%02d" % k)
		if s:
			s.rotate_object_local(Vector3.FORWARD, PI / 2 + rng.randf_range(-0.15, 0.15))
			s.global_position.y = FLOOR_Y + 0.15
			KIT.override_material(s, stone)
			s.add_to_group("wettable")
	# Waterweed (fern assets, gentle sway) on the hall floor.
	for k in 18:
		var p := Vector3(rng.randf_range(-21, 19), FLOOR_Y, rng.randf_range(-9, 23))
		var f := KIT.place(root, "res://assets/models/jungle/lod/jun_fern_cluster_low_LOD0.glb", p, rng.randf_range(0.6, 1.2), rng.randf() * TAU, Vector3.ONE, true, "Weed%02d" % k)
		if f:
			f.set_meta("collision", "none")
			KIT.sway(f, 1.0, FLOOR_Y, "fern")
	# Caustic-ish cool light under the surface.
	KIT.omni(root, Vector3(-4, FLOOR_Y + 1.5, 10), Color(0.35, 0.7, 0.8), 1.4, 14.0)

func _discoveries() -> void:
	var d := Node3D.new()
	d.name = "Discoveries"
	add_child(d)
	KIT.collectible(d, "c06_diver_slate", "document", "Meridian Dive Slate",
		"Grease-pencil notes on a diver's slate:\n'Turbine = drain. DO NOT open before Drake's signal. East cistern floods from below - valve on the floor. Ledge tablet too heavy, left it.'",
		Vector3(6.5, FLOOR_Y + 0.25, 14.0), 0.5)
	KIT.collectible(d, "c06_tablet_waterline", "tablet", "Tablet of the Waterline",
		"Vaelor glyphs: 'We raised the halls by water and lowered them by water. The one who listens to the wheel may pass dry.'\n\nThe drain mechanism was a gate all along.",
		CISTERN + Vector3(4.6, 8.2, 0.8), -PI / 2)

func _lighting(level: Node3D) -> void:
	var env_node := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.3, 0.38, 0.42)
		env.ambient_light_energy = 1.7
		env.fog_light_color = Color(0.08, 0.14, 0.17)
		env.fog_density = 0.008
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env_node.environment = env
	var sky := level.get_node_or_null("AqueductSkylight") as DirectionalLight3D
	if sky:
		# A hall-wide sun through the broken vault lit ragged pale patches on the walls
		# (read as white specks). Keep it as a faint cool fill; the shaft spot below carries it.
		sky.shadow_enabled = true
		sky.shadow_blur = 3.0
		sky.light_energy = 0.3
		var shaft_light := SpotLight3D.new()
		shaft_light.name = "ShaftSpot"
		shaft_light.light_color = Color(0.7, 0.85, 0.95)
		shaft_light.light_energy = 4.0
		shaft_light.spot_range = 22.0
		shaft_light.spot_angle = 16.0
		shaft_light.spot_attenuation = 0.6
		add_child(shaft_light)
		shaft_light.global_position = Vector3(3, 13.5, 10.0)
		shaft_light.look_at(Vector3(3, 0, 6.5))
	# Expedition work lights and wall torches (warm) + Vaelor glyph glow (cool) so walls read.
	var bracket := KIT.std_mat(Color(0.25, 0.2, 0.15), 0.6, 0.5)
	var fire := KIT.std_mat(Color(1, 0.6, 0.25), 0.3, 0.0, Color(1.0, 0.55, 0.2), 4.0)
	var cup := CylinderMesh.new()
	cup.top_radius = 0.18
	cup.bottom_radius = 0.08
	cup.height = 0.3
	var flame := SphereMesh.new()
	flame.radius = 0.14
	flame.height = 0.4
	var torches := [Vector3(-23.6, 3.2, 16), Vector3(-23.6, 3.2, -1), Vector3(21.6, 3.2, 16), Vector3(21.6, 3.2, -6), Vector3(-9, 3.2, 24.6), Vector3(9, 3.2, 24.6), Vector3(-5, 3.2, -11.6), Vector3(5, 3.2, -11.6)]
	for p in torches:
		KIT.mesh(self, cup, Transform3D(Basis(), p), bracket).set_meta("collision", "none")
		KIT.mesh(self, flame, Transform3D(Basis(), p + Vector3(0, 0.25, 0)), fire).set_meta("collision", "none")
		var l := KIT.omni(self, p + Vector3(0, 0.6, 0) + (Vector3(-p.x, 0, 0).normalized() * 0.6 if absf(p.x) > 20 else Vector3(0, 0, -signf(p.z) * 0.6)), Color(1.0, 0.62, 0.32), 2.2, 13.0)
		_torches.append(l)
	var glyph := KIT.std_mat(Color(0.2, 0.5, 0.55), 0.4, 0.0, Color(0.3, 0.9, 1.0), 2.5)
	var strip := BoxMesh.new()
	strip.size = Vector3(0.05, 0.25, 5.0)
	for p in [Vector3(-24.0, 6.5, 8), Vector3(22.0, 6.5, 8)]:
		KIT.mesh(self, strip, Transform3D(Basis(), p), glyph, "VaelorGlyphBand").set_meta("collision", "none")
		KIT.omni(self, p + Vector3(-signf(p.x) * 1.5, 0, 0), Color(0.35, 0.85, 1.0), 1.6, 14.0)
	# Expedition floodlight aimed at the sanctum gate.
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.93, 0.8)
	spot.light_energy = 3.0
	spot.spot_range = 40.0
	spot.spot_angle = 30.0
	add_child(spot)
	spot.global_position = Vector3(0, 4.5, 22.0)
	spot.look_at(Vector3(0, 0, -12))
func hook_audio(p_sc: Node) -> void:
	sc = p_sc
	if sc == null:
		return
	sc.add_emitter("res://audio/ambience/temple/AMB_DROWNED_TEMPLE.wav", Vector3(0, 2, 6), 0.0, 40.0)
	sc.add_emitter("res://audio/ambience/cave/AMB_PRO_CAVE_WATER.ogg", Vector3(-22, 0, 10), -3.0, 25.0)
	sc.add_reverb_zone(Vector3(-1, 4, 6), Vector3(48, 16, 40), "temple")
	sc.add_reverb_zone(CISTERN + Vector3(0, 5, 0), Vector3(12, 12, 12), "cave")
	sc.add_reverb_zone(Vector3(0, 0, -25), Vector3(10, 8, 24), "tunnel")
	if basin and basin.has_signal("body_entered_water"):
		pass

var _uw := false
var _torches: Array[OmniLight3D] = []
var _tt := 0.0

func _physics_process(_d: float) -> void:
	if sc == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and "underwater" in player and bool(player.underwater) != _uw:
		_uw = bool(player.underwater)
		sc.set_underwater(_uw)

# ------------------------------------------------------------------ phase-2 hero assets
const H6 := "res://assets/models/hero/ch6/lod/"
var waterwheel: Node3D

func _hero_props() -> void:
	var root := Node3D.new()
	root.name = "TempleHeroProps"
	add_child(root)
	# Guardian statue: the hall's landmark, half-submerged, facing the entrance.
	var statue := KIT.place(root, H6 + "ch6_drowned_temple_statue_LOD0.glb", Vector3(9.0, FLOOR_Y, -6.5), 8.0, -0.6, Vector3.ONE, true, "GuardianStatue")
	if statue:
		statue.set_meta("collision", "convex")
		statue.add_to_group("wettable")
	# Great hydraulic waterwheel driving the drain (spins up when the turbine is turned).
	var pivot := Node3D.new()
	pivot.name = "GreatWaterwheel"
	root.add_child(pivot)
	pivot.global_position = Vector3(-20.5, FLOOR_Y + 4.7, 13.0)
	var wheel := KIT.place(pivot, H6 + "ch6_great_hydraulic_wheel_LOD0.glb", Vector3.ZERO, 9.4, 0.0, Vector3.ONE, true, "Wheel")
	if wheel:
		wheel.position.y -= 4.7 # centre the wheel on the pivot (bottom-fit placement)
		wheel.set_meta("collision", "none")
		wheel.add_to_group("wettable")
		waterwheel = pivot
	KIT.box_body(root, Vector3(-20.5, FLOOR_Y + 4.7, 13.0), Vector3(2.0, 9.0, 9.0), 0.0, "WaterwheelBody")
	# Sunken aqueduct arches along the east side of the hall.
	for z in [15.0, 4.5]:
		var aq := KIT.place(root, H6 + "ch6_sunken_aqueduct_arches_LOD0.glb", Vector3(19.0, FLOOR_Y, z), 10.0, 0.0, Vector3.ONE, false, "Aqueduct%d" % int(z))
		if aq:
			aq.set_meta("collision", "trimesh")
			aq.add_to_group("wettable")