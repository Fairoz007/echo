extends Node3D
## Procedural limestone cave: irregular shell (walls + bedded ceiling), blended ground,
## speleothems, pebble scatter, rockfall and end caps. Profile keys control
## compression/expansion and chamber height along the route (-Z is forward).
## All generated solids receive collision here; the EnvironmentCollision pass skips them.

@export var profile_z := PackedFloat32Array([7, 3, -1, -4, -7, -10, -14, -17, -19, -22, -25, -29, -33])
@export var profile_w := PackedFloat32Array([2.8, 3.2, 2.5, 2.0, 3.4, 6.0, 6.4, 4.0, 2.4, 2.9, 4.6, 5.0, 3.6])
@export var profile_h := PackedFloat32Array([3.0, 3.4, 2.8, 2.6, 4.2, 9.5, 11.0, 6.0, 3.0, 3.4, 6.5, 7.0, 4.2])
@export var start_z := 7.0
@export var end_z := -33.0
@export var slice_step := 0.33
@export var seed_value := 4127
@export var stalactite_count := 70
@export var stalagmite_count := 22
@export var pebble_count := 900
@export var vein_start_z := -20.0 ## Vaelor veins fade in toward the portal
@export var route_clear := 1.15
@export var cap_far := true ## false: open far end (daylight exit) ## keep |x| < route_clear free of floor speleothems

const ROCK_SHADER := preload("res://materials/cave_rock.gdshader")
const GROUND_SHADER := preload("res://materials/cave_ground.gdshader")
const WALL_TEX := "res://assets/environment/cave/cave_wall_limestone_Color_e63e799a-2e6c-41d4-966d-f77e80cd4719.jpg"
const WALL_NRM := "res://assets/environment/cave/cave_wall_limestone_NormalGL_e63e799a-2e6c-41d4-966d-f77e80cd4719.png"
const FLOOR_TEX := "res://assets/environment/cave/cave_floor_sediment_Color_9ebda37d-24d2-422f-b7e2-13565bd3ab05.jpg"
const FLOOR_NRM := "res://assets/environment/cave/cave_floor_sediment_NormalGL_9ebda37d-24d2-422f-b7e2-13565bd3ab05.png"

const WALL_ROWS := 18
var CEIL_COLS := 16 ## auto-scaled with the widest section

@export var ground_step := 0.0 ## 0 = auto (0.28 m in tunnels, coarser in halls)
@export var hole_rects: Array[Rect2] = [] ## XZ holes in the ground (chasms); pits are walled
@export var pit_depth := 22.0
@export var avoid_rects: Array[Rect2] = [] ## XZ areas kept free of speleothems (gameplay, rooms)
@export var stalagmite_band := 6.0 ## stalagmites stay within this distance of the walls

var n_lump := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_fract := FastNoiseLite.new()
var n_ground := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var rock_material: ShaderMaterial
var plain_rock_material: ShaderMaterial ## for meshes without vertex colour
var ground_material: ShaderMaterial
var noise_texture: NoiseTexture2D
signal built
var is_built := false
var puddle_points: Array[Vector3] = []
## Wet zones near water: Marker3D nodes in group "cave_wet_zone" (meta "radius").
var wet_zones: Array[Vector4] = []

func _ready() -> void:
	build()

func build() -> void:
	rng.seed = seed_value
	for n in [n_lump, n_detail, n_fract, n_ground]:
		n.seed = seed_value + [n_lump, n_detail, n_fract, n_ground].find(n) * 17
	n_lump.frequency = 0.22
	n_lump.fractal_octaves = 3
	n_detail.frequency = 1.1
	n_detail.fractal_octaves = 2
	n_fract.frequency = 0.35
	n_fract.noise_type = FastNoiseLite.TYPE_PERLIN
	n_ground.frequency = 0.16
	n_ground.fractal_octaves = 3
	wet_zones.clear()
	if is_inside_tree():
		for m in get_tree().get_nodes_in_group("cave_wet_zone"):
			var p: Vector3 = m.global_position
			wet_zones.append(Vector4(p.x, p.y, p.z, float(m.get_meta("radius", 3.0))))
	var max_w := 0.0
	for v in profile_w:
		max_w = maxf(max_w, v)
	CEIL_COLS = clampi(int(max_w * 0.8), 16, 44)
	_make_materials()
	# Staged over frames to avoid a load hitch (shell/ground trimesh + scatter are the heavy parts).
	# One heavy stage per frame; set meta "profile_build" to print per-stage cost.
	_deferring_shapes = is_inside_tree()
	var stages := [_build_shell, _build_pits, _build_ground, _build_caps, _build_speleothems, _build_pebbles]
	for i in stages.size():
		var t := Time.get_ticks_usec()
		await stages[i].call()
		if has_meta("profile_build") or OS.get_cmdline_user_args().has("--profile-build"):
			print("[CaveBuilder] %s stage %d: %.0f ms" % [name, i, (Time.get_ticks_usec() - t) / 1000.0])
		if i < stages.size() - 1:
			await _yield()
		# Trimesh cooking for this stage's solids gets its own frame.
		while not _pending_shapes.is_empty():
			var job: Array = _pending_shapes.pop_front()
			if is_instance_valid(job[0]):
				var tc := Time.get_ticks_usec()
				job[0].shape = (job[1] as Mesh).create_trimesh_shape()
				if OS.get_cmdline_user_args().has("--profile-build"):
					print("[CaveBuilder] %s trimesh %s %.0f ms" % [name, job[0].get_parent().name, (Time.get_ticks_usec() - tc) / 1000.0])
			await _yield()
	_deferring_shapes = false
	is_built = true
	built.emit()

# ---------------------------------------------------------------- profile
func _key(arr: PackedFloat32Array, z: float) -> float:
	if z >= profile_z[0]:
		return arr[0]
	for i in range(profile_z.size() - 1):
		var z0 := profile_z[i]
		var z1 := profile_z[i + 1]
		if z <= z0 and z >= z1:
			var t := (z0 - z) / (z0 - z1)
			return lerpf(arr[i], arr[i + 1], t * t * (3.0 - 2.0 * t))
	return arr[arr.size() - 1]

func width_at(z: float) -> float:
	return _key(profile_w, z)

func height_at(z: float) -> float:
	return _key(profile_h, z)

## Signed recess (+ = into rock) for a wall at height y.
func _wall_disp(side: float, y: float, z: float) -> Vector2:
	var lump := n_lump.get_noise_3d(side * 11.0, y * 0.8, z) * 0.6
	var detail := n_detail.get_noise_3d(side * 7.0, y, z) * 0.12
	var bed := fposmod(y * 0.85 + n_lump.get_noise_2d(z, side * 3.0) * 1.2, 1.0)
	var parting := 0.16 * (1.0 - smoothstep(0.0, 0.12, bed))
	var f := absf(n_fract.get_noise_2d(z * 1.4 + side * 40.0, y * 0.12))
	var fracture := 0.55 * (1.0 - smoothstep(0.0, 0.07, f))
	# Ledges: inward shelves in tall chambers.
	var h := height_at(z)
	var ledge := 0.0
	if h > 5.0:
		for ly in [2.6, 5.2]:
			ledge += 0.55 * exp(-pow((y - ly - n_lump.get_noise_2d(z, side) * 0.4) / 0.32, 2.0)) * clampf((h - 5.0) / 2.0, 0.0, 1.0)
	var d := lump + detail + parting + fracture - ledge
	# Floor junction: walls flare inward slightly at the base (talus/flowstone).
	d -= 0.35 * (1.0 - smoothstep(0.0, 0.9, y))
	var cavity := clampf(parting * 3.0 + fracture * 1.6 + maxf(lump, 0.0) * 0.6, 0.0, 1.0)
	return Vector2(d, cavity)

func _ceil_y(x: float, z: float) -> float:
	var h := height_at(z)
	var w := width_at(z)
	var u := clampf(absf(x) / maxf(w, 0.1), 0.0, 1.2)
	# Bedded limestone roof: flattish slab, stepped by bedding, sagging toward walls.
	var y := h - 0.35 * u * u * h * 0.25
	y += n_lump.get_noise_2d(x * 0.6, z * 0.6) * 0.45
	var step := n_fract.get_noise_2d(x * 0.3, z * 0.3)
	y += 0.35 if step > 0.15 else 0.0
	y += n_detail.get_noise_2d(x * 2.0, z * 2.0) * 0.08
	return y

func wall_x(side: float, y: float, z: float) -> float:
	var w := width_at(z)
	var lean := n_lump.get_noise_2d(z * 0.5, side * 9.0) * 0.18 * y
	return side * (w + lean + _wall_disp(side, y, z).x)

func floor_clear_x(z: float) -> float:
	## Conservative inner limit of the walls near the floor.
	return width_at(z) - 0.9

# ---------------------------------------------------------------- materials
func _make_materials() -> void:
	noise_texture = NoiseTexture2D.new()
	var nn := FastNoiseLite.new()
	nn.seed = seed_value
	nn.frequency = 0.012
	nn.fractal_octaves = 5
	noise_texture.noise = nn
	noise_texture.seamless = true
	noise_texture.width = 512
	noise_texture.height = 512
	var normal_noise := NoiseTexture2D.new()
	var nn2 := FastNoiseLite.new()
	nn2.seed = seed_value + 3
	nn2.frequency = 0.03
	nn2.fractal_octaves = 4
	normal_noise.noise = nn2
	normal_noise.seamless = true
	normal_noise.as_normal_map = true
	normal_noise.bump_strength = 6.0
	normal_noise.width = 512
	normal_noise.height = 512
	rock_material = ShaderMaterial.new()
	rock_material.shader = ROCK_SHADER
	rock_material.set_shader_parameter("albedo_tex", load(WALL_TEX))
	rock_material.set_shader_parameter("normal_tex", normal_noise)
	rock_material.set_shader_parameter("noise_tex", noise_texture)
	plain_rock_material = rock_material.duplicate()
	plain_rock_material.set_shader_parameter("vertex_color_mix", 0.0)
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("sediment_tex", load(FLOOR_TEX))
	ground_material.set_shader_parameter("sediment_normal", load(FLOOR_NRM))
	ground_material.set_shader_parameter("rock_tex", load(WALL_TEX))
	ground_material.set_shader_parameter("noise_tex", noise_texture)

# ---------------------------------------------------------------- shell
func _vein(z: float) -> float:
	return clampf((vein_start_z - z) / 8.0, 0.0, 1.0)

func zone_wetness(p: Vector3) -> float:
	var w := 0.0
	for zone in wet_zones:
		var d := Vector2(p.x - zone.x, p.z - zone.z).length()
		w = maxf(w, 1.0 - smoothstep(zone.w * 0.5, zone.w, d))
	return w

func _wet(y: float, z: float) -> float:
	return clampf(1.0 - y / 0.8, 0.0, 1.0) * 0.7 + clampf(n_ground.get_noise_2d(z * 0.7, y * 0.2), 0.0, 1.0) * 0.4

func _build_shell() -> void:
	var arrays: Array = await _threaded(_with_faces.bind(_shell_arrays))
	if arrays.is_empty():
		return
	var t := Time.get_ticks_usec()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays[0])
	_add_solid("CaveShell", mesh, rock_material, true, arrays[1])
	if OS.get_cmdline_user_args().has("--profile-build"):
		print("[CaveBuilder] shell main-thread commit %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

## Pure CPU: runs on a WorkerThreadPool thread (no scene-tree / RenderingServer calls).
func _shell_arrays() -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices := int(ceil((start_z - end_z) / slice_step)) + 1
	var ring := WALL_ROWS * 2 + CEIL_COLS - 2
	for i in slices:
		var z := start_z - i * slice_step
		var pts: Array[Vector3] = []
		var cols: Array[Color] = []
		var lx_top := wall_x(-1.0, height_at(z) * 0.82, z)
		var rx_top := wall_x(1.0, height_at(z) * 0.82, z)
		var ly_top := _ceil_y(lx_top, z)
		var ry_top := _ceil_y(rx_top, z)
		for r in WALL_ROWS:
			var y := lerpf(-0.6, ly_top, float(r) / float(WALL_ROWS - 1))
			var x := wall_x(-1.0, y, z) if r < WALL_ROWS - 1 else lx_top
			var disp := _wall_disp(-1.0, y, z)
			pts.append(Vector3(x, y, z))
			cols.append(Color(disp.y, maxf(_wet(y, z), zone_wetness(Vector3(x, y, z))), _vein(z) * smoothstep(0.5, 2.5, y), 1))
		for c in range(1, CEIL_COLS - 1):
			var x := lerpf(lx_top, rx_top, float(c) / float(CEIL_COLS - 1))
			var y := _ceil_y(x, z)
			pts.append(Vector3(x, y, z))
			cols.append(Color(clampf(n_fract.get_noise_2d(x, z) * 1.5, 0.0, 1.0), 0.15, _vein(z) * 0.6, 1))
		for r in range(WALL_ROWS - 1, -1, -1):
			var y := lerpf(-0.6, ry_top, float(r) / float(WALL_ROWS - 1))
			var x := wall_x(1.0, y, z) if r < WALL_ROWS - 1 else rx_top
			var disp := _wall_disp(1.0, y, z)
			pts.append(Vector3(x, y, z))
			cols.append(Color(disp.y, maxf(_wet(y, z), zone_wetness(Vector3(x, y, z))), _vein(z) * smoothstep(0.5, 2.5, y), 1))
		for j in ring:
			st.set_color(cols[j])
			st.set_uv(Vector2(pts[j].z * 0.3, pts[j].y * 0.3 + pts[j].x * 0.3))
			st.add_vertex(pts[j])
	for i in slices - 1:
		for j in ring - 1:
			var a := i * ring + j
			var b := a + 1
			var c := a + ring
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	st.generate_tangents()
	return st.commit_to_arrays()

# ---------------------------------------------------------------- ground
func ground_y(x: float, z: float) -> float:
	var w := width_at(z)
	var ax := absf(x)
	var y := n_ground.get_noise_2d(x, z) * 0.12
	y *= lerpf(0.4, 1.0, smoothstep(0.6, 1.6, ax))
	y += smoothstep(w - 1.6, w + 0.4, ax) * 0.55 # talus toward walls
	y += maxf(n_detail.get_noise_2d(x * 0.5, z * 0.5), 0.0) * 0.25 * smoothstep(1.0, 2.0, ax)
	var p := _puddle(x, z)
	y -= p * 0.07
	return y

func in_hole(p: Vector2) -> bool:
	for r in hole_rects:
		if r.has_point(p):
			return true
	return false

func blocked(p: Vector2, margin := 0.6) -> bool:
	for r in hole_rects:
		if r.grow(margin).has_point(p):
			return true
	for r in avoid_rects:
		if r.grow(margin).has_point(p):
			return true
	return false

## Inward-facing rock walls + floor for each ground hole (chasm).
func _build_pits() -> void:
	for r in hole_rects:
		_vcount = 0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
		var rows := 12
		for side in 4:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side + 1) % 4]
			var inward := Vector2(-(b - a).y, (b - a).x).normalized() * -1.0
			var cols := maxi(4, int(a.distance_to(b) / 1.2))
			var base := st_vertex_count(st)
			for iy in rows + 1:
				var y := lerpf(-minf(0.35, pit_depth * 0.3), -pit_depth - 0.05, float(iy) / rows)
				for ix in cols + 1:
					var q := a.lerp(b, float(ix) / cols)
					var d := n_lump.get_noise_3d(q.x, y * 0.7, q.y) * 1.2 + n_detail.get_noise_3d(q.x, y, q.y) * 0.15
					var pos := Vector3(q.x - inward.x * d, y, q.y - inward.y * d)
					st.set_color(Color(clampf(-d, 0, 1), clampf(-y / pit_depth, 0, 1) * 0.6, 0, 1))
					st.add_vertex(pos)
			for iy in rows:
				for ix in cols:
					var i0 := base + iy * (cols + 1) + ix
					var i1 := i0 + 1
					var i2 := i0 + cols + 1
					var i3 := i2 + 1
					st.add_index(i0); st.add_index(i2); st.add_index(i1)
					st.add_index(i1); st.add_index(i2); st.add_index(i3)
			_vcount += (rows + 1) * (cols + 1)
		st.generate_normals()
		var mi := _add_solid("ChasmWalls", st.commit(), rock_material, true)
		mi.set_meta("cull_check", true)

var _vcount := 0
func st_vertex_count(_st: SurfaceTool) -> int:
	return _vcount

func _puddle(x: float, z: float) -> float:
	var v := n_ground.get_noise_2d(x * 1.3 + 50.0, z * 1.3)
	return smoothstep(0.18, 0.32, v) * (1.0 - smoothstep(1.4, 2.2, absf(x)))

func _build_ground() -> void:
	var arrays: Array = await _threaded(_with_faces.bind(_ground_arrays))
	if arrays.is_empty():
		return
	var ground_mesh := ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays[0])
	_add_solid("CaveGround", ground_mesh, ground_material, true, arrays[1])
	# Water placeholder markers for the water system (systems/water/).
	var markers := Node3D.new()
	markers.name = "WaterPlaceholders"
	add_child(markers)
	for p in puddle_points:
		var m := Marker3D.new()
		m.position = p + Vector3.UP * 0.01
		m.add_to_group("water_placeholder")
		m.set_meta("kind", "puddle")
		markers.add_child(m)

## Pure CPU: runs on a WorkerThreadPool thread. Fills puddle_points.
func _ground_arrays() -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var max_w := 0.0
	for v in profile_w:
		max_w = maxf(max_w, v)
	var half := max_w + 3.0
	var step := ground_step if ground_step > 0.0 else clampf(half / 32.0, 0.28, 0.7)
	var nx := int(half * 2.0 / step) + 1
	var nz := int(ceil((start_z - end_z) / step)) + 1
	for iz in nz:
		var z := start_z - iz * step
		var w := width_at(z)
		for ix in nx:
			var x := -half + ix * step
			var y := ground_y(x, z)
			var ax := absf(x)
			var gravel := clampf(smoothstep(w - 2.0, w - 0.5, ax) + n_detail.get_noise_2d(x * 0.4, z * 0.4) * 0.6, 0.0, 1.0)
			var rock := clampf(smoothstep(w - 0.8, w + 0.3, ax) + maxf(n_fract.get_noise_2d(x * 0.8, z * 0.8) - 0.3, 0.0) * 2.0, 0.0, 1.0)
			var p := _puddle(x, z)
			var mud := clampf(p * 1.4 + maxf(n_ground.get_noise_2d(x * 0.7 - 20.0, z * 0.7), 0.0) * 1.2, 0.0, 1.0)
			var zw := zone_wetness(Vector3(x, y, z))
			st.set_color(Color(gravel * (1.0 - zw * 0.5), maxf(mud, zw), maxf(p, zw * 0.3), rock))
			st.set_uv(Vector2(x, z) * 0.4)
			st.add_vertex(Vector3(x, y, z))
			if p > 0.9 and rng.randf() < 0.05:
				puddle_points.append(Vector3(x, y, z))
	for iz in nz - 1:
		for ix in nx - 1:
			if in_hole(Vector2(-half + (ix + 0.5) * step, start_z - (iz + 0.5) * step)):
				continue
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	st.generate_tangents()
	return st.commit_to_arrays()

# ---------------------------------------------------------------- caps (rockfall + far wall)
func _build_caps() -> void:
	for cap in ([[start_z, 1.0], [end_z, -1.0]] if cap_far else [[start_z, 1.0]]):
		var z: float = cap[0]
		var dir: float = cap[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w := width_at(z) + 1.0
		var h := height_at(z) + 1.0
		var res := 14
		for iy in res:
			for ix in res:
				var x := lerpf(-w, w, float(ix) / (res - 1))
				var y := lerpf(-0.6, h, float(iy) / (res - 1))
				var bulge := n_lump.get_noise_2d(x, y + z) * 0.8 - 0.5
				st.set_color(Color(clampf(bulge + 0.5, 0, 1), 0.2, 0, 1))
				st.add_vertex(Vector3(x, y, z - dir * bulge))
		for iy in res - 1:
			for ix in res - 1:
				var a := iy * res + ix
				var b := a + 1
				var c := a + res
				var d := c + 1
				if dir > 0.0: # faces -Z (toward the route)
					st.add_index(a); st.add_index(c); st.add_index(b)
					st.add_index(b); st.add_index(c); st.add_index(d)
				else:
					st.add_index(a); st.add_index(b); st.add_index(c)
					st.add_index(b); st.add_index(d); st.add_index(c)
		st.generate_normals()
		_add_solid("Cap_%s" % ("Rockfall" if dir > 0 else "Far"), st.commit(), rock_material, true)

# ---------------------------------------------------------------- speleothems
func _spike_mesh(radius: float, length: float, down: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var segs := 7
	var wobble := rng.randf() * 10.0
	for r in rings + 1:
		var t := float(r) / rings
		var rad := radius * pow(1.0 - t, 1.35) + 0.01
		var y := t * length * (-1.0 if down else 1.0)
		for s in segs:
			var ang := TAU * s / segs
			var k := 1.0 + n_detail.get_noise_2d(ang * 3.0 + wobble, t * 4.0) * 0.35
			var off := Vector3(n_lump.get_noise_1d(wobble + t * 3.0), 0, n_lump.get_noise_1d(wobble - t * 3.0)) * radius * 0.6 * t
			st.set_color(Color(0.15 + t * 0.2, 0.55 if down else 0.3, 0, 1))
			st.add_vertex(Vector3(cos(ang) * rad * k, y, sin(ang) * rad * k) + off)
	for r in rings:
		for s in segs:
			var a := r * segs + s
			var b := r * segs + (s + 1) % segs
			var c := a + segs
			var d := b + segs
			if down:
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(b); st.add_index(c); st.add_index(d)
			else:
				st.add_index(a); st.add_index(b); st.add_index(c)
				st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	return st.commit()

func _build_speleothems() -> void:
	var root := Node3D.new()
	root.name = "Speleothems"
	add_child(root)
	var placed := 0
	var tries := 0
	while placed < stalactite_count and tries < stalactite_count * 6:
		tries += 1
		var z := rng.randf_range(end_z + 1.0, start_z - 1.5)
		var w := width_at(z)
		var x := rng.randf_range(-w * 0.8, w * 0.8)
		var h := height_at(z)
		var cy := _ceil_y(x, z)
		var length := rng.randf_range(0.25, 1.0) * clampf(h / 3.5, 0.5, 2.6)
		if cy - length < 2.35 and absf(x) < 1.6:
			continue # keep the walking/camera route clear
		if cy - length < 3.0 and blocked(Vector2(x, z)):
			continue
		# Clusters along fractures look more natural than uniform scatter.
		var count := 1 + (rng.randi() % 3)
		for k in count:
			var mi := MeshInstance3D.new()
			mi.name = "Stalactite_%d" % placed
			mi.mesh = _spike_mesh(rng.randf_range(0.06, 0.2) * (1.0 + length * 0.3), length * rng.randf_range(0.5, 1.0), true)
			mi.material_override = rock_material
			mi.set_meta("collision", "none") # overhead, unreachable
			mi.position = Vector3(x + rng.randf_range(-0.3, 0.3), cy + 0.25, z + rng.randf_range(-0.3, 0.3))
			root.add_child(mi)
		placed += 1
	placed = 0
	tries = 0
	while placed < stalagmite_count and tries < stalagmite_count * 8:
		tries += 1
		var z := rng.randf_range(end_z + 2.0, start_z - 2.0)
		var limit := floor_clear_x(z)
		if limit < route_clear + 0.4:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * rng.randf_range(maxf(route_clear + 0.3, limit - stalagmite_band), limit)
		if blocked(Vector2(x, z), 1.0):
			continue
		var length := rng.randf_range(0.35, 1.6) * clampf(height_at(z) / 4.0, 0.6, 1.8)
		var radius := rng.randf_range(0.12, 0.32) * (0.8 + length * 0.4)
		var body := StaticBody3D.new()
		body.name = "Stalagmite_%d" % placed
		body.position = Vector3(x, ground_y(x, z) - 0.08, z)
		root.add_child(body)
		var mi := MeshInstance3D.new()
		mi.mesh = _spike_mesh(radius, length, false)
		mi.material_override = rock_material
		body.add_child(mi)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius * 0.8
		cyl.height = length * 0.7
		shape.shape = cyl
		shape.position.y = cyl.height * 0.5
		body.add_child(shape)
		placed += 1

# ---------------------------------------------------------------- pebble scatter
func _rock_mesh(radius: float, roughness: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.4
	sphere.radial_segments = 8
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var offset := rng.randf() * 100.0
	for i in verts.size():
		var v := verts[i]
		var k := 1.0 + n_detail.get_noise_3d(v.x * 6.0 + offset, v.y * 6.0, v.z * 6.0) * roughness
		verts[i] = Vector3(v.x * k, maxf(v.y * k, -radius * 0.25), v.z * k)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var colors := PackedColorArray()
	for v in verts:
		colors.append(Color(clampf(0.5 - v.y / radius, 0.0, 0.8), 0.25, 0.0, 1.0))
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.generate_normals()
	return st.commit()

func _build_pebbles() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _rock_mesh(0.12, 0.6)
	mm.instance_count = pebble_count
	for i in pebble_count:
		var z := rng.randf_range(end_z + 0.5, start_z - 0.5)
		var w := width_at(z)
		# Bias toward the walls (rubble) but allow some on the path.
		var t := pow(rng.randf(), 0.6)
		var x := (-1.0 if rng.randf() < 0.5 else 1.0) * t * (w - 0.3)
		if in_hole(Vector2(x, z)):
			x = -x
		var s := rng.randf_range(0.25, 1.4) * (0.6 + t * 0.9)
		var basis := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)).scaled(Vector3(s, s * rng.randf_range(0.5, 1.0), s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, ground_y(x, z) + 0.01, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PebbleScatter"
	mmi.multimesh = mm
	mmi.material_override = rock_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## Worker-side: builds surface arrays plus the expanded triangle list for collision, so
## the main thread never reads the mesh back from the GPU (get_faces() is a GL readback
## on the Compatibility renderer).
func _with_faces(builder: Callable) -> Array:
	var arrays: Array = builder.call()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var faces := PackedVector3Array()
	if idx.is_empty():
		faces = verts
	else:
		faces.resize(idx.size())
		for i in idx.size():
			faces[i] = verts[idx[i]]
	return [arrays, faces]

## Runs a pure-CPU builder on a worker thread while the main thread keeps rendering.
## Outside the tree (tools/tests) it runs inline.
var _task_id := -1
func _threaded(work: Callable) -> Variant:
	if not is_inside_tree():
		return work.call()
	var result := []
	var t0 := Time.get_ticks_usec()
	_task_id = WorkerThreadPool.add_task(func(): result.append(work.call()), false, "CaveBuilder")
	while not WorkerThreadPool.is_task_completed(_task_id):
		await get_tree().process_frame
		if not is_inside_tree():
			break
	var t1 := Time.get_ticks_usec()
	WorkerThreadPool.wait_for_task_completion(_task_id)
	if OS.get_cmdline_user_args().has("--profile-build"):
		print("[CaveBuilder] worker %.0f ms wall, join %.0f ms" % [(t1 - t0) / 1000.0, (Time.get_ticks_usec() - t1) / 1000.0])
	_task_id = -1
	return result[0] if not result.is_empty() else []

func _notification(what: int) -> void:
	# Never free the builder while a worker still reads its noise/profile members.
	if what == NOTIFICATION_PREDELETE and _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

func _yield() -> void:
	if is_inside_tree():
		await get_tree().process_frame

## Cached unit rocks: convex hulls are expensive, so a few variants are built once per
## builder and reused with a uniform scale.
var _rock_cache: Array = []
func _cached_rock() -> Array:
	if _rock_cache.size() < 6:
		var m := _rock_mesh(1.0, 0.45)
		var entry := [m, m.create_convex_shape(true, false)] # simplify=true cost ~40 ms per hull
		_rock_cache.append(entry)
		return entry
	return _rock_cache[rng.randi() % _rock_cache.size()]

## Builds a rubble pile of irregular rocks with convex collision (used for rockfall).
func add_rock(parent: Node3D, pos: Vector3, radius: float, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "RockfallRock"
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	var cached := _cached_rock()
	var mi := MeshInstance3D.new()
	mi.mesh = cached[0]
	mi.material_override = rock_material
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = cached[1]
	body.add_child(shape)
	body.scale = Vector3.ONE * radius # uniform body scale: safe for Jolt/Godot physics
	return body

# ---------------------------------------------------------------- helpers
var _pending_shapes: Array = []
var _deferring_shapes := false

func _add_solid(label: String, mesh: ArrayMesh, material: Material, collide: bool, faces := PackedVector3Array()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = material
	if collide and not _has_area_faces(mesh, faces):
		# Jolt rejects concave shapes with only degenerate triangles ("Need triangles to create a mesh shape!").
		push_warning("CaveBuilder: %s has no non-degenerate triangles; skipping collision" % label)
		collide = false
	if collide:
		var body := StaticBody3D.new()
		body.name = label + "Body"
		body.collision_layer = 1
		add_child(body)
		body.add_child(mi)
		var shape := CollisionShape3D.new()
		# Ground collision stays immediate so the player never spawns over a hole.
		if not faces.is_empty():
			var concave := ConcavePolygonShape3D.new()
			concave.set_faces(faces)
			shape.shape = concave
		elif _deferring_shapes and label != "CaveGround":
			_pending_shapes.append([shape, mesh])
		else:
			shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
	else:
		add_child(mi)
	return mi

func _has_area_faces(mesh: Mesh, known := PackedVector3Array()) -> bool:
	var faces := known if not known.is_empty() else mesh.get_faces()
	for i in range(0, faces.size() - 2, 3):
		if (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length_squared() > 1e-10:
			return true
	return false
