extends Node
class_name EnvironmentCollision
## Reusable runtime collision pass for imported/visual environment geometry.
## Walks the level once (deferred, after all dressing scripts ran) and gives every
## visible MeshInstance3D that is not already covered by a physics body a
## StaticBody3D matched to its class:
##   rock/boulder/stalagmite/crate/prop -> convex hull
##   wall/floor/ceiling/ruin/arch/bridge/pillar/cave shell -> trimesh (concave)
##   tree -> cylinder trunk
##   fern/grass/plant/leaf/foliage/tiny meshes -> none
## Override per node with metadata "collision" = "none"|"convex"|"trimesh"|"trunk"|"box"
## (checked on the mesh and its ancestors) or group "no_auto_collision".

const META_KEY := "collision"
const GENERATED_GROUP := "auto_collision"
const MIN_SIZE := 0.45 # metres; smaller meshes never block the player
const LAYER := 1

const NONE_WORDS := ["fern", "grass", "plant", "leaf", "leaves", "foliage", "vine", "moss_patch", "decal", "water", "puddle", "fog", "glow", "light", "beam", "particle", "dust"]
const TRUNK_WORDS := ["tree", "trunk", "palm"]
const TRIMESH_WORDS := ["wall", "floor", "ceiling", "roof", "ruin", "arch", "bridge", "pillar", "column", "portal", "stair", "platform", "ledge", "cave", "cavern", "shell", "terrain", "ground", "barrier", "door", "turbine", "monolith", "rockfall_shelf"]
const CONVEX_WORDS := ["rock", "boulder", "stalag", "rubble", "stone", "crate", "tent", "radio", "desk", "box", "barrel", "prop", "pedestal"]

static func attach(level: Node) -> void:
	if level == null or level.has_node("EnvironmentCollision"):
		return
	var pass_node := EnvironmentCollision.new()
	pass_node.name = "EnvironmentCollision"
	level.add_child.call_deferred(pass_node)

var report: Array[Dictionary] = []
## Set once the deferred pass has finished (the runtime pass is spread over frames).
var is_done := false
signal done
## Main-thread budget per frame for the runtime pass. One shape is always cooked per
## frame, so a single huge hull can still exceed it, but the pass no longer cooks
## every hull of the level in one frame (Ch7 was 606 ms in a single frame).
const FRAME_BUDGET_USEC := 6000
## Cooked shapes shared between instances of the same mesh resource (Tripo props are
## instanced many times; a simplified convex hull costs ~40 ms each).
var _shape_cache := {}
var _profile := false

func _ready() -> void:
	_profile = OS.get_cmdline_user_args().has("--profile-build")
	# Two frames so dressing that is spawned in sibling _ready()/deferred calls exists.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		var t := Time.get_ticks_usec()
		await build_async(get_parent())
		if _profile:
			print("[COLLISION] build spread over frames, %.0f ms wall" % ((Time.get_ticks_usec() - t) / 1000.0))
		if is_inside_tree():
			print("[COLLISION] %s: generated %d collision bodies" % [get_parent().name, report.size()])
	is_done = true
	done.emit()

## Synchronous pass (QA / tools).
func build(level: Node) -> Array[Dictionary]:
	report.clear()
	for mesh in level.find_children("*", "MeshInstance3D", true, false):
		_process_mesh(level, mesh as MeshInstance3D)
	for csg in level.find_children("*", "CSGShape3D", true, false):
		_process_csg(level, csg as CSGShape3D)
	return report

## Runtime pass: same result as build(), but yields whenever the frame budget is spent.
func build_async(level: Node) -> Array[Dictionary]:
	report.clear()
	var items: Array = level.find_children("*", "MeshInstance3D", true, false)
	items.append_array(level.find_children("*", "CSGShape3D", true, false))
	var frame_start := Time.get_ticks_usec()
	for node in items:
		if not is_inside_tree() or not is_instance_valid(level):
			return report
		if not is_instance_valid(node):
			continue
		var t := Time.get_ticks_usec()
		if node is MeshInstance3D:
			_process_mesh(level, node)
		else:
			_process_csg(level, node)
		var cost := Time.get_ticks_usec() - t
		if _profile and cost > 15000:
			print("[COLLISION] slow %s %.0f ms" % [node.name, cost / 1000.0])
		if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
			await get_tree().process_frame
			frame_start = Time.get_ticks_usec()
	return report

func _cached_shape(key: String, maker: Callable) -> Shape3D:
	if not _shape_cache.has(key):
		_shape_cache[key] = maker.call()
	return _shape_cache[key]

func _lod3_shape(lod3_path: String, fallback: Mesh) -> Shape3D:
	var lod_mesh: Mesh = null
	if lod3_path != "" and ResourceLoader.exists(lod3_path):
		var inst := (load(lod3_path) as PackedScene).instantiate()
		var found := inst.find_children("*", "MeshInstance3D", true, false)
		if found.size() > 0:
			lod_mesh = found[0].mesh
		inst.free()
	return (lod_mesh if lod_mesh else fallback).create_trimesh_shape()

func _process_csg(level: Node, csg: CSGShape3D) -> void:
	# Only root CSG shapes own collision; skip ones already colliding or under a body.
	if csg.use_collision or csg.get_parent() is CSGShape3D or not csg.is_visible_in_tree():
		return
	if is_covered_or_exempt(csg, level) != "":
		return
	if classify(csg, level) == "none":
		return
	csg.use_collision = true
	csg.collision_layer = LAYER
	report.append({"mesh": str(level.get_path_to(csg)), "kind": "csg", "size": Vector3.ZERO})

## Per-asset rules for the optimized Tripo set (TRIPO_DELIVERY_REPORT.md).
## "lod3" = trimesh built from the sibling _LOD3.glb.
const ASSET_RULES := {
	"arch_wall_vaelor": "box", "arch_floor_stone": "box", "arch_glass_barrier": "box",
	"ruin_pillar_vaelor": "convex", "prop_expedition_tent": "convex",
	"arch_bridge_span": "lod3", "ruin_arch_portal": "lod3",
	"env_boulder_moss": "convex", "env_stalagmite_cluster": "convex", "prop_vaelor_turbine_wheel": "convex",
	"prop_meridian_crate": "box", "prop_expedition_radio_station": "box", "prop_vaelor_key": "none",
}

static func asset_root(mesh: Node, level: Node) -> Node:
	var node := mesh
	while node and node != level:
		if node.scene_file_path.ends_with(".glb"):
			return node
		node = node.get_parent()
	return null

static func asset_rule(mesh: Node, level: Node) -> String:
	var root := asset_root(mesh, level)
	if root == null:
		return ""
	var base := root.scene_file_path.get_file().get_basename()
	base = base.trim_suffix("_LOD0").trim_suffix("_LOD1").trim_suffix("_LOD2").trim_suffix("_LOD3")
	return ASSET_RULES.get(base, "")

static func classify(mesh: Node, level: Node) -> String:
	var node := mesh
	while node and node != level:
		if node.has_meta(META_KEY):
			return str(node.get_meta(META_KEY))
		if node.is_in_group("no_auto_collision"):
			return "none"
		node = node.get_parent()
	var rule := asset_rule(mesh, level)
	if rule != "":
		return rule
	# Closest name first so a parent like "NaturalCavernArt" never overrides "Boulder".
	node = mesh
	while node and node != level:
		var label := (String(node.name) + " " + node.scene_file_path.get_file()).to_lower()
		for group in [[NONE_WORDS, "none"], [TRUNK_WORDS, "trunk"], [TRIMESH_WORDS, "trimesh"], [CONVEX_WORDS, "convex"]]:
			for w in group[0]:
				if label.contains(w):
					return group[1]
		node = node.get_parent()
	return "convex"

static func _label(mesh: Node, level: Node) -> String:
	var parts := PackedStringArray()
	var node := mesh
	while node and node != level:
		parts.append(String(node.name))
		if node.scene_file_path != "":
			parts.append(node.scene_file_path.get_file())
		node = node.get_parent()
	return " ".join(parts).to_lower()

## True if mesh is part of the player/NPCs/triggers or already lives under a physics body
## that owns collision shapes.
static func is_covered_or_exempt(mesh: Node, level: Node) -> String:
	var node := mesh.get_parent()
	while node and node != level:
		if node is CharacterBody3D or node is Area3D or node.is_in_group("player") or node is Skeleton3D:
			return "exempt"
		if node is CollisionObject3D:
			for child in node.get_children():
				if child is CollisionShape3D and not child.disabled:
					return "covered"
		node = node.get_parent()
	for child in mesh.get_children():
		if child is StaticBody3D:
			return "covered"
	return ""

static func world_size(mesh: MeshInstance3D) -> Vector3:
	var box := mesh.get_aabb()
	var b := mesh.global_transform.basis
	return Vector3(b.x.length() * box.size.x, b.y.length() * box.size.y, b.z.length() * box.size.z)

func _process_mesh(level: Node, mesh: MeshInstance3D) -> void:
	if mesh.mesh == null or not mesh.is_visible_in_tree():
		return
	var exempt := is_covered_or_exempt(mesh, level)
	if exempt != "":
		return
	var size := world_size(mesh)
	if size[size.max_axis_index()] < MIN_SIZE:
		return
	var kind := classify(mesh, level)
	if kind == "none":
		return
	var body := StaticBody3D.new()
	body.name = "AutoCollision"
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.add_to_group(GENERATED_GROUP)
	var shape_node := CollisionShape3D.new()
	var box := mesh.get_aabb()
	match kind:
		"lod3":
			var root := asset_root(mesh, level)
			var lod3_path := root.scene_file_path.replace("_LOD0.glb", "_LOD3.glb") if root else ""
			shape_node.shape = _cached_shape("lod3:%s:%d" % [lod3_path, mesh.mesh.get_rid().get_id()], _lod3_shape.bind(lod3_path, mesh.mesh))
		"trimesh":
			shape_node.shape = _cached_shape("tri:%d" % mesh.mesh.get_rid().get_id(), mesh.mesh.create_trimesh_shape)
		"trunk":
			# Trunk: thin cylinder through the lower 60% of the bounds, ~12% of width.
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(0.05, minf(box.size.x, box.size.z) * 0.12)
			cyl.height = box.size.y * 0.6
			shape_node.shape = cyl
			shape_node.position = Vector3(box.get_center().x, box.position.y + cyl.height * 0.5, box.get_center().z)
		"box":
			var bs := BoxShape3D.new()
			bs.size = box.size
			shape_node.shape = bs
			shape_node.position = box.get_center()
		_:
			shape_node.shape = _cached_shape("cvx:%d" % mesh.mesh.get_rid().get_id(), mesh.mesh.create_convex_shape.bind(true, false))
			kind = "convex"
	if shape_node.shape == null:
		return
	body.add_child(shape_node)
	mesh.add_child(body)
	report.append({"mesh": str(level.get_path_to(mesh)), "kind": kind, "size": size})
