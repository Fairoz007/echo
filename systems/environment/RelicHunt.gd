extends Node
## Optional exploration layer: five hidden Vaelor resonance shards per chapter.
##
## Shards are LBCollectible tablets (interact to read, persisted by SaveManager, journal
## objective per shard). Lore: content/relic_shards.json. Placement is deterministic per
## chapter and probed against real floor collision; a spot is only accepted when it is on
## roughly the same level as the route and has clear line of sight from the travel corridor
## at waist height, so every shard is reachable with normal movement. Finding all five
## completes "opt_relics_cNN" and awards XP once.

const KIT := preload("res://systems/levelb/LBKit.gd")
const MASK := 3
const SIGHT_MASK := 0x7FFFFFFF
const COUNT := 5
const XP_REWARD := 400

var chapter := 0
var shards: Array[Node] = []
var _announced := 0

static func apply(level: Node3D, p_chapter: int) -> void:
	var hunt: Node = load("res://systems/environment/RelicHunt.gd").new()
	hunt.name = "RelicHunt"
	hunt.chapter = p_chapter
	level.add_child(hunt)
	hunt._place.call_deferred(level)

func _place(level: Node3D) -> void:
	# Several levels generate their cave shells / dressing over the first frames (and Ch6
	# builds incrementally when staged); validate placement only against the finished world.
	if "is_built" in level:
		while is_instance_valid(level) and not level.is_built:
			await get_tree().process_frame
	# Wait until the level's collision stops changing (procedural rock masses, cave shells and
	# dressing are added over many frames), up to 10 s.
	var last := -1
	var stable := 0
	for i in 600:
		await get_tree().physics_frame
		if not is_instance_valid(level):
			return
		var n := level.find_children("*", "CollisionShape3D", true, false).size()
		stable = stable + 1 if n == last else 0
		last = n
		if stable >= 120 and i >= 180:
			break
	if not is_instance_valid(level):
		return
	var lore: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/relic_shards.json")).get(str(chapter), [])
	if lore.is_empty():
		return
	var space := level.get_world_3d().direct_space_state
	var player := level.get_node_or_null("Player") as Node3D
	var route_y := player.global_position.y if player else 0.0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	var player_mask: int = player.collision_mask if player else 3
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	var bounds := _bounds(level)
	var avoid: Array[Vector3] = []
	for a in level.find_children("*", "Area3D", true, false):
		avoid.append((a as Node3D).global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51000 + chapter
	var placed: Array[Vector3] = []
	for attempt in 4000:
		if placed.size() >= mini(COUNT, lore.size()):
			break
		var x := rng.randf_range(bounds.position.x, bounds.end.x)
		var z := rng.randf_range(bounds.position.z, bounds.end.z)
		# 5..36 m off the corridor: worth a detour, never out at the unreachable level fringe.
		if absf(x) < 5.0 or absf(x) > 36.0 or absf(z) > 48.0:
			continue
		var hit := _floor(space, Vector3(x, bounds.end.y + 20.0, z), bounds.position.y - 20.0)
		# The Drowned Temple is a diving chapter: shards may lie on the flooded hall floor.
		if hit.is_empty() or absf(hit.position.y - route_y) > (6.0 if chapter == 6 else 2.5):
			continue
		var p: Vector3 = hit.position
		# Story triggers can spawn collapses or debris; keep shards clear of them.
		if avoid.any(func(a): return Vector2(a.x - p.x, a.z - p.z).length() < 8.0):
			continue
		if placed.any(func(q): return q.distance_to(p) < 12.0):
			continue
		# Reachability: clear waist-height sight line from the corridor at the same z.
		var from := Vector3(0, p.y + 1.0, p.z)
		var corridor_floor := _floor(space, from + Vector3.UP * 3.0, p.y - 4.0)
		if corridor_floor.is_empty() or absf(corridor_floor.position.y - p.y) > (6.0 if chapter == 6 else 1.5):
			continue
		# Sweep Mara's own capsule (her collision mask) from the corridor to the shard: this is
		# exactly what would stop her walking there. Then sample the floor for pits on the way.
		var start := Vector3(0, corridor_floor.position.y + 0.95, p.z)
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = capsule
		params.transform = Transform3D(Basis(), start)
		params.motion = Vector3(p.x, p.y + 0.95, p.z) - start
		params.collision_mask = player_mask
		params.exclude = exclude
		var frac: PackedFloat32Array = space.cast_motion(params)
		if frac.is_empty() or frac[0] < 0.97:
			continue
		var pit := false
		for k in range(1, 8):
			var mid := start.lerp(Vector3(p.x, p.y + 0.95, p.z), k / 8.0)
			var f := _floor(space, mid + Vector3.UP * 0.5, mid.y - 3.0)
			if f.is_empty() or absf(f.position.y - p.y) > (6.0 if chapter == 6 else 1.2):
				pit = true
				break
		if pit:
			continue
		placed.append(p)
	for i in placed.size():
		var id := "shard_c%02d_%d" % [chapter, i + 1]
		var c := KIT.collectible(self, id, "tablet", "Resonance Shard %d/%d" % [i + 1, placed.size()], lore[i], placed[i] + Vector3(0, 0.05, 0), rng.randf() * TAU)
		shards.append(c)
	print("[RELIC] chapter %d: %d shards placed" % [chapter, placed.size()])

func _process(_d: float) -> void:
	if shards.is_empty():
		return
	var found := shards.filter(func(s): return is_instance_valid(s) and s.collected).size()
	if found == _announced:
		return
	_announced = found
	var obj := "opt_relics_c%02d" % chapter
	if found >= shards.size() and not MissionManager.completed_objectives.has(obj):
		MissionManager.register_objective(obj, "Recover every Vaelor resonance shard in this area")
		MissionManager.complete_objective(obj)
		SkillManager.add_xp(XP_REWARD)
		AudioManager.play_story_line("Mara", "That's all of them. Whatever they were saying, it's starting to make sense.", 4.0)
	elif found > 0 and found < shards.size():
		AudioManager.play_story_line("Mara", "Another shard. %d of %d." % [found, shards.size()], 2.5)

func _floor(space: PhysicsDirectSpaceState3D, from: Vector3, bottom: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(from.x, bottom, from.z), MASK)
	var hit: Dictionary = space.intersect_ray(q)
	var guard := 0
	while not hit.is_empty() and hit.normal.y < 0.2 and guard < 3:
		q.from = hit.position + Vector3.DOWN * 0.05
		hit = space.intersect_ray(q)
		guard += 1
	if hit.is_empty() or hit.normal.y < 0.85 or hit.collider is CharacterBody3D or hit.collider.get_meta("no_dressing", false):
		return {}
	return hit

func _bounds(level: Node3D) -> AABB:
	var total := AABB()
	var first := true
	for cs in level.find_children("*", "CollisionShape3D", true, false):
		var s := cs as CollisionShape3D
		var body := s.get_parent() as StaticBody3D
		if body == null or body.collision_layer & MASK == 0 or s.shape == null:
			continue
		var box := s.global_transform * s.shape.get_debug_mesh().get_aabb()
		if box.size.length() > 600.0:
			continue
		total = box if first else total.merge(box)
		first = false
	return total.grow(-2.0) if not first else AABB(Vector3(-30, -10, -40), Vector3(60, 30, 80))
