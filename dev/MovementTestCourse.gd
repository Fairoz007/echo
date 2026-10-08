extends Node3D
## DEV ONLY movement test course. Not referenced by the campaign.
## Each obstacle sits in its own lane (z) with the start point at x = 0 and the
## obstacle face at x = 4, so tests run Mara along +X.

const LANE := {
	"flat": -14.0, "step_015": 0.0, "step_030": 7.0, "step_050": 14.0, "stairs": 21.0,
	"slope_15": 28.0, "slope_30": 35.0, "slope_45": 42.0, "slope_60": 49.0, "wall": 56.0,
	"rock_small": 63.0, "rock_large": 70.0, "ledge": 77.0, "mantle_box": 84.0,
	"climb_wall": 91.0, "pool": 100.0, "cave": 116.0, "crawl": 123.0,
}
const WATER_SURFACE := 2.3

var player: Player
var camera_rig: CameraController
var _mats := {}

func _ready() -> void:
	_build_environment()
	_build_course()
	_spawn_player()

func lane_start(lane: String) -> Vector3:
	return Vector3(0, 0.02, LANE[lane])

func _mat(color: Color) -> StandardMaterial3D:
	if _mats.has(color):
		return _mats[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.2
	noise.seamless = true
	m.detail_enabled = true
	m.detail_albedo = noise
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	_mats[color] = m
	return m

func _box(name: String, size: Vector3, xform: Transform3D, color: Color, groups: Array = []) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 2
	body.collision_mask = 0
	body.transform = xform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat(color)
	body.add_child(mesh)
	for g in groups:
		body.add_to_group(g)
	add_child(body)
	return body

func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)

func _label(text: String, p: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = p
	l.font_size = 64
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = false # low-graphics rule: no shadows in dev captures
	add_child(sun)

func _build_course() -> void:
	var stone := Color(0.55, 0.55, 0.52)
	var accent := Color(0.75, 0.5, 0.3)
	_box("Ground", Vector3(120, 1, 200), _at(Vector3(20, -0.5, 50)), Color(0.35, 0.4, 0.33))
	# Steps
	for pair in [["step_015", 0.15], ["step_030", 0.30], ["step_050", 0.50]]:
		var h: float = pair[1]
		_box(pair[0], Vector3(3, h, 4), _at(Vector3(5.5, h * 0.5, LANE[pair[0]])), accent)
		_label("%s m step" % h, Vector3(2, 2.2, LANE[pair[0]]))
	# Stairs: 8 x 0.18 m rise, 0.30 m run
	for i in 8:
		var top := 0.18 * (i + 1)
		_box("Stair%d" % i, Vector3(0.3, top, 3), _at(Vector3(4.15 + 0.3 * i, top * 0.5, LANE.stairs)), stone)
	_box("StairTop", Vector3(3, 1.44, 3), _at(Vector3(4.0 + 2.4 + 1.5, 0.72, LANE.stairs)), stone)
	_label("stairs 0.18 rise", Vector3(2, 2.2, LANE.stairs))
	# Slopes
	for deg in [15, 30, 45, 60]:
		var a := deg_to_rad(float(deg))
		var length := 10.0
		var thick := 0.5
		var c := Vector2(4.0, 0.0) - Vector2(-length * 0.5 * cos(a) - thick * 0.5 * sin(a), -length * 0.5 * sin(a) + thick * 0.5 * cos(a))
		var basis := Basis(Vector3.BACK, a)
		_box("Slope%d" % deg, Vector3(length, thick, 4), Transform3D(basis, Vector3(c.x, c.y, LANE["slope_%d" % deg])), stone)
		_label("%d deg" % deg, Vector3(2, 2.2, LANE["slope_%d" % deg]))
	# Wall (too tall to mantle)
	_box("Wall", Vector3(1, 4, 6), _at(Vector3(4.5, 2, LANE.wall)), stone)
	_label("4 m wall", Vector3(2, 2.2, LANE.wall))
	# Rocks
	_box("RockSmall", Vector3(0.7, 0.25, 0.7), Transform3D(Basis(Vector3.UP, 0.7), Vector3(4.35, 0.125, LANE.rock_small)), Color(0.45, 0.42, 0.4))
	_label("small rock 0.25", Vector3(2, 2.2, LANE.rock_small))
	_box("RockLarge", Vector3(1.6, 0.9, 1.6), _at(Vector3(4.8, 0.45, LANE.rock_large)), Color(0.45, 0.42, 0.4))
	_label("large rock 0.9", Vector3(2, 2.2, LANE.rock_large))
	# Ledge (1.6 m) and mantle box (1.0 m)
	_box("Ledge", Vector3(4, 1.6, 4), _at(Vector3(6, 0.8, LANE.ledge)), stone)
	_label("ledge 1.6", Vector3(2, 2.6, LANE.ledge))
	_box("MantleBox", Vector3(1.5, 1.0, 2), _at(Vector3(4.75, 0.5, LANE.mantle_box)), accent)
	_label("mantle box 1.0", Vector3(2, 2.2, LANE.mantle_box))
	# Climbable wall: 4.5 m, with a walkable top 3 m deep
	_box("ClimbWall", Vector3(3, 4.5, 4), _at(Vector3(5.5, 2.25, LANE.climb_wall)), Color(0.5, 0.45, 0.6), ["climbable"])
	_label("climbable 4.5", Vector3(2, 2.6, LANE.climb_wall))
	# Pool: basin walls 2.5 m tall above ground, water surface at 2.3 m, inner beach ramp.
	var pz: float = LANE.pool
	var px := 8.0
	_box("PoolWallW", Vector3(0.5, 2.5, 10), _at(Vector3(px - 5.25, 1.25, pz)), stone)
	_box("PoolWallE", Vector3(0.5, 2.5, 10), _at(Vector3(px + 5.25, 1.25, pz)), stone)
	_box("PoolWallN", Vector3(11, 2.5, 0.5), _at(Vector3(px, 1.25, pz - 5.25)), stone)
	_box("PoolWallS", Vector3(11, 2.5, 0.5), _at(Vector3(px, 1.25, pz + 5.25)), stone)
	var beach := deg_to_rad(20.0)
	_box("PoolBeach", Vector3(8, 0.4, 3), Transform3D(Basis(Vector3.BACK, beach), Vector3(px + 1.5, 1.2, pz + 3.5)), Color(0.7, 0.65, 0.5))
	var water := Area3D.new()
	water.name = "Water"
	water.set_script(load("res://dev/DevWaterVolume.gd"))
	water.position = Vector3(px, 0, pz)
	water.set("surface_height", WATER_SURFACE)
	var wshape := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(10, WATER_SURFACE + 0.3, 10)
	wshape.shape = wbox
	wshape.position.y = (WATER_SURFACE + 0.3) * 0.5
	water.add_child(wshape)
	add_child(water)
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	surface.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.15, 0.35, 0.5, 0.55)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = wm
	surface.position = Vector3(px, WATER_SURFACE, pz)
	add_child(surface)
	_label("pool (surface 2.3)", Vector3(2, 3.2, pz))
	# Narrow cave: 1.6 m wide, 2.2 m high, 12 m long
	var cz: float = LANE.cave
	_box("CaveL", Vector3(12, 2.2, 1), _at(Vector3(10, 1.1, cz - 1.3)), Color(0.3, 0.28, 0.27))
	_box("CaveR", Vector3(12, 2.2, 1), _at(Vector3(10, 1.1, cz + 1.3)), Color(0.3, 0.28, 0.27))
	_box("CaveRoof", Vector3(12, 1, 3.6), _at(Vector3(10, 2.7, cz)), Color(0.3, 0.28, 0.27))
	_label("narrow cave", Vector3(2, 2.6, cz))
	# Crawl space: 1.3 m clearance, 4 m long
	var kz: float = LANE.crawl
	_box("CrawlRoof", Vector3(4, 1, 3), _at(Vector3(6, 1.8, kz)), Color(0.3, 0.28, 0.27))
	_label("crawl 1.3", Vector3(2, 2.6, kz))

func _spawn_player() -> void:
	player = (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	player.position = lane_start("flat")
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
	camera_rig.yaw = -PI * 0.5 # look down +X
	player.camera_pivot = camera_rig
	player.spring_arm = arm
	add_child(player)
	add_child(camera_rig)
