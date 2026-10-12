extends Node3D
## S-bend connector passage used to join two campaign regions without a visible swap.
##
## Local frame: mouth A at the origin, travel along -Z, mouth B at (0, 0, -24).
##   leg A  x=0    z 0..-6
##   jog 1  x -1.3..5.8, z -6..-9
##   leg M  x=4.5  z -9..-15     <- the region swap happens here (SwapArea)
##   jog 2  x -1.3..5.8, z -15..-18
##   leg B  x=0    z -18..-24
## The legs are offset by more than their width, so from anywhere in leg M neither mouth is
## visible (a sight line would have to cross 3.8 m of lateral offset inside a 2.6 m leg).
## The previous region builds this at its exit; the next region builds an identical copy
## behind its spawn. Swapping regions while Mara is in leg M is therefore invisible.

const KIT := preload("res://systems/levelb/LBKit.gd")
const ROCK_ALBEDO := "res://assets/textures/polyhaven/rock_wall_08_diff_1k.jpg"
const ROCK_NORMAL := "res://assets/textures/polyhaven/rock_wall_08_nor_gl_1k.jpg"
const ROCK_ROUGH := "res://assets/textures/polyhaven/rock_wall_08_rough_1k.jpg"
const HALF := 1.3
const H := 3.4
const OFFSET := 4.5
const LENGTH := 24.0
## Route through the passage, in order (QA bots and scripted walkers use these).
const WAYPOINTS := [Vector3(0, 0, -2.5), Vector3(0, 0, -7.5), Vector3(OFFSET, 0, -7.5), Vector3(OFFSET, 0, -12.0),
	Vector3(OFFSET, 0, -16.5), Vector3(0, 0, -16.5), Vector3(0, 0, -21.5), Vector3(0, 0, -26.5)]
const SWAP_INDEX := 3

signal swap_entered

var stone: StandardMaterial3D
var swap_area: Area3D

static func create(parent: Node3D, xform: Transform3D, node_name: String, seal_mouth_a := false) -> Node3D:
	var p: Node3D = load("res://systems/world/SeamlessPassage.gd").new()
	p.name = node_name
	parent.add_child(p)
	p.global_transform = xform
	p._build(seal_mouth_a)
	return p

func _build(seal_mouth_a: bool) -> void:
	set_meta("collision", "none")
	stone = StandardMaterial3D.new()
	stone.albedo_texture = load(ROCK_ALBEDO)
	stone.albedo_color = Color(0.6, 0.58, 0.54)
	stone.normal_enabled = true
	stone.normal_texture = load(ROCK_NORMAL)
	stone.roughness_texture = load(ROCK_ROUGH)
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.4
	_leg(Vector3(0, 0, -3), 6.0)
	_chamber(-7.5)
	_leg(Vector3(OFFSET, 0, -12), 6.0)
	_chamber(-16.5)
	_leg(Vector3(0, 0, -21), 6.0)
	for z in [-1.0, -12.0, -23.0]:
		var x := OFFSET if z == -12.0 else 0.0
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.76, 0.5)
		l.light_energy = 1.0
		l.omni_range = 7.0
		add_child(l)
		l.position = Vector3(x, H - 0.5, z)
	for i in WAYPOINTS.size():
		var m := Marker3D.new()
		m.name = "Q%d" % i
		add_child(m)
		m.position = WAYPOINTS[i]
	swap_area = Area3D.new()
	swap_area.name = "SwapArea"
	swap_area.collision_layer = 0
	swap_area.collision_mask = 1
	add_child(swap_area)
	swap_area.position = Vector3(OFFSET, 1.5, -12.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF * 2.0, 3.0, 2.0)
	cs.shape = box
	swap_area.add_child(cs)
	swap_area.body_entered.connect(func(b): if b is CharacterBody3D and b.is_in_group("player"): swap_entered.emit())
	if seal_mouth_a:
		# Region loaded on its own (save/continue): the way back is blocked by a rockfall.
		_box(Vector3(0, H * 0.5, -0.6), Vector3(HALF * 2.0 + 0.4, H, 1.0))
		for i in 3:
			KIT.place(self, "res://assets/polyhaven/models/boulder_01/boulder_01.gltf", to_global(Vector3(-0.8 + i * 0.8, 0, -1.2)), 1.3, i * 1.1)

func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("no_dressing", true)
	add_child(body)
	body.position = center
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = stone
	body.add_child(mi)

func _leg(center: Vector3, length: float) -> void:
	_box(center + Vector3(0, -0.5, 0), Vector3(HALF * 2.0 + 1.0, 1.0, length + 0.02))
	_box(center + Vector3(0, H + 0.5, 0), Vector3(HALF * 2.0 + 2.0, 1.0, length + 0.02))
	for s in [-1.0, 1.0]:
		_box(center + Vector3(s * (HALF + 0.5), H * 0.5, 0), Vector3(1.0, H, length + 0.02))

func _chamber(z: float) -> void:
	var x0 := -HALF
	var x1 := OFFSET + HALF
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	_box(Vector3(cx, -0.5, z), Vector3(w + 2.0, 1.0, 3.0))
	_box(Vector3(cx, H + 0.5, z), Vector3(w + 2.0, 1.0, 3.0))
	_box(Vector3(x0 - 0.5, H * 0.5, z), Vector3(1.0, H, 3.0))
	_box(Vector3(x1 + 0.5, H * 0.5, z), Vector3(1.0, H, 3.0))
	# End walls with the leg openings (leg at x=0 on one side, x=OFFSET on the other).
	for side in [[z + 1.5, 0.0, OFFSET], [z - 1.5, OFFSET, 0.0]]:
		var wall_z: float = side[0]
		var open_x: float = side[1] if z == -7.5 else side[2]
		var left := (open_x - HALF) - (x0 - 1.0)
		var right := (x1 + 1.0) - (open_x + HALF)
		if left > 0.05:
			_box(Vector3(x0 - 1.0 + left * 0.5, H * 0.5, wall_z), Vector3(left, H, 0.4))
		if right > 0.05:
			_box(Vector3(open_x + HALF + right * 0.5, H * 0.5, wall_z), Vector3(right, H, 0.4))

## Global waypoint list.
func route() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for w in WAYPOINTS:
		out.append(to_global(w))
	return out

## Transform that puts mouth B just behind a spawn point, travelling the way the spawn faces.
static func entry_transform(spawn: Transform3D) -> Transform3D:
	var fwd := -spawn.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	var yaw := atan2(-fwd.x, -fwd.z)
	var basis := Basis(Vector3.UP, yaw)
	return Transform3D(basis, spawn.origin - fwd.normalized() * (LENGTH + 1.0))

## Transform for an exit passage whose mouth A sits at `at`, travelling `yaw`.
static func exit_transform(at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)

## Hides and de-collides region geometry intersecting the passage volume, except anything
## containing `keep` (the floor Mara stands on at the mouth). Region art that would poke into
## the tunnel (cliffs, rocks, walls behind a spawn) is the main source of visible seams.
static func clear_volume(level: Node, passage: Node3D, keep: Vector3) -> int:
	var vol := AABB(Vector3(-HALF - 1.2, -0.2, -LENGTH - 0.5), Vector3(OFFSET + HALF * 2.0 + 2.4, H + 0.4, LENGTH + 1.0))
	var inv := passage.global_transform.affine_inverse()
	var count := 0
	var floor_y := passage.global_position.y
	# Only the ground under the mouth is protected (and carved); arches or gates that merely
	# straddle the mouth keep their visuals but lose collision inside the tunnel.
	var ground: Object = null
	var player := level.get_node_or_null("Player") as CollisionObject3D
	var excl: Array[RID] = []
	if player:
		excl.append(player.get_rid())
	for b in passage.find_children("*", "StaticBody3D", true, false):
		excl.append((b as StaticBody3D).get_rid()) # the passage's own floor is not "the ground"
	var q := PhysicsRayQueryParameters3D.create(keep + Vector3.UP * 0.4, keep + Vector3.DOWN * 3.0, 3, excl)
	var g: Dictionary = (level as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	if not g.is_empty():
		ground = g.collider
	for n in level.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if passage.is_ancestor_of(vi) or vi is Light3D or not vi.is_visible_in_tree():
			continue
		if vi.get_parent() is CharacterBody3D or vi.get_parent().get_parent() is CharacterBody3D:
			continue
		var box := vi.global_transform * vi.get_aabb()
		if not (inv * box).intersects(vol):
			continue
		if box.size.length() > 120.0 or box.has_point(keep):
			# Ground Mara stands on: carve the tunnel footprint out of it instead of hiding it.
			if vi is MeshInstance3D and box.size.y < 0.6 * maxf(box.size.x, box.size.z):
				count += _carve_mesh(vi as MeshInstance3D, inv, vol, floor_y)
			continue
		vi.visible = false
		count += 1
	# CSG blockout pieces collide through their own use_collision flag.
	for n in level.find_children("*", "CSGShape3D", true, false):
		var csg := n as CSGShape3D
		if not csg.use_collision or passage.is_ancestor_of(csg):
			continue
		var cbox := csg.global_transform * csg.get_aabb()
		if cbox.size.length() > 120.0 or csg == ground or (ground is Node and csg.is_ancestor_of(ground)):
			continue
		if (inv * cbox).intersects(vol):
			csg.set_deferred("use_collision", false)
			count += 1
	for n in level.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		var owner_body := cs.get_parent()
		if passage.is_ancestor_of(cs) or not owner_body is StaticBody3D or cs.shape == null:
			continue
		var box := cs.global_transform * (cs.shape.get_debug_mesh().get_aabb() if not cs.shape is HeightMapShape3D else _heightmap_aabb(cs.shape))
		if not (inv * box).intersects(vol):
			continue
		if owner_body == ground or box.size.length() > 120.0:
			if cs.shape is HeightMapShape3D:
				count += _carve_heightmap(cs, inv, vol, floor_y)
			elif cs.shape is ConcavePolygonShape3D:
				count += _carve_concave(cs, inv, vol, floor_y)
			continue
		cs.set_deferred("disabled", true)
		count += 1
	return count

## Carving stops just inside the mouths so the ground Mara stands on outside stays intact.
static func _in_footprint(local: Vector3, vol: AABB) -> bool:
	return local.x > vol.position.x and local.x < vol.end.x and local.z > -LENGTH + 0.3 and local.z < -0.3

## Lowers heightmap samples inside the tunnel footprint below the tunnel floor (a trench the
## passage shell sits in), so the ground no longer crosses the tunnel interior.
static func _carve_heightmap(cs: CollisionShape3D, inv: Transform3D, vol: AABB, floor_y: float) -> int:
	var hm := (cs.shape as HeightMapShape3D).duplicate() as HeightMapShape3D
	var data := hm.map_data
	var w := hm.map_width
	var d := hm.map_depth
	var to_local := cs.global_transform.affine_inverse()
	var changed := 0
	for j in d:
		for i in w:
			var idx := j * w + i
			var lp := Vector3(i - (w - 1) * 0.5, data[idx], j - (d - 1) * 0.5)
			var gp := cs.global_transform * lp
			if _in_footprint(inv * gp, vol) and gp.y > floor_y - 0.6:
				data[idx] = (to_local * Vector3(gp.x, floor_y - 0.8, gp.z)).y
				changed += 1
	if changed > 0:
		hm.map_data = data
		cs.shape = hm
	return changed

static func _heightmap_aabb(hm: HeightMapShape3D) -> AABB:
	var lo := INF
	var hi := -INF
	for v in hm.map_data:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return AABB(Vector3(-(hm.map_width - 1) * 0.5, lo, -(hm.map_depth - 1) * 0.5), Vector3(hm.map_width - 1, hi - lo, hm.map_depth - 1))

## Removes concave-ground triangles that cross the tunnel interior.
static func _carve_concave(cs: CollisionShape3D, inv: Transform3D, vol: AABB, floor_y: float) -> int:
	var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
	var kept := PackedVector3Array()
	var removed := 0
	for t in range(0, faces.size(), 3):
		var c := cs.global_transform * ((faces[t] + faces[t + 1] + faces[t + 2]) / 3.0)
		var lc := inv * c
		if _in_footprint(lc, vol) and lc.y > -0.3 and lc.y < vol.end.y:
			removed += 1
			continue
		kept.append(faces[t]); kept.append(faces[t + 1]); kept.append(faces[t + 2])
	if removed > 0:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(kept)
		cs.shape = shape
	return removed

## Drops terrain-mesh vertices inside the footprint to just below the tunnel floor.
static func _carve_mesh(mi: MeshInstance3D, inv: Transform3D, vol: AABB, floor_y: float) -> int:
	var am := mi.mesh as ArrayMesh
	if am == null or am.get_surface_count() == 0:
		return 0
	var mdt := MeshDataTool.new()
	if mdt.create_from_surface(am, 0) != OK or mdt.get_vertex_count() > 250000:
		return 0
	var to_local := mi.global_transform.affine_inverse()
	var changed := 0
	for v in mdt.get_vertex_count():
		var gp := mi.global_transform * mdt.get_vertex(v)
		if _in_footprint(inv * gp, vol) and gp.y > floor_y - 0.6:
			mdt.set_vertex(v, to_local * Vector3(gp.x, floor_y - 0.8, gp.z))
			changed += 1
	if changed > 0:
		var mat := mi.get_active_material(0)
		var out := ArrayMesh.new()
		mdt.commit_to_surface(out)
		mi.mesh = out
		if mat and mi.material_override == null:
			mi.set_surface_override_material(0, mat)
	return changed

## Authored spawn transform of a level scene's Player node, read from the PackedScene state.
static func authored_spawn(packed: PackedScene) -> Transform3D:
	var st := packed.get_state()
	for i in st.get_node_count():
		if st.get_node_name(i) == "Player" and str(st.get_node_path(i, true)) == "./..":
			pass
		if st.get_node_name(i) == "Player":
			for k in st.get_node_property_count(i):
				if st.get_node_property_name(i, k) == "transform":
					return st.get_node_property_value(i, k)
			return Transform3D()
	return Transform3D()
