extends Node3D
## Data-driven placement of Tripo hero/environment assets (TRIPO_DELIVERY_REPORT.md Phase 2).
## Each entry: "res://path_LOD0.glb|x,y,z|rot_y_deg|size_m|collision[|axis]"
##   size_m: target length of the longest axis (or of `axis` = x|y|z if given)
##   y: height of the model's base (bottom of its bounds)
##   collision: none | box | convex | lod3 | lod2 (trimesh from that LOD file) | capsule
## Generated bodies are tagged so the EnvironmentCollision pass skips them.
## Foliage entries (path contains "fern"/"tree"/"root_curtain") get FoliageWind.

@export var placements: PackedStringArray = PackedStringArray()

signal built
var is_built := false
## Collision shapes cached per "path|kind" (shapes live in the model's local mesh space,
## so instances of the same asset share them). Convex/trimesh cooking is the costly part.
static var _shape_cache := {}

func _ready() -> void:
	# Load in background threads, then place one entry per frame so level load never stalls.
	var paths: Array[String] = []
	for entry in placements:
		var f := entry.split("|")
		if f.size() >= 5 and ResourceLoader.exists(f[0]):
			paths.append(f[0])
			var kind := f[4].strip_edges()
			if kind in ["lod3", "lod2", "convex"]:
				var lod := f[0].replace("_LOD0.glb", "_LOD2.glb" if kind == "lod2" else "_LOD3.glb")
				if ResourceLoader.exists(lod):
					paths.append(lod)
	for p in paths:
		ResourceLoader.load_threaded_request(p)
	for i in placements.size():
		var f := placements[i].split("|")
		if f.size() >= 5 and ResourceLoader.exists(f[0]):
			while ResourceLoader.load_threaded_get_status(f[0]) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
				if not is_inside_tree():
					return
		_place(placements[i], i)
		if i < placements.size() - 1:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	is_built = true
	built.emit()

func _get_res(path: String) -> Resource:
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var r := ResourceLoader.load_threaded_get(path)
		if r:
			return r
	return load(path)

func _place(entry: String, index: int) -> void:
	var f := entry.split("|")
	if f.size() < 5 or not ResourceLoader.exists(f[0]):
		push_warning("[HeroProps] bad or missing entry: " + entry)
		return
	var pos_f := f[1].split_floats(",")
	var pos := Vector3(pos_f[0], pos_f[1], pos_f[2])
	var model := (_get_res(f[0]) as PackedScene).instantiate() as Node3D
	model.name = "%s_%d" % [f[0].get_file().get_basename().trim_suffix("_LOD0"), index]
	model.set_meta("collision", "none") # collision is authored below
	add_child(model)
	var bounds := _bounds(model)
	var axis := f[5] if f.size() > 5 else ""
	var native := bounds.size[bounds.size.max_axis_index()]
	if axis == "x": native = bounds.size.x
	elif axis == "y": native = bounds.size.y
	elif axis == "z": native = bounds.size.z
	var s := float(f[3]) / maxf(native, 0.001)
	model.rotation.y = deg_to_rad(float(f[2]))
	model.scale = Vector3.ONE * s
	var center := bounds.get_center()
	model.position = pos - model.basis * Vector3(center.x, bounds.position.y, center.z)
	_collide(model, f[0], f[4].strip_edges())
	var lower := f[0].to_lower()
	if lower.contains("fern") or lower.contains("tree") or lower.contains("root_curtain"):
		var wind := preload("res://systems/FoliageWind.gd").new()
		wind.name = "FoliageWind"
		model.add_child(wind)
		wind.configure(model, bounds.size.y * s, pos.y, "tree" if lower.contains("tree") else "fern")

func _bounds(model: Node3D) -> AABB:
	var b := AABB()
	var started := false
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (model.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		b = b.merge(a) if started else a
		started = true
	return b

func _collide(model: Node3D, path: String, kind: String) -> void:
	if kind == "none":
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var src := meshes[0] as MeshInstance3D
	var body := StaticBody3D.new()
	body.name = "HeroCollision"
	body.add_to_group("auto_collision")
	src.add_child(body)
	var cs := CollisionShape3D.new()
	var box: AABB = src.get_aabb()
	var key := path + "|" + kind
	if _shape_cache.has(key):
		cs.shape = _shape_cache[key][0]
		cs.position = _shape_cache[key][1]
		body.add_child(cs)
		return
	match kind:
		"box":
			var b := BoxShape3D.new()
			b.size = box.size
			cs.shape = b
			cs.position = box.get_center()
		"capsule":
			var c := CylinderShape3D.new()
			c.radius = minf(box.size.x, box.size.z) * 0.3
			c.height = box.size.y
			cs.shape = c
			cs.position = box.get_center()
		"lod3", "lod2":
			var lod_path := path.replace("_LOD0.glb", "_LOD3.glb" if kind == "lod3" else "_LOD2.glb")
			var mesh: Mesh = src.mesh
			if ResourceLoader.exists(lod_path):
				var inst := (_get_res(lod_path) as PackedScene).instantiate()
				var found := inst.find_children("*", "MeshInstance3D", true, false)
				if found.size() > 0:
					mesh = found[0].mesh
				inst.free()
			cs.shape = mesh.create_trimesh_shape()
		_:
			# Hull from the LOD3 mesh (same local space): simplifying a LOD0 hull can cost 0.5 s.
			var hull_mesh: Mesh = src.mesh
			var lod3 := path.replace("_LOD0.glb", "_LOD3.glb")
			if lod3 != path and ResourceLoader.exists(lod3):
				var inst3 := (_get_res(lod3) as PackedScene).instantiate()
				var found3 := inst3.find_children("*", "MeshInstance3D", true, false)
				if found3.size() > 0:
					hull_mesh = found3[0].mesh
				inst3.free()
			cs.shape = hull_mesh.create_convex_shape(true, true)
	_shape_cache[key] = [cs.shape, cs.position]
	body.add_child(cs)
