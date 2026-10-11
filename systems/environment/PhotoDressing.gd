extends RefCounted
## Scatters downloaded CC0 Poly Haven models (assets/polyhaven/models) over a level's real floor.
##
## Candidate points are probed with downward raycasts against world collision (layer 2), so
## props only land on walkable-looking ground. Points near the spawn, any Area3D trigger or
## interactable, or the central travel corridor (|x| < 4.5, levels run along -Z) are rejected,
## and nothing placed here gets collision, so dressing can never block progression.
## Licences: assets/polyhaven/models/SOURCES.json, ASSET_LICENSE_REGISTER.md.

const KIT := preload("res://systems/levelb/LBKit.gd")
const PH := "res://assets/polyhaven/models/"
const MASK := 3 ## blockout floors are on layer 1, generated environment collision on layer 2

# [model id, height range (m), weight, needs open sky / headroom (m), fit_height]
const NATURE_JUNGLE := [["fern_02", Vector2(0.7, 1.3), 5, 1.4, true], ["calathea_orbifolia_01", Vector2(0.6, 1.0), 3, 1.2, true],
	["pachira_aquatica_01", Vector2(1.8, 3.2), 2, 3.5, true], ["rock_moss_set_01", Vector2(1.2, 2.0), 2, 1.5, false],
	["root_cluster_01", Vector2(0.9, 1.4), 1, 1.5, false], ["dead_tree_trunk", Vector2(4.0, 6.0), 1, 1.5, false]]
const NATURE_CAVE := [["rock_07", Vector2(0.8, 1.8), 4, 1.8, true], ["rock_09", Vector2(0.7, 1.6), 4, 1.8, true],
	["rock_moss_set_02", Vector2(2.4, 3.6), 1, 1.6, false], ["boulder_01", Vector2(1.6, 2.8), 2, 2.8, true],
	["dry_branches_medium_01", Vector2(1.2, 2.0), 1, 1.0, false]]
const NATURE_RUINS := [["rock_07", Vector2(0.7, 1.5), 3, 1.6, true], ["rock_moss_set_02", Vector2(2.2, 3.2), 2, 1.5, false],
	["fern_02", Vector2(0.6, 1.1), 3, 1.2, true], ["root_cluster_01", Vector2(0.9, 1.3), 2, 1.4, false],
	["dry_branches_medium_01", Vector2(1.0, 1.8), 1, 1.0, false]]
const MERIDIAN := [["wooden_crate_01", 0.7], ["plastic_crate_03", 0.45], ["Barrel_01", 0.95], ["barrel_03", 0.95],
	["metal_jerrycan_green", 0.47], ["ammo_box", 0.4], ["old_military_compressor", 0.9], ["portable_generator", 0.62],
	["portable_searchlight", 1.1], ["metal_toolbox", 0.26], ["picke_dirty_01", 0.9], ["Lantern_01", 0.34]]

## chapter -> [nature set, nature count, prop clusters]
const PLAN := {
	0: ["cave", 26, 1], 2: ["jungle", 46, 1], 3: ["ruins", 34, 0], 4: ["cave", 34, 3],
	7: ["ruins", 50, 2], 9: ["ruins", 36, 3], 10: ["cave", 20, 1], 11: ["cave", 40, 0],
}

static func apply(level: Node3D, chapter: int) -> void:
	if not PLAN.has(chapter):
		return
	# World collision must be registered with the physics server before probing.
	await level.get_tree().physics_frame
	if not is_instance_valid(level):
		return
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "PhotoDressing"
	root.set_meta("collision", "none")
	level.add_child(root)
	var plan: Array = PLAN[chapter]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + chapter
	var bounds := _floor_bounds(level)
	var avoid := _avoid_points(level)
	# Caves and ruins are lit by sparse local lights: only dress where the player can see.
	var lights: Array = []
	if plan[0] != "jungle":
		for l in level.find_children("*", "OmniLight3D", true, false):
			if l.visible and l.light_energy > 0.2:
				lights.append([l.global_position, l.omni_range * 1.4])
		for l in level.find_children("*", "SpotLight3D", true, false):
			if l.visible and l.light_energy > 0.2 and not l.get_parent() is CharacterBody3D:
				lights.append([l.global_position, l.spot_range * 0.6])
	var space := level.get_world_3d().direct_space_state
	var set: Array = {"jungle": NATURE_JUNGLE, "cave": NATURE_CAVE, "ruins": NATURE_RUINS}[plan[0]]
	var total_w := 0
	for e in set:
		total_w += e[2]
	var placed := 0
	for i in plan[1] * 24:
		if placed >= plan[1]:
			break
		# First half of the attempts insist on lit ground; later ones top up anywhere.
		var target: int = plan[1]
		var need_light: bool = i < target * 12 or placed >= target / 2
		var e: Array = _pick(set, total_w, rng)
		var hit := _probe(space, bounds, avoid, rng, e[3], 3.0 if e[1].y < 2.0 else 6.0)
		if hit.is_empty() or (need_light and not _lit(hit.position, lights)):
			continue
		_place(root, e[0], hit.position - Vector3(0, 0.06, 0), rng.randf_range(e[1].x, e[1].y), rng.randf() * TAU, e[4])
		placed += 1
	# Meridian supply clusters: 3-5 props grouped like an abandoned or active work site.
	var clusters := 0
	for c in plan[2] * 20:
		if clusters >= plan[2]:
			break
		var centre := _probe(space, bounds, avoid, rng, 2.0, 5.0)
		if centre.is_empty():
			continue
		clusters += 1
		# Every Meridian work site brings its own lamp, so it reads in the dark.
		_place(root, "Lantern_01", centre.position + Vector3(0.3, 0, -0.4), 0.34, rng.randf() * TAU, true)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 1.4
		lamp.omni_range = 7.0
		root.add_child(lamp)
		lamp.global_position = centre.position + Vector3(0.3, 0.9, -0.4)
		for k in rng.randi_range(3, 5):
			var p: Array = MERIDIAN[rng.randi() % MERIDIAN.size()]
			var off := Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
			var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(centre.position + off + Vector3.UP * 1.5, centre.position + off + Vector3.DOWN * 2.0, MASK))
			if down.is_empty():
				continue
			_place(root, p[0], down.position, p[1], rng.randf() * TAU, true)
	print("[PHOTO] chapter %d: %d nature, %d prop clusters in %d ms" % [chapter, placed, clusters, Time.get_ticks_msec() - t0])

static func _lit(p: Vector3, lights: Array) -> bool:
	if lights.is_empty():
		return true
	for l in lights:
		if p.distance_to(l[0]) < l[1]:
			return true
	return false

static func _pick(set: Array, total_w: int, rng: RandomNumberGenerator) -> Array:
	var r := rng.randi() % total_w
	for e in set:
		r -= e[2]
		if r < 0:
			return e
	return set[0]

static func _place(parent: Node3D, id: String, at: Vector3, height: float, yaw: float, fit_height: bool) -> void:
	var n := KIT.place(parent, PH + id + "/" + id + ".gltf", at, height, yaw, Vector3.ONE, fit_height, id)
	if n:
		n.set_meta("collision", "none")

static func _floor_bounds(level: Node3D) -> AABB:
	var total := AABB()
	var first := true
	for cs in level.find_children("*", "CollisionShape3D", true, false):
		var shape_node := cs as CollisionShape3D
		var body := shape_node.get_parent() as StaticBody3D
		if body == null or body.collision_layer & MASK == 0 or shape_node.shape == null:
			continue
		var box := shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb()
		if box.size.length() > 600.0:
			continue
		total = box if first else total.merge(box)
		first = false
	return total.grow(-2.0) if not first else AABB(Vector3(-30, -10, -40), Vector3(60, 30, 80))

static func _avoid_points(level: Node3D) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for n in level.find_children("*", "Area3D", true, false):
		pts.append((n as Node3D).global_position)
	var player := level.get_node_or_null("Player") as Node3D
	if player:
		pts.append(player.global_position)
	return pts

static func _probe(space: PhysicsDirectSpaceState3D, bounds: AABB, avoid: Array[Vector3], rng: RandomNumberGenerator, headroom: float, corridor: float) -> Dictionary:
	var x := rng.randf_range(bounds.position.x, bounds.end.x)
	var z := rng.randf_range(bounds.position.z, bounds.end.z)
	if absf(x) < corridor:
		return {}
	var top := bounds.end.y + 20.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, bounds.position.y - 20.0, z), MASK)
	var hit: Dictionary = space.intersect_ray(q)
	# Caves have ceilings: if the first hit faces down, re-probe from just under it.
	var guard := 0
	while not hit.is_empty() and hit.normal.y < 0.2 and guard < 3:
		q.from = hit.position + Vector3.DOWN * 0.05
		hit = space.intersect_ray(q)
		guard += 1
	if hit.is_empty() or hit.normal.y < 0.82:
		return {}
	for a in avoid:
		if Vector2(a.x - x, a.z - z).length() < 4.0:
			return {}
	var up: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(hit.position + Vector3.UP * 0.1, hit.position + Vector3.UP * headroom, MASK))
	if not up.is_empty():
		return {}
	return hit
