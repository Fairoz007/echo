extends Node3D
## Chapter 1 "The Arrival": jungle valley terrain, expedition camp, Eastern Ridge ascent,
## waterfall gorge, secondary western ledge route, optional discoveries.
## Built at runtime from Chapter1.gd so the authored gameplay nodes keep their paths.

const KIT := preload("res://systems/levelb/LBKit.gd")
const TERRAIN := preload("res://systems/levelb/LBTerrain.gd")
const TREE := "res://assets/environment/jungle/jungle_tree.glb"
const FERN := "res://assets/environment/jungle/jungle_fern.glb"
const BOULDER := "res://assets/models/optimized/env_boulder_moss_LOD0.glb"
const CLIFF := "res://assets/environment/cave/cave_wall_limestone.glb"
const TENT := "res://assets/models/optimized/prop_expedition_tent_LOD0.glb"
const CRATE := "res://assets/models/optimized/prop_meridian_crate_LOD0.glb"
const RADIO := "res://assets/models/optimized/prop_expedition_radio_station_LOD0.glb"
const PILLAR := "res://assets/models/optimized/ruin_pillar_vaelor_LOD0.glb"
const PICK := "res://assets/props/equipment/climbing_pick.glb"
const J := "res://assets/models/jungle/lod/"
## [path, target metres] (sizes per TRIPO_DELIVERY_REPORT phase-2 table)
const JUN_TREES := [[J + "jun_kapok_tree_buttress_LOD0.glb", 18.0], [J + "jun_strangler_fig_tree_LOD0.glb", 14.0], [J + "jun_leaning_palm_cluster_LOD0.glb", 10.0], [J + "jun_mossy_dead_tree_LOD0.glb", 7.0], [TREE, 13.0]]
const JUN_FERNS := [[J + "jun_fern_cluster_tree_fern_LOD0.glb", 3.0], [J + "jun_fern_cluster_low_LOD0.glb", 1.5]]
const JUN_BOULDERS := [[J + "jun_boulder_cluster_mossy_a_LOD0.glb", 4.0], [J + "jun_boulder_cluster_split_b_LOD0.glb", 5.0], [J + "jun_boulder_ruin_mix_c_LOD0.glb", 5.0], [BOULDER, 2.5]]
## [path, size, fit_height]
const JUN_ROOTS := [[J + "jun_giant_surface_roots_a_LOD0.glb", 6.0, false], [J + "jun_root_arch_over_stone_LOD0.glb", 4.0, false], [J + "jun_hanging_root_curtain_LOD0.glb", 5.0, true]]
const H1 := "res://assets/models/hero/ch1/lod/"
const RIDGE_Y := 6.0
const WATERFALL_POS := Vector3(46, 0, -40)

var terrain: TERRAIN
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
## Corridors: [from, to, half_width, height_from, height_to, path_paint]
var corridors := []

func _init() -> void:
	name = "LevelBDressing"

func build(level: Node3D) -> void:
	rng.seed = 1101
	noise.seed = 77
	noise.frequency = 0.018
	noise.fractal_octaves = 4
	detail.seed = 91
	detail.frequency = 0.09
	corridors = [
		# Main route: camp -> Eastern Ridge portal (kept straight around x=0 for the beaten track).
		[Vector2(0, 34), Vector2(0, 14), 6.0, 0.0, 0.0, 1.0],
		[Vector2(0, 14), Vector2(1.5, -12), 3.2, 0.0, 0.6, 1.0],
		[Vector2(1.5, -12), Vector2(-1.0, -40), 3.2, 0.6, 5.2, 1.0],
		[Vector2(-1.0, -40), Vector2(0, -58), 3.4, 5.2, RIDGE_Y, 1.0],
		# Secondary route: western ledges past the old survey cairn (exploration room at -36,-10).
		[Vector2(-10, 4), Vector2(-24, -6), 2.4, 0.0, 0.0, 0.8],
		[Vector2(-24, -6), Vector2(-30, -26), 2.2, 0.0, 2.8, 0.7],
		[Vector2(-30, -26), Vector2(-18, -48), 2.2, 2.8, RIDGE_Y, 0.7],
		[Vector2(-24, -6), Vector2(-33, -10), 2.6, 0.0, 0.0, 0.6],
		# East spur: camp -> waterfall gorge (exploration room at 36,-10).
		[Vector2(9, 6), Vector2(33, -9), 2.6, 0.0, 0.0, 0.8],
		[Vector2(33, -9), Vector2(41, -30), 2.4, 0.0, 0.0, 0.6],
		# South spur to the third exploration room (30, 36).
		[Vector2(8, 18), Vector2(27, 33), 2.4, 0.0, 0.0, 0.6],
	]
	_disable_blockout_floor(level)
	terrain = TERRAIN.new()
	terrain.name = "JungleTerrain"
	add_child(terrain)
	terrain.build(Vector2(-110, -130), Vector2(220, 220), 1.6, _height, _mask)
	terrain.material.set_shader_parameter("path_grit", 1.0)
	_lift_ridge(level)
	_cliffs()
	_camp(level)
	_vegetation()
	_waterfall_gorge()
	_secondary_route()
	_discoveries()
	_sky(level)
	_path_no_grass()
	var grass := preload("res://systems/nature/GrassScatter.tscn").instantiate()
	grass.name = "GrassScatter"
	grass.set("area_size", Vector2(120, 130))
	grass.set("density", 2.2)
	grass.set("max_slope_deg", 30.0)
	grass.set("visibility_end", 40.0)
	grass.set("ray_height", 40.0)
	grass.set("ray_depth", 60.0)
	add_child(grass)
	grass.position = Vector3(0, 0, -15)
	_brighten_grass(grass)
	WindSystem.set_wind(Vector2(0.8, -0.6), 0.7, 0.6, 0.3)


# ---------------------------------------------------------------- terrain

func _seg(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	## returns (distance, t)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)

func _height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var ridge_base := RIDGE_Y * smoothstep(-6.0, -50.0, z)
	# Natural valley: rises away from the centre line, high walls toward the north cliff.
	var d_centre := absf(x) - 14.0
	var hill := smoothstep(0.0, 40.0, d_centre) * (9.0 + 12.0 * n)
	var h := ridge_base + hill + n * 1.6 + detail.get_noise_2d(x, z) * 0.35
	# Sheer ridge wall behind the portal.
	var wall := smoothstep(-64.0, -74.0, z + noise.get_noise_2d(x * 2.0, 0) * 3.0)
	h = maxf(h, RIDGE_Y + wall * (22.0 + 10.0 * n))
	# Ridge plateau.
	var plateau := (1.0 - smoothstep(16.0, 26.0, absf(x))) * smoothstep(-44.0, -50.0, z) * (1.0 - smoothstep(-66.0, -70.0, z))
	h = lerpf(h, RIDGE_Y + detail.get_noise_2d(x, z) * 0.15, plateau)
	# Camp clearing.
	var camp := 1.0 - smoothstep(0.75, 1.15, Vector2(x / 19.0, (z - 7.0) / 15.0).length())
	h = lerpf(h, detail.get_noise_2d(x, z) * 0.08, camp)
	# Exploration rooms (CampaignExploration) need flat ground at y=0.
	for room in [Vector2(-36, -10), Vector2(36, -10), Vector2(30, 36)]:
		var w := 1.0 - smoothstep(8.0, 13.0, p.distance_to(room))
		h = lerpf(h, 0.0, w)
	# Corridors.
	for c in corridors:
		var r := _seg(p, c[0], c[1])
		var w := 1.0 - smoothstep(c[2], c[2] + 5.0, r.x)
		var ch := lerpf(c[3], c[4], r.y) + detail.get_noise_2d(x, z) * 0.12
		h = lerpf(h, ch, w)
	# Waterfall gorge: cliff behind the fall, basin, and stream channel south of it.
	var wf := Vector2(WATERFALL_POS.x, WATERFALL_POS.z)
	var gorge_w := 1.0 - smoothstep(8.0, 16.0, absf(x - wf.x))
	if z < wf.y - 1.0:
		h = maxf(h, lerpf(h, 10.5 + n * 3.0, gorge_w * smoothstep(wf.y - 1.0, wf.y - 3.0, z)))
	var basin_d := p.distance_to(wf + Vector2(0, 3.0))
	h = lerpf(h, -2.2, 1.0 - smoothstep(3.6, 6.0, basin_d))
	var stream := _seg(p, wf + Vector2(0, 6.0), wf + Vector2(0, 22.0))
	h = minf(h, lerpf(h, -1.1, 1.0 - smoothstep(1.8, 3.2, stream.x)))
	return maxf(h, -2.4)

func _mask(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var path := 0.0
	for c in corridors:
		var r := _seg(p, c[0], c[1])
		path = maxf(path, (1.0 - smoothstep(c[2] * 0.35, c[2] * 0.9, r.x)) * c[5])
	var camp := 1.0 - smoothstep(0.35, 0.8, Vector2(x / 19.0, (z - 7.0) / 15.0).length())
	path = maxf(path, camp * 0.75)
	var wf := Vector2(WATERFALL_POS.x, WATERFALL_POS.z)
	var wet := 1.0 - smoothstep(4.0, 9.0, p.distance_to(wf + Vector2(0, 3)))
	wet = maxf(wet, 1.0 - smoothstep(2.5, 4.5, _seg(p, wf + Vector2(0, 6.0), wf + Vector2(0, 22.0)).x))
	var litter := clampf(noise.get_noise_2d(x * 3.0, z * 3.0) + 0.3, 0.0, 1.0)
	return Color(path, 0.0, wet * 0.8, litter)

func _disable_blockout_floor(level: Node3D) -> void:
	var floor_body := level.get_node_or_null("ValleyTerrain/Floor")
	if floor_body:
		for c in floor_body.get_children():
			if c is CollisionShape3D:
				c.disabled = true
			elif c is GeometryInstance3D:
				c.visible = false

func _lift_ridge(level: Node3D) -> void:
	var ridge := level.get_node_or_null("RidgeArea") as Node3D
	if ridge == null:
		return
	ridge.position.y = RIDGE_Y
	# Old trail boulders: settle them onto the new slope instead of floating/sinking.
	var boulders := ridge.get_node_or_null("TrailBoulders")
	if boulders:
		for b in boulders.get_children():
			var g: Vector3 = b.global_position
			b.global_position.y = terrain.height_at(g.x, g.z) - 0.4
	var rock := KIT.rock_material(Color(0.5, 0.49, 0.44), 0.85)
	if boulders:
		for b in boulders.get_children():
			KIT.override_material(b, rock)
	# The sealed portal is the chapter landmark: monumental scale, facing the trail.
	var portal := ridge.get_node_or_null("ArchPortal3D") as Node3D
	if portal:
		var pb := KIT.model_bounds(portal.scene_file_path)
		var pbasis := Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 8.0)
		var pc := pb.get_center()
		portal.transform = Transform3D(pbasis, Vector3(0, -0.3, -13.4) - pbasis * Vector3(pc.x, pb.position.y, pc.z))
		portal.set_meta("collision", "trimesh")
		# Phase-2 hero portal replaces the generic arch when delivered.
		if ResourceLoader.exists(H1 + "ch1_first_sealed_portal_LOD0.glb"):
			portal.visible = false
			portal.set_meta("collision", "none")
			var hero := KIT.place(ridge, H1 + "ch1_first_sealed_portal_LOD0.glb", Vector3(0, -0.3, -15.4), 10.0, PI / 2, Vector3.ONE, true, "HeroSealedPortal")
			if hero:
				hero.set_meta("collision", "trimesh")
	var cliff := ridge.get_node_or_null("CliffWall")
	if cliff:
		cliff.queue_free()

# ---------------------------------------------------------------- ridge cliff (P1 fix)

func _cliffs() -> void:
	var root := Node3D.new()
	root.name = "RidgeCliffs"
	add_child(root)
	var mat := KIT.rock_material(Color(0.47, 0.46, 0.41), 0.8)
	# Irregular cliff massing along a curved, staggered line; varied yaw/scale/depth/sink
	# so no two neighbours read as the same wall piece.
	var x := -60.0
	var i := 0
	while x < 60.0:
		var curve := -71.0 - 4.0 * cos(x * 0.045) + rng.randf_range(-3.5, 3.5)
		if absf(x) < 10.0:
			# Leave the carved portal face open; frame it with two closer buttresses.
			curve = -67.5 + rng.randf_range(-0.5, 0.5)
			x = -10.5 if x < 0.0 else 10.5
		var height := rng.randf_range(16.0, 30.0)
		var stretch := Vector3(rng.randf_range(0.7, 1.4), 1.0, rng.randf_range(0.8, 1.6))
		var ground_y := terrain.height_at(x, curve) - rng.randf_range(2.0, 5.0)
		var piece := KIT.place(root, CLIFF, Vector3(x, ground_y, curve), height, rng.randf_range(-0.6, 0.6) + (PI if i % 3 == 0 else 0.0), stretch, true, "Cliff%02d" % i)
		if piece:
			KIT.override_material(piece, mat)
			piece.set_meta("collision", "trimesh")
		x += rng.randf_range(7.0, 12.0)
		i += 1
	# Talus boulders at the cliff foot, clustered (not in a row).
	for k in 26:
		var bx := rng.randf_range(-48.0, 48.0)
		if absf(bx) < 6.0:
			continue
		var bz := rng.randf_range(-66.0, -60.0) - absf(bx) * 0.05
		var size := rng.randf_range(1.2, 4.2)
		var b := KIT.place(root, BOULDER, Vector3(bx, terrain.height_at(bx, bz) - size * 0.25, bz), size, rng.randf() * TAU, Vector3(rng.randf_range(0.8, 1.3), 1.0, rng.randf_range(0.8, 1.3)), true, "Talus%02d" % k)
		if b:
			KIT.override_material(b, mat)
	# Carved Vaelor pillars flanking the sealed portal: the landmark reads from camp.
	for side in [-1.0, 1.0]:
		var px: float = side * 8.6
		var pil := KIT.place(root, PILLAR, Vector3(px, RIDGE_Y - 0.2, -63.0), 7.5, side * 0.2, Vector3.ONE, true, "PortalPillar" + ("L" if side < 0 else "R"))
	KIT.omni(root, Vector3(0, RIDGE_Y + 4.0, -58.0), Color(1.0, 0.82, 0.6), 1.2, 12.0)

# ---------------------------------------------------------------- camp

func _camp(level: Node3D) -> void:
	var camp := Node3D.new()
	camp.name = "CampDressing"
	add_child(camp)
	# Additional tents arranged around the fire, facing the centre.
	var tents := [[Vector3(-10, 0, 12), 0.9], [Vector3(10.5, 0, 13), -0.8], [Vector3(-11, 0, 1), 1.9], [Vector3(12, 0, 0), -1.7]]
	for t in tents.size():
		var tpos: Vector3 = tents[t][0]
		KIT.place(camp, TENT, Vector3(tpos.x, terrain.height_at(tpos.x, tpos.z), tpos.z), 2.6, tents[t][1], Vector3.ONE, true, "CampTent%d" % t)
	# Phase-2 hero camp pieces: command tent hub behind the survey table, supply truck.
	var hub := KIT.place(camp, H1 + "ch1_expedition_command_tent_LOD0.glb", Vector3(-10.5, 0, -5.5), 7.5, PI * 0.8, Vector3.ONE, false, "CommandTentHub")
	var truck := KIT.place(camp, H1 + "ch1_expedition_supply_truck_LOD0.glb", Vector3(14.5, 0, 9.0), 5.6, 2.3, Vector3.ONE, false, "SupplyTruck")
	if truck:
		truck.set_meta("collision", "convex")
	# Canopy over the survey/command area (poles + tarp).
	var canopy_mat := KIT.std_mat(Color(0.33, 0.36, 0.26), 0.85)
	var pole_mat := KIT.std_mat(Color(0.25, 0.25, 0.24), 0.5, 0.6)
	var tarp := BoxMesh.new()
	tarp.size = Vector3(7.0, 0.04, 5.0)
	KIT.mesh(camp, tarp, Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0.3, 3.0, 5.2)), canopy_mat, "CommandTarp")
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.05
	pole.height = 3.1
	for c in [Vector3(-3.1, 1.5, 3.0), Vector3(3.7, 1.5, 3.0), Vector3(-3.1, 1.4, 7.4), Vector3(3.7, 1.4, 7.4)]:
		KIT.mesh(camp, pole, Transform3D(Basis(), c), pole_mat)
	# Campfire ring with flicker light and logs.
	var fire_pos := Vector3(-1.5, 0, 13.5)
	var stone_mat := KIT.rock_material(Color(0.45, 0.44, 0.42), 0.1)
	for s in 9:
		var a := TAU * s / 9.0
		var st := SphereMesh.new()
		st.radius = rng.randf_range(0.16, 0.22)
		st.height = st.radius * 1.4
		KIT.mesh(camp, st, Transform3D(Basis(Vector3.UP, a), fire_pos + Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75)), stone_mat).set_meta("collision", "none")
	var log_mat := KIT.std_mat(Color(0.22, 0.15, 0.1), 0.95)
	var lg := CylinderMesh.new()
	lg.top_radius = 0.18
	lg.bottom_radius = 0.2
	lg.height = 1.9
	for l in [[Vector3(-3.6, 0.2, 13.0), 1.3], [Vector3(0.6, 0.2, 15.6), 0.2], [Vector3(-2.2, 0.2, 16.2), 1.75]]:
		KIT.mesh(camp, lg, Transform3D(Basis(Vector3.UP, l[1]) * Basis(Vector3.FORWARD, PI / 2), l[0]), log_mat, "SeatLog")
		KIT.box_body(camp, l[0], Vector3(1.9, 0.4, 0.4), l[1], "SeatLogBody")
	var ember := SphereMesh.new()
	ember.radius = 0.35
	ember.height = 0.25
	KIT.mesh(camp, ember, Transform3D(Basis(), fire_pos + Vector3(0, 0.05, 0)), KIT.std_mat(Color(0.2, 0.08, 0.02), 0.9, 0.0, Color(1.0, 0.38, 0.08), 3.0), "Embers")
	var fire_light := KIT.omni(camp, fire_pos + Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.25), 1.8, 9.0)
	fire_light.set_meta("flicker", true)
	_flicker_lights.append(fire_light)
	var smoke := GPUParticles3D.new()
	smoke.name = "CampfireSmoke"
	smoke.amount = 24
	smoke.lifetime = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.15, 0.1, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	smoke.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.albedo_color = Color(0.6, 0.6, 0.6, 0.18)
	quad.material = smat
	smoke.draw_pass_1 = quad
	camp.add_child(smoke)
	smoke.global_position = fire_pos + Vector3(0, 0.4, 0)
	# Nadiya's comms station: radio + antenna mast + crates.
	KIT.place(camp, RADIO, Vector3(-4.2, 0, 9.6), 1.1, 0.6, Vector3.ONE, true, "CommsRadio")
	var mast := CylinderMesh.new()
	mast.top_radius = 0.02
	mast.bottom_radius = 0.035
	mast.height = 6.0
	KIT.mesh(camp, mast, Transform3D(Basis(), Vector3(-5.2, 3.0, 10.4)), pole_mat, "AntennaMast")
	KIT.box_body(camp, Vector3(-5.2, 3.0, 10.4), Vector3(0.12, 6.0, 0.12), 0.0, "MastBody")
	var light_tip := KIT.omni(camp, Vector3(-5.2, 6.1, 10.4), Color(1, 0.2, 0.15), 0.6, 2.5)
	light_tip.set_meta("blink", true)
	_flicker_lights.append(light_tip)
	# Tomas's equipment bench: crates stacked with gear on top.
	var bench := Vector3(5.6, 0, 9.4)
	KIT.place(camp, CRATE, bench, 0.8, 0.3, Vector3(1.6, 1.0, 1.0), true, "BenchCrateA")
	KIT.place(camp, CRATE, bench + Vector3(1.6, 0, -0.5), 0.7, -0.2, Vector3.ONE, true, "BenchCrateB")
	KIT.place(camp, CRATE, bench + Vector3(1.6, 0.7, -0.5), 0.55, 0.5, Vector3.ONE, true, "BenchCrateC")
	KIT.place(camp, PICK, bench + Vector3(0, 0.8, 0), 0.38, 1.2, Vector3.ONE, false, "BenchPick")
	# Generator + fuel cans (procedural; small).
	var gen_mat := KIT.std_mat(Color(0.55, 0.42, 0.12), 0.55, 0.3)
	var gen := BoxMesh.new()
	gen.size = Vector3(0.9, 0.6, 0.6)
	KIT.mesh(camp, gen, Transform3D(Basis(Vector3.UP, 0.4), Vector3(8.5, 0.3, 5.5)), gen_mat, "Generator")
	KIT.box_body(camp, Vector3(8.5, 0.3, 5.5), Vector3(0.9, 0.6, 0.6), 0.4, "GeneratorBody")
	var can := BoxMesh.new()
	can.size = Vector3(0.18, 0.45, 0.32)
	for k in 3:
		KIT.mesh(camp, can, Transform3D(Basis(Vector3.UP, k * 0.3), Vector3(9.3 + k * 0.22, 0.225, 6.2)), KIT.std_mat(Color(0.12, 0.28, 0.12), 0.6, 0.2))
	# Camp lanterns: timber post, crossarm and a hurricane lantern hanging from a hook.
	var wood := KIT.std_mat(Color(0.3, 0.22, 0.14), 0.9)
	var post := BoxMesh.new()
	post.size = Vector3(0.1, 2.4, 0.1)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.55, 0.07, 0.07)
	var glass := CylinderMesh.new()
	glass.top_radius = 0.07
	glass.bottom_radius = 0.08
	glass.height = 0.2
	var lcap := CylinderMesh.new()
	lcap.top_radius = 0.03
	lcap.bottom_radius = 0.1
	lcap.height = 0.07
	var base_m := CylinderMesh.new()
	base_m.top_radius = 0.09
	base_m.bottom_radius = 0.09
	base_m.height = 0.04
	var tin := KIT.std_mat(Color(0.16, 0.17, 0.15), 0.5, 0.7)
	var flame := KIT.std_mat(Color(0.95, 0.62, 0.3), 0.2, 0.0, Color(1.0, 0.55, 0.2), 1.1)
	var hook := CylinderMesh.new()
	hook.top_radius = 0.008
	hook.bottom_radius = 0.008
	hook.height = 0.12
	for lp in [Vector3(-7, 0, 6), Vector3(7, 0, 4), Vector3(-3.5, 0, 19)]:
		KIT.mesh(camp, post, Transform3D(Basis(), lp + Vector3(0, 1.2, 0)), wood, "LanternPost")
		KIT.mesh(camp, arm, Transform3D(Basis(), lp + Vector3(0.25, 2.3, 0)), wood).set_meta("collision", "none")
		var hang: Vector3 = lp + Vector3(0.45, 2.05, 0)
		KIT.mesh(camp, lcap, Transform3D(Basis(), hang + Vector3(0, 0.14, 0)), tin).set_meta("collision", "none")
		KIT.mesh(camp, hook, Transform3D(Basis(), hang + Vector3(0, 0.235, 0)), tin).set_meta("collision", "none")
		KIT.mesh(camp, glass, Transform3D(Basis(), hang), flame, "LanternGlass").set_meta("collision", "none")
		KIT.mesh(camp, base_m, Transform3D(Basis(), hang + Vector3(0, -0.12, 0)), tin).set_meta("collision", "none")
		KIT.omni(camp, hang, Color(1.0, 0.72, 0.42), 0.9, 7.0)
	# The survey desk sits inside the SurveyTable interaction body (legacy layout, no collision).
	var desk := level.get_node_or_null("CampArea/SurveyTable/SurveyDeskModel")
	if desk:
		desk.set_meta("collision", "none")
	# NPC staging: everyone idles at a station, facing what they work on.
	var elias := level.get_node_or_null("CampArea/EliasNPC") as Node3D
	if elias:
		elias.rotation.y = -PI / 2.0 + 0.3 # leaning over the survey table
	var nadiya := level.get_node_or_null("CampArea/NadiyaNPC") as Node3D
	if nadiya:
		nadiya.rotation.y = 2.4 # toward the radio
	var tomas := level.get_node_or_null("CampArea/TomasPresentation") as Node3D
	if tomas:
		tomas.position = Vector3(4.3, 0, 4.6)
		tomas.rotation.y = 0.9 # at the gear bench
	var adrian := level.get_node_or_null("CampArea/AdrianPresentation") as Node3D
	if adrian:
		adrian.position = Vector3(-4.8, 0, -3.2)
		adrian.rotation.y = -2.6 # alone at the tent, glancing toward the ridge
	var tomas_body := StaticBody3D.new()
	tomas_body.name = "TomasBlocker"
	tomas_body.collision_layer = 2
	camp.add_child(tomas_body)
	tomas_body.global_position = Vector3(4.3, 0.9, 9.6)
	var cap := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.8
	cap.shape = cs
	tomas_body.add_child(cap)
	var tomas_talk := KIT.interaction(tomas_body, Vector3.ZERO, Vector3(2, 2, 2), "[E] Talk to Tomas")
	tomas_talk.interacted.connect(func(_p): AudioManager.play_story_line("Tomas", "Ropes, anchors, spare batteries. If the ridge wants to fight, we're ready.", 4.0))

var _flicker_lights: Array[OmniLight3D] = []
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	for l in _flicker_lights:
		if l.has_meta("blink"):
			l.visible = fmod(_t, 1.6) < 0.25
		else:
			l.light_energy = 1.6 + sin(_t * 13.0) * 0.18 + sin(_t * 7.3) * 0.22

# ---------------------------------------------------------------- vegetation

func _near_route(p: Vector2, margin: float) -> bool:
	for c in corridors:
		if _seg(p, c[0], c[1]).x < c[2] + margin:
			return true
	if Vector2(p.x / 20.0, (p.y - 7.0) / 16.0).length() < 1.0:
		return true
	for room in [Vector2(-36, -10), Vector2(36, -10), Vector2(30, 36)]:
		if p.distance_to(room) < 10.0:
			return true
	if p.distance_to(Vector2(WATERFALL_POS.x, WATERFALL_POS.z + 3)) < 8.0:
		return true
	if absf(p.x - WATERFALL_POS.x) < 4.0 and p.y > WATERFALL_POS.z and p.y < WATERFALL_POS.z + 24:
		return true
	return p.y < -64.0

func _vegetation() -> void:
	var root := Node3D.new()
	root.name = "Jungle"
	add_child(root)
	var cluster_noise := FastNoiseLite.new()
	cluster_noise.seed = 5
	cluster_noise.frequency = 0.05
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-70, 70), rng.randf_range(-62, 55))
		if cluster_noise.get_noise_2d(p.x, p.y) < -0.05 or _near_route(p, 3.5):
			continue
		var h := terrain.height_at(p.x, p.y)
		# Phase-2 jungle set (target sizes from the hand-off table) mixed with the original tree.
		var spec: Array = JUN_TREES[rng.randi() % JUN_TREES.size()]
		var tall: float = spec[1] * rng.randf_range(0.85, 1.12)
		var tree := KIT.place(root, spec[0], Vector3(p.x, h - 0.3, p.y), tall, rng.randf() * TAU, Vector3.ONE, true, "Tree%02d" % placed)
		if tree:
			tree.set_meta("collision", "trunk")
			for mi in tree.find_children("*", "GeometryInstance3D", true, false):
				(mi as GeometryInstance3D).visibility_range_end = 140.0
			KIT.sway(tree, tall, h, "tree")
		placed += 1
	var ferns := 0
	tries = 0
	while ferns < 150 and tries < 5000:
		tries += 1
		var p := Vector2(rng.randf_range(-55, 55), rng.randf_range(-62, 45))
		if _near_route(p, 0.8) and rng.randf() < 0.85:
			continue
		if cluster_noise.get_noise_2d(p.x * 1.5, p.y * 1.5) < -0.25:
			continue
		var h := terrain.height_at(p.x, p.y)
		var fspec: Array = JUN_FERNS[rng.randi() % JUN_FERNS.size()]
		var size: float = fspec[1] * rng.randf_range(0.7, 1.15)
		var fern := KIT.place(root, fspec[0], Vector3(p.x, h - 0.05, p.y), size, rng.randf() * TAU, Vector3.ONE, true, "Fern%03d" % ferns)
		if fern:
			fern.set_meta("collision", "none")
			for mi in fern.find_children("*", "GeometryInstance3D", true, false):
				(mi as GeometryInstance3D).visibility_range_end = 60.0
				(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			KIT.sway(fern, size, h, "fern")
		ferns += 1
	# Scattered mossy boulders in the undergrowth (clustered, varied).
	var mat := KIT.rock_material(Color(0.5, 0.5, 0.46), 0.85)
	for k in 30:
		var p := Vector2(rng.randf_range(-60, 60), rng.randf_range(-58, 50))
		if _near_route(p, 1.5):
			continue
		var bspec: Array = JUN_BOULDERS[k % JUN_BOULDERS.size()]
		var s: float = bspec[1] * rng.randf_range(0.5, 1.1)
		var b := KIT.place(root, bspec[0], Vector3(p.x, terrain.height_at(p.x, p.y) - 0.3, p.y), s, rng.randf() * TAU, Vector3.ONE, false, "Boulder%02d" % k)
		if b and bspec[0] == BOULDER:
			KIT.override_material(b, mat)
	# Giant surface roots and hanging root curtains at the bases of the big trees.
	for k in 14:
		var p := Vector2(rng.randf_range(-60, 60), rng.randf_range(-58, 50))
		if _near_route(p, 2.5):
			continue
		var rspec: Array = JUN_ROOTS[k % JUN_ROOTS.size()]
		var r := KIT.place(root, rspec[0], Vector3(p.x, terrain.height_at(p.x, p.y) - 0.2, p.y), rspec[1] * rng.randf_range(0.8, 1.1), rng.randf() * TAU, Vector3.ONE, rspec[2], "Roots%02d" % k)
		if r and rspec[0].contains("curtain"):
			r.set_meta("collision", "none")
			KIT.sway(r, rspec[1], terrain.height_at(p.x, p.y), "fern")

# ---------------------------------------------------------------- waterfall gorge

func _waterfall_gorge() -> void:
	var wf := preload("res://systems/water/Waterfall.tscn").instantiate()
	wf.name = "GorgeWaterfall"
	wf.set("fall_height", 10.0)
	wf.set("width", 3.2)
	wf.set("basin_size", Vector2(9, 8))
	wf.set("basin_depth", 2.2)
	wf.set("downstream_length", 14.0)
	wf.set("downstream_width", 3.6)
	wf.set("build_lip_rock", true)
	add_child(wf)
	wf.global_position = WATERFALL_POS + Vector3(0, -0.15, 0)
	var mat := KIT.rock_material(Color(0.42, 0.42, 0.4), 0.6)
	for k in 7:
		var side := -1.0 if k % 2 == 0 else 1.0
		var x := WATERFALL_POS.x + side * rng.randf_range(6.5, 10.0)
		var z := WATERFALL_POS.z - rng.randf_range(2.0, 4.5) + float(k / 2) * 3.0
		var r := KIT.place(self, CLIFF, Vector3(x, -2.0, z), rng.randf_range(11.0, 15.0), rng.randf_range(-0.4, 0.4), Vector3(0.6, 1.0, 0.8), true, "GorgeRock%d" % k)
		if r:
			KIT.override_material(r, mat)

# ---------------------------------------------------------------- secondary route

func _secondary_route() -> void:
	# Western ledges: a rope-and-plank crossing and stone steps from the survey cairn to the plateau.
	var root := Node3D.new()
	root.name = "WesternLedgeRoute"
	add_child(root)
	var plank_mat := KIT.std_mat(Color(0.36, 0.27, 0.18), 0.9)
	var plank := BoxMesh.new()
	plank.size = Vector3(1.6, 0.08, 0.32)
	var a := Vector3(-29.0, 0, -22.0)
	var b := Vector3(-27.0, 0, -32.0)
	a.y = terrain.height_at(a.x, a.z) + 0.1
	b.y = terrain.height_at(b.x, b.z) + 0.1
	var count := 22
	for k in count:
		var t := float(k) / (count - 1)
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * 0.35
		var yaw := atan2(b.x - a.x, b.z - a.z)
		KIT.mesh(root, plank, Transform3D(Basis(Vector3.UP, yaw + PI / 2 + rng.randf_range(-0.05, 0.05)), p), plank_mat)
	# Survey cairn landmark along the secondary route.
	var stone := KIT.rock_material(Color(0.52, 0.5, 0.46), 0.3)
	var base := Vector3(-24.5, terrain.height_at(-24.5, -7.5), -7.5)
	for k in 5:
		var s := SphereMesh.new()
		s.radius = 0.42 - k * 0.06
		s.height = s.radius * 1.3
		KIT.mesh(root, s, Transform3D(Basis(Vector3.UP, k), base + Vector3(rng.randf_range(-0.05, 0.05), 0.25 + k * 0.42, 0)), stone, "Cairn%d" % k).set_meta("collision", "none")
	KIT.box_body(root, base + Vector3(0, 1.2, 0), Vector3(0.9, 2.4, 0.9), 0.0, "CairnBody")
	var flag := BoxMesh.new()
	flag.size = Vector3(0.02, 0.3, 0.5)
	KIT.mesh(root, flag, Transform3D(Basis(), base + Vector3(0, 2.35, 0.25)), KIT.std_mat(Color(0.85, 0.35, 0.1), 0.7), "SurveyFlag")

# ---------------------------------------------------------------- optional discoveries

func _discoveries() -> void:
	var d := Node3D.new()
	d.name = "Discoveries"
	add_child(d)
	var cairn := Vector3(-24.0, terrain.height_at(-24.0, -6.5), -6.5)
	KIT.collectible(d, "c01_journal_father", "journal", "Field Journal, 1987 (R. Vale)",
		"\"The ridge sings at dusk. Not wind; the stone itself. Kell says I'm romanticising acoustics, but the survey cairns were placed by someone who heard it too.\"\n\nMara's father marked this cairn. The ink on the last page points east, toward the sealed cliff.",
		cairn + Vector3(0.9, 0.02, 0.2), 0.4)
	var wf := Vector3(WATERFALL_POS.x + 4.5, 0, WATERFALL_POS.z + 7.5)
	wf.y = terrain.height_at(wf.x, wf.z)
	KIT.collectible(d, "c01_tablet_gorge", "tablet", "Weathered Vaelor Tablet",
		"A palm-sized slab behind the falls, glyphs worn smooth by spray. Three rings, a downward arrow, and a symbol Elias calls 'the listening ear'.\n\nThe Vaelor built where water and stone meet.",
		wf, -0.6)

# ---------------------------------------------------------------- ambience hooks

func _ambience() -> void:
	var root := Node3D.new()
	root.name = "WildlifeAmbience"
	add_child(root)
	var stream := load("res://audio/ambience/jungle/AMB_JUNGLE_CANOPY.wav")
	var spots := [[Vector3(-25, 10, 10), "birds"], [Vector3(28, 10, 15), "birds"], [Vector3(-30, 4, -30), "insects"], [Vector3(20, 4, -35), "insects"], [Vector3(46, 2, -30), "frogs"], [Vector3(0, 12, -50), "birds"]]
	for i in spots.size():
		var a := AudioStreamPlayer3D.new()
		a.name = "Wildlife_%s_%d" % [spots[i][1], i]
		a.add_to_group("wildlife_ambience_hook")
		a.set_meta("kind", spots[i][1])
		a.stream = stream
		a.volume_db = -14.0
		a.unit_size = 14.0
		a.max_distance = 70.0
		a.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
		root.add_child(a)
		a.global_position = spots[i][0]
		if stream:
			a.autoplay = true
			a.play.call_deferred(rng.randf_range(0.0, 20.0))

# ---------------------------------------------------------------- sky / light

func _sky(level: Node3D) -> void:
	var env_node := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.36, 0.52, 0.66)
		sky_mat.sky_horizon_color = Color(0.72, 0.76, 0.74)
		sky_mat.ground_horizon_color = Color(0.42, 0.45, 0.4)
		sky_mat.ground_bottom_color = Color(0.18, 0.2, 0.16)
		sky_mat.sun_angle_max = 20.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.7
		env.fog_enabled = true
		env.fog_light_color = Color(0.68, 0.74, 0.72)
		env.fog_density = 0.0022
		env.fog_sky_affect = 0.12
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.0
		env_node.environment = env
	var sun := level.get_node_or_null("SunLight") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.93, 0.8)
		sun.light_energy = 1.25
		sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-35.0), 0)
		sun.directional_shadow_max_distance = 80.0
		sun.shadow_blur = 2.5
		sun.shadow_opacity = 0.72

func _brighten_grass(grass: Node) -> void:
	# The shared grass material reads near-black on back faces in the Compatibility
	# renderer; give this valley a lighter, sun-bleached tint (still wind-registered).
	# Build our own material (no dependence on scatter timing) and re-apply it to every
	# MultiMesh chunk the scatter creates now or later (it rescatters on quality changes).
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://systems/levelb/grass_lb.gdshader")
	mat.set_shader_parameter("base_color", Vector3(0.16, 0.26, 0.08))
	mat.set_shader_parameter("tip_color", Vector3(0.42, 0.58, 0.2))
	mat.set_shader_parameter("dry_tip_color", Vector3(0.62, 0.58, 0.3))
	WindSystem.register_material(mat)
	var apply := func(c: Node) -> void:
		if c is MultiMeshInstance3D:
			(c as MultiMeshInstance3D).set_deferred("material_override", mat)
	grass.child_entered_tree.connect(apply)
	for c in grass.find_children("*", "MultiMeshInstance3D", true, false):
		apply.call(c)

func _path_no_grass() -> void:
	# Invisible strips on a non-gameplay layer (bit 20) keep grass off the beaten tracks.
	var root := Node3D.new()
	root.name = "PathGrassMask"
	add_child(root)
	for c in corridors:
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		var segs := int(ceil(a.distance_to(b) / 3.0))
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			var mid := (p0 + p1) * 0.5
			var y := terrain.height_at(mid.x, mid.y) + 0.06
			var body := KIT.box_body(root, Vector3(mid.x, y, mid.y), Vector3(c[2] * 1.3, 0.05, p0.distance_to(p1) + 0.4), atan2(b.x - a.x, b.y - a.y), "NoGrass", 1 << 19)
			body.add_to_group("no_grass")
	var camp := KIT.box_body(root, Vector3(0, 0.06, 7), Vector3(30, 0.05, 22), 0.0, "NoGrassCamp", 1 << 19)
	camp.add_to_group("no_grass")

## Called by Chapter1.gd after CampaignDialogue created the chapter Soundscape.
func hook_audio(sc: Node) -> void:
	if sc == null:
		return
	var birds := "res://audio/ambience/jungle/AMB_JUNGLE_BIRDS_INSECTS.ogg"
	var spots := [[Vector3(-25, 10, 10), "birds"], [Vector3(28, 10, 15), "birds"], [Vector3(-30, 4, -30), "insects"], [Vector3(20, 4, -35), "insects"], [Vector3(0, 12, -50), "birds"]]
	for s in spots:
		var e: Node = sc.add_emitter(birds, s[0], -6.0, 45.0)
		if e:
			e.add_to_group("wildlife_ambience_hook")
			e.set_meta("kind", s[1])
	sc.add_emitter("res://audio/ambience/lost_city/AMB_WATERFALL_RESONANT_LOOP.ogg", WATERFALL_POS + Vector3(0, 3, 2), 0.0, 40.0)
	sc.add_emitter("res://audio/ambience/jungle/AMB_DAYLIGHT_RIDGE_WIND.ogg", Vector3(0, RIDGE_Y + 3, -58), -4.0, 35.0)
	sc.add_reverb_zone(WATERFALL_POS + Vector3(0, 4, 8), Vector3(18, 12, 26), "ruin")
	sc.add_reverb_zone(Vector3(0, RIDGE_Y + 4, -62), Vector3(26, 10, 10), "ruin")