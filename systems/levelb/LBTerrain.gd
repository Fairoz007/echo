extends Node3D
## Level B heightfield terrain: one blended mesh + one concave collider + height queries.
## height_fn(x, z) -> float, mask_fn(x, z) -> Color (r path, g rock, b wet, a litter).

const SHADER := preload("res://systems/levelb/terrain_blend.gdshader")
const DETAIL := "res://assets/environment/cave/cave_floor_sediment_Color_9ebda37d-24d2-422f-b7e2-13565bd3ab05.jpg"
const DETAIL_N := "res://assets/environment/cave/cave_floor_sediment_NormalGL_9ebda37d-24d2-422f-b7e2-13565bd3ab05.png"
const ROCK := "res://assets/models/env_boulder_moss_Color_5f5a647b-546c-43b3-a3c5-a81652d3ce2e.jpg"

var origin := Vector2.ZERO
var size := Vector2(100, 100)
var step := 2.0
var cols := 0
var rows := 0
var heights := PackedFloat32Array()
var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var body: StaticBody3D

func build(p_origin: Vector2, p_size: Vector2, p_step: float, height_fn: Callable, mask_fn: Callable) -> void:
	origin = p_origin
	size = p_size
	step = p_step
	cols = int(ceil(size.x / step)) + 1
	rows = int(ceil(size.y / step)) + 1
	heights.resize(cols * rows)
	var masks: Array[Color] = []
	masks.resize(cols * rows)
	for j in rows:
		for i in cols:
			var x := origin.x + i * step
			var z := origin.y + j * step
			heights[j * cols + i] = height_fn.call(x, z)
			masks[j * cols + i] = mask_fn.call(x, z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows:
		for i in cols:
			var idx := j * cols + i
			var x := origin.x + i * step
			var z := origin.y + j * step
			var hl := heights[j * cols + maxi(i - 1, 0)]
			var hr := heights[j * cols + mini(i + 1, cols - 1)]
			var hd := heights[maxi(j - 1, 0) * cols + i]
			var hu := heights[mini(j + 1, rows - 1) * cols + i]
			st.set_normal(Vector3(hl - hr, 2.0 * step, hd - hu).normalized())
			st.set_color(masks[idx])
			st.set_uv(Vector2(x, z) * 0.25)
			st.add_vertex(Vector3(x, heights[idx], z))
	var faces := PackedVector3Array()
	for j in rows - 1:
		for i in cols - 1:
			var a := j * cols + i
			var b := a + 1
			var c := a + cols
			var d := c + 1
			# Split along the shorter diagonal for smoother ridges.
			if absf(heights[a] - heights[d]) < absf(heights[b] - heights[c]):
				for k in [a, b, d, a, d, c]:
					st.add_index(k)
			else:
				for k in [a, b, c, b, d, c]:
					st.add_index(k)
	st.generate_tangents()
	var arr_mesh := st.commit()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = arr_mesh
	mesh_instance.set_meta("collision", "none")
	mesh_instance.set_meta("keep_material", true)
	material = ShaderMaterial.new()
	material.shader = SHADER
	# Tripo textures are UV atlases (seams when tiled), so the ground uses seamless noise.
	var kit := preload("res://systems/levelb/LBKit.gd")
	material.set_shader_parameter("detail_tex", kit.noise_tex(0.02, 5, false, 0.0, 311))
	material.set_shader_parameter("detail_nrm", kit.noise_tex(0.035, 4, true, 5.0, 312))
	material.set_shader_parameter("rock_tex", kit.noise_tex(0.03, 3, false, 0.0, 313, true))
	mesh_instance.material_override = material
	add_child(mesh_instance)
	body = StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 3
	body.collision_mask = 0
	add_child(body)
	var shape := HeightMapShape3D.new()
	# HeightMapShape3D is centred and uses 1 unit per sample; scale the CollisionShape.
	shape.map_width = cols
	shape.map_depth = rows
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1, step)
	cs.position = Vector3(origin.x + (cols - 1) * step * 0.5, 0, origin.y + (rows - 1) * step * 0.5)
	body.add_child(cs)

func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / step, 0.0, cols - 1.001)
	var fz := clampf((z - origin.y) / step, 0.0, rows - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := heights[j * cols + i]
	var h10 := heights[j * cols + i + 1]
	var h01 := heights[(j + 1) * cols + i]
	var h11 := heights[(j + 1) * cols + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
