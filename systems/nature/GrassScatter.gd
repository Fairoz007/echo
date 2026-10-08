class_name GrassScatter
extends Node3D
## Scatters MultiMesh grass over the colliders below this node.
## Rejects: no ground hit, slopes steeper than max_slope_deg, points under any
## WaterBody (group "water_volume"), points whose blade volume overlaps other
## collision (sphere query, excluding the ground collider), and colliders in
## group "no_grass", and dynamic bodies (RigidBody/CharacterBody/AnimatableBody). Output is chunked (chunk_size) per variation for culling.

@export var area_size := Vector2(20, 20)
@export var density := 6.0  ## clumps per m^2 before rejection
@export_range(0.0, 89.0) var max_slope_deg := 32.0
@export var ray_height := 20.0
@export var ray_depth := 40.0
@export_flags_3d_physics var ground_mask := 0xFFFFFFFF
@export_flags_3d_physics var overlap_mask := 0xFFFFFFFF
@export var overlap_radius := 0.18
@export var random_seed := 1337
@export var chunk_size := 8.0
@export var visibility_end := 45.0
@export var scale_range := Vector2(0.75, 1.3)
@export var scatter_on_ready := true
## 0 Low graphics => density scaled by this.
@export var low_quality_density_scale := 0.35

var stats := {}
var _chunks: Array[MultiMeshInstance3D] = []
static var _material: ShaderMaterial

## (blades, height, width, lean) per variation: short tuft, tall grass, wide dense, sparse wispy
const VARIATIONS := [
	[9, 0.28, 0.035, 0.25],
	[7, 0.5, 0.03, 0.35],
	[14, 0.38, 0.04, 0.3],
	[5, 0.7, 0.025, 0.5],
]

func _ready() -> void:
	if scatter_on_ready:
		await get_tree().physics_frame
		await get_tree().physics_frame
		scatter()

func clear() -> void:
	for c in _chunks:
		c.queue_free()
	_chunks.clear()

func scatter() -> Dictionary:
	clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var space := get_world_3d().direct_space_state
	var dens := density
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	if graphics and "vegetation_density" in graphics:
		dens *= float(graphics.vegetation_density)
	elif graphics and int(graphics.preset) == 0:
		dens *= low_quality_density_scale
	var count := int(area_size.x * area_size.y * dens)
	stats = {"candidates": count, "accepted": 0, "no_hit": 0, "slope": 0, "underwater": 0, "overlap": 0, "no_grass": 0, "dynamic": 0}
	var min_up := cos(deg_to_rad(max_slope_deg))
	var waters := get_tree().get_nodes_in_group("water_volume")
	var sphere := SphereShape3D.new()
	sphere.radius = overlap_radius
	var shape_q := PhysicsShapeQueryParameters3D.new()
	shape_q.shape = sphere
	shape_q.collision_mask = overlap_mask
	shape_q.collide_with_areas = false
	var buckets := {}  # Vector3i(cx, cz, variant) -> Array[Transform3D]
	var customs := {}
	for i in count:
		var local := Vector3(rng.randf_range(-0.5, 0.5) * area_size.x, 0, rng.randf_range(-0.5, 0.5) * area_size.y)
		var origin := global_transform * local
		var q := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * ray_height, origin - Vector3.UP * ray_depth, ground_mask)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			stats.no_hit += 1
			continue
		var n: Vector3 = hit.normal
		if n.y < min_up:
			stats.slope += 1
			continue
		var collider: Object = hit.collider
		if collider is RigidBody3D or collider is CharacterBody3D or collider is AnimatableBody3D:
			stats.dynamic += 1  # never plant on moving props/characters
			continue
		if collider is Node and (collider as Node).is_in_group("no_grass"):
			stats.no_grass += 1
			continue
		var p: Vector3 = hit.position
		var wet := false
		for w in waters:
			if w.has_method("contains_xz") and w.contains_xz(p) and p.y < w.get_level() + 0.05 and p.y > w.get_level() - w.depth - 2.0:
				wet = true
				break
		if wet:
			stats.underwater += 1
			continue
		shape_q.transform = Transform3D(Basis(), p + n * (overlap_radius + 0.06))
		shape_q.exclude = [hit.rid]
		if not space.intersect_shape(shape_q, 1).is_empty():
			stats.overlap += 1
			continue
		var variant := rng.randi_range(0, VARIATIONS.size() - 1)
		var up := Vector3.UP.lerp(n, 0.6).normalized()
		var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var xf := Transform3D(basis.scaled(Vector3.ONE * s), p)
		var key := Vector3i(floori(p.x / chunk_size), floori(p.z / chunk_size), variant)
		if not buckets.has(key):
			buckets[key] = []
			customs[key] = []
		buckets[key].append(xf)
		customs[key].append(Color(rng.randf(), clampf(rng.randfn(0.25, 0.2), 0.0, 1.0), rng.randf(), 0))
		stats.accepted += 1
	_ensure_material()
	var meshes := []
	for v in VARIATIONS:
		meshes.append(build_clump_mesh(v[0], v[1], v[2], v[3], 99 + meshes.size()))
	for key in buckets:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[key.z]
		var list: Array = buckets[key]
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, global_transform.affine_inverse() * list[j])
			mm.set_instance_custom_data(j, customs[key][j])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Grass_%d_%d_v%d" % [key.x, key.y, key.z]
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = visibility_end
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		add_child(mmi)
		_chunks.append(mmi)
	stats["chunks"] = _chunks.size()
	return stats

static func _ensure_material() -> void:
	if _material:
		return
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass_wind.gdshader")
	WindSystem.register_material(_material)

## A clump of tapered, curved blades. COLOR.r = normalized height (drives sway/tint).
static func build_clump_mesh(blades: int, height: float, width: float, lean: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 4
	for b in blades:
		var ang := rng.randf() * TAU
		var root := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.0, 0.12)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face))
		var lean_dir := Vector3(-side.z, 0, side.x) * (1 if rng.randf() > 0.5 else -1)
		var h := height * rng.randf_range(0.7, 1.15)
		var l := lean * rng.randf_range(0.5, 1.2)
		var nrm := lean_dir.cross(side).normalized()
		if nrm.y < 0: nrm = -nrm
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var c0 := root + lean_dir * l * h * t0 * t0 + Vector3.UP * h * t0
			var c1 := root + lean_dir * l * h * t1 * t1 + Vector3.UP * h * t1
			var w0 := width * (1.0 - t0 * 0.92) * 0.5
			var w1 := width * (1.0 - t1 * 0.92) * 0.5
			var v := [c0 - side * w0, c0 + side * w0, c1 + side * w1, c1 - side * w1]
			var hs := [t0, t0, t1, t1]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(hs[idx], 0, 0))
				st.set_normal((nrm + Vector3.UP * 0.6).normalized())
				st.set_uv(Vector2(0.5, 1.0 - hs[idx]))
				st.add_vertex(v[idx])
	return st.commit()

func set_graphics_quality(_preset: int) -> void:
	# Density is decided at scatter time; re-scatter to apply.
	if is_inside_tree() and not _chunks.is_empty():
		scatter()
