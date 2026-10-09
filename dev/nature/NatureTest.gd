extends Node3D
## DEV ONLY wind & nature test bed. Not referenced by the campaign.
## Large/small Tripo trees, procedural trees (plain colours: easy to judge rooting), a forest row
## (desync check), grass, bushes, ferns, vines, falling leaves, and a walking player.
## Keys: 1 CALM  2 BREEZE  3 MODERATE  4 STRONG  5 STORM  6 CAVE
## Run: godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3
##      --resolution 1280x720 res://dev/nature/NatureTest.tscn -- --quality=1

const TREE_GLB := "res://assets/environment/jungle/jungle_tree.glb"
const FERN_GLB := "res://assets/environment/jungle/jungle_fern.glb"
const FoliageWindScript := preload("res://systems/FoliageWind.gd")

var player: Player
var camera_rig: CameraController
var leaves
var grass: GrassScatter
var hud: Label
var plants := {}  # name -> Node3D

func _ready() -> void:
	_environment()
	_ground()
	_trees()
	_forest_row()
	_bushes_and_ferns()
	_vines()
	grass = GrassScatter.new()
	grass.name = "Grass"
	grass.area_size = Vector2(16, 12)
	grass.density = 9.0
	grass.position = Vector3(7, 0, 0)
	add_child(grass)
	leaves = preload("res://systems/nature/FallingLeaves.gd").new()
	leaves.name = "FallingLeaves"
	leaves.area_size = Vector3(26, 3, 22)
	leaves.position = Vector3(12, 8.5, 0)
	add_child(leaves)
	_spawn_player()
	_hud()
	WindSystem.set_preset(WindSystem.Preset.BREEZE, 0.0, Vector2(1, 0.3))
	WindSystem.driver().wind_changed.connect(_on_wind_changed)

func _on_wind_changed(s: float, d: Vector2, turb: float, storm: float) -> void:
	if hud:
		hud.text = "Wind %s  strength %.2f  dir (%.2f, %.2f)  turb %.2f  storm %.2f  detail %d\n1 CALM  2 BREEZE  3 MODERATE  4 STRONG  5 STORM  6 CAVE" % [
			WindSystem.PRESET_NAMES[WindSystem.current_preset] if WindSystem.current_preset >= 0 else "-", s, d.x, d.y, turb, storm, WindSystem.detail]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < WindSystem.PRESET_NAMES.size():
			WindSystem.set_preset(idx, 3.0)

# --- world -----------------------------------------------------------------

func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.52, 0.72)
	sm.sky_horizon_color = Color(0.7, 0.76, 0.78)
	sm.ground_horizon_color = Color(0.45, 0.47, 0.4)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90, 1, 90)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	mi.mesh = pm
	mi.material_override = _mat(Color(0.24, 0.27, 0.15))
	body.add_child(mi)
	add_child(body)

func _trunk_collider(parent: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "TrunkCollision"
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	cs.position.y = height * 0.5
	body.add_child(cs)
	parent.add_child(body)

func _attach_wind(plant: Node3D, profile: String, untextured := false) -> void:
	var aabb := _aabb(plant)
	var wind = FoliageWindScript.new()
	wind.name = "FoliageWind"
	wind.accept_untextured = untextured
	plant.add_child(wind)
	wind.configure(plant, aabb.size.y, aabb.position.y, profile)

func _aabb(plant: Node3D) -> AABB:
	var out := AABB()
	for vi in plant.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = vi.global_transform * vi.get_aabb()
		out = a if out.size == Vector3.ZERO else out.merge(a)
	return out

func _glb(path: String, pos: Vector3, height: float, yaw: float, label: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.name = label
	add_child(n)
	var a := _aabb(n)
	var s := height / maxf(a.size.y, 0.01)
	n.scale = Vector3.ONE * s
	n.rotation.y = yaw
	n.global_position = pos - Vector3(0, a.position.y * s, 0)
	plants[label] = n
	return n

func _trees() -> void:
	var big := [[Vector3(15, 0, 7), 11.0], [Vector3(20, 0, -6), 9.5], [Vector3(-4, 0, 9), 10.0]]
	for i in big.size():
		var t := _glb(TREE_GLB, big[i][0], big[i][1], i * 1.7, "BigTree%d" % i)
		_attach_wind(t, "tree")
		_trunk_collider(t, 0.4 / t.scale.x, 3.0 / t.scale.x)
	var small := [[Vector3(4, 0, 6), 4.0], [Vector3(10, 0, -6.5), 3.5]]
	for i in small.size():
		var t := _glb(TREE_GLB, small[i][0], small[i][1], 0.8 + i, "SmallTree%d" % i)
		_attach_wind(t, "tree")
	for i in 2:
		var pt := _proc_tree(Vector3(9 + i * 9, 0, 9.5 - i * 19), 6.5 + i, 7 + i)
		pt.name = "ProcTree%d" % i
		plants[pt.name] = pt
		_attach_wind(pt, "tree", true)

func _forest_row() -> void:
	for i in 8:
		var pt := _proc_tree(Vector3(-2 + i * 4.2, 0, -16 + (i % 2) * 1.5), 5.0 + (i % 3) * 0.6, 100 + i)
		pt.name = "Row%d" % i
		plants[pt.name] = pt
		_attach_wind(pt, "tree", true)

## Plain-colour tree: tapered trunk, 4-5 branches, leaf-card clusters at the branch ends.
func _proc_tree(pos: Vector3, h: float, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09 * h / 6.0
	cm.bottom_radius = 0.2 * h / 6.0
	cm.height = h * 0.75
	cm.radial_segments = 10
	cm.rings = 8
	trunk.mesh = cm
	trunk.position.y = h * 0.375
	trunk.material_override = null
	cm.material = _mat(Color(0.33, 0.24, 0.16))
	root.add_child(trunk)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var branch_st := SurfaceTool.new()
	branch_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := rng.randi_range(4, 5)
	for b in n:
		var ang := TAU * b / n + rng.randf_range(-0.3, 0.3)
		var y0 := h * rng.randf_range(0.42, 0.62)
		var reach := h * rng.randf_range(0.22, 0.32)
		var tip := Vector3(cos(ang) * reach, y0 + reach * 0.55, sin(ang) * reach)
		_branch(branch_st, Vector3(0, y0, 0), tip, 0.05 * h / 6.0)
		_leaf_cluster(st, rng, tip, h * 0.17, 70)
	_leaf_cluster(st, rng, Vector3(0, h * 0.8, 0), h * 0.2, 90)
	var bm := MeshInstance3D.new()
	branch_st.generate_normals()
	bm.mesh = branch_st.commit()
	bm.material_override = null
	bm.mesh.surface_set_material(0, _mat(Color(0.3, 0.22, 0.15)))
	root.add_child(bm)
	var lm := MeshInstance3D.new()
	lm.mesh = st.commit()
	var leaf_mat := _mat(Color(0.3, 0.48, 0.16))
	lm.mesh.surface_set_material(0, leaf_mat)
	root.add_child(lm)
	_trunk_collider(root, cm.bottom_radius, h * 0.75)
	return root

func _branch(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var ax := (b - a).normalized()
	var u := ax.cross(Vector3.UP).normalized()
	if u.length() < 0.1:
		u = Vector3.RIGHT
	var v := ax.cross(u).normalized()
	var seg := 6
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var o0 := (u * cos(a0) + v * sin(a0))
		var o1 := (u * cos(a1) + v * sin(a1))
		var p := [a + o0 * r, a + o1 * r, b + o1 * r * 0.4, b + o0 * r * 0.4]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(p[idx])

## Random leaf cards in a sphere; normals biased outward/up so cards read as a lit canopy.
func _leaf_cluster(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, radius: float, count: int, size := 0.0) -> void:
	var leaf := size if size > 0.0 else radius * 0.32
	for i in count:
		var dir := Vector3(rng.randfn(), rng.randfn() * 0.7, rng.randfn()).normalized()
		var p := c + dir * radius * pow(rng.randf(), 0.4)
		var n := (dir + Vector3.UP * 0.6).normalized()
		var t := n.cross(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)).normalized()
		var bt := n.cross(t)
		var w := leaf * rng.randf_range(0.6, 1.1)
		var q := [p - t * w * 0.5, p + t * w * 0.5, p + t * w * 0.35 + bt * w, p - t * w * 0.35 + bt * w]
		var shade := rng.randf_range(0.75, 1.15)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(shade, shade, shade))
			st.set_normal(n)
			st.add_vertex(q[idx])

func _bushes_and_ferns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var spots := [Vector3(4.5, 0, 1.6), Vector3(7.5, 0, -1.3), Vector3(10.5, 0, 1.2), Vector3(13, 0, -0.4)]
	for i in spots.size():
		var root := Node3D.new()
		root.name = "Bush%d" % i
		add_child(root)
		root.global_position = spots[i]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 4:
			var off := Vector3(rng.randf_range(-0.35, 0.35), 0.45 + rng.randf() * 0.25, rng.randf_range(-0.35, 0.35))
			_leaf_cluster(st, rng, off, 0.5, 60, 0.18)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.mesh.surface_set_material(0, _mat(Color(0.22, 0.4, 0.13)))
		root.add_child(mi)
		plants[root.name] = root
		_attach_wind(root, "bush", true)
	var fspots := [Vector3(5.5, 0, -2.4), Vector3(9, 0, 2.6), Vector3(12, 0, -2.2), Vector3(2.5, 0, -1.5)]
	for i in fspots.size():
		var f := _glb(FERN_GLB, fspots[i], 1.1, i * 2.1, "Fern%d" % i)
		_attach_wind(f, "fern")

func _vines() -> void:
	# A stone lintel on two posts at x=16; vines hang from it (pinned at the top).
	var lintel := Vector3(16.5, 3.6, 0)
	for z in [-1.6, 1.6]:
		var post := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.4, 3.6, 0.4)
		cs.shape = bx
		post.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bx.size
		mi.mesh = bm
		mi.material_override = _mat(Color(0.5, 0.48, 0.44))
		post.add_child(mi)
		post.position = Vector3(lintel.x, 1.8, z)
		add_child(post)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.5, 0.35, 3.8)
	top.mesh = tb
	top.material_override = _mat(Color(0.5, 0.48, 0.44))
	top.position = lintel + Vector3(0, 0.15, 0)
	add_child(top)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6:
		var root := Node3D.new()
		root.name = "Vine%d" % i
		add_child(root)
		var z := -1.2 + i * 0.48
		var length := rng.randf_range(1.6, 2.9)
		root.global_position = Vector3(lintel.x - 0.22, lintel.y - length, z)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := int(length / 0.12)
		for k in steps:
			var y := length - k * 0.12
			var c := Vector3(sin(k * 0.7 + i) * 0.04, y, 0)
			_leaf_cluster(st, rng, c, 0.07, 3, 0.11)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.mesh.surface_set_material(0, _mat(Color(0.2, 0.38, 0.12)))
		root.add_child(mi)
		plants[root.name] = root
		_attach_wind(root, "vine", true)

func _spawn_player() -> void:
	player = (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.05, 0)
	camera_rig = CameraController.new()
	camera_rig.name = "CameraController"
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 3.5
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	arm.add_child(cam)
	camera_rig.add_child(arm)
	camera_rig.target = player
	camera_rig.yaw = -PI * 0.5
	player.camera_pivot = camera_rig
	player.spring_arm = arm
	add_child(player)
	add_child(camera_rig)

func _hud() -> void:
	var layer := CanvasLayer.new()
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)
	add_child(layer)
