extends Node3D
## Meridian service aqueduct linking the Ch5 ruin gate to the Ch6 temple landing (Ch6 coordinates).
##
## Layout (Mara travels -Z):
##   Ch5 gate (-9, 3, 76) -> leg A (x=-9) -> junction chamber (z 46..56) -> leg B (x=0)
##   -> ramp down through the south-wall doorway onto the landing (0, 1, 25.5).
## The x jog in the chamber blocks the line of sight between the two ends, so region
## activation and the old region's release always happen out of view.
## Built in both modes: when Ch6 is loaded standalone (save/continue), leg A ends in a rockfall.

const KIT := preload("res://systems/levelb/LBKit.gd")
const WALL := "res://assets/environment/cave/cave_wall_limestone.glb"
const CEIL := "res://assets/environment/cave/cave_ceiling_limestone.glb"
const FLOOR := "res://assets/environment/cave/cave_floor_sediment.glb"
const BOULDER := "res://assets/models/optimized/env_boulder_moss_LOD0.glb"
const PILLAR := "res://assets/models/optimized/ruin_pillar_vaelor_LOD0.glb"

const GATE := Vector3(-9.0, 3.0, 76.0) ## where the Ch5 gate floor lands in Ch6 space
const FLOOR_Y := 3.0
const HEIGHT := 4.6
const HALF_W := 2.5

var activation_area: Area3D
var rockfall: Node3D
var stone: Material

const ROCK_ALBEDO := "res://assets/textures/polyhaven/rock_wall_08_diff_1k.jpg"
const ROCK_NORMAL := "res://assets/textures/polyhaven/rock_wall_08_nor_gl_1k.jpg"
const ROCK_ROUGH := "res://assets/textures/polyhaven/rock_wall_08_rough_1k.jpg"

func _rock() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(ROCK_ALBEDO)
	m.albedo_color = Color(0.62, 0.6, 0.56) # cooler/darker to sit with the Ch5 limestone and Ch6 hall
	m.normal_enabled = true
	m.normal_texture = load(ROCK_NORMAL)
	m.roughness_texture = load(ROCK_ROUGH)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.4 # 1 tile per 2.5 m
	return m

func build(_p_stone: Material) -> void:
	name = "Ch5Ch6Aqueduct"
	stone = _rock()
	_corridor(Vector3(-9, 0, 66), 20.0, false)      # leg A: z 56..76
	_chamber()                                      # z 46..56, x -12..3
	_corridor(Vector3(0, 0, 38.5), 15.0, false)     # leg B: z 31..46
	_ramp()
	_portal()
	_lights()
	_activation()
	# Route markers for scripted traversal QA (qa_campaign_physical): leg A end, chamber exit.
	for wp in [["QA_AqA", Vector3(-9, FLOOR_Y, 57)], ["QA_AqB", Vector3(0, FLOOR_Y, 49)], ["QA_Landing", Vector3(0, 1.0, 22.0)]]:
		var m := Node3D.new()
		m.name = wp[0]
		add_child(m)
		m.position = wp[1]
	rockfall = Node3D.new()
	rockfall.name = "Rockfall"
	add_child(rockfall)
	for i in 5:
		KIT.place(rockfall, BOULDER, Vector3(-9 + (i - 2) * 1.1, FLOOR_Y, 73.5 + (i % 2) * 0.8), 2.4 + (i % 3) * 0.5, i * 1.3)
	_box(rockfall, Vector3(-9, FLOOR_Y + HEIGHT * 0.5, 74), Vector3(HALF_W * 2, HEIGHT, 1.5), false)

## Seamless mode: leg A stays open onto the live Ch5 region.
func open_to_previous_region(open: bool) -> void:
	rockfall.visible = not open
	for c in rockfall.find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).disabled = open

func _box(parent: Node, center: Vector3, size: Vector3, _visual := true) -> StaticBody3D:
	var visual := true
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("collision", "none")
	parent.add_child(body)
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visual:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		m.mesh = bm
		m.material_override = stone
		body.add_child(m)
	return body

## Tiles a cave kit model along the longest horizontal axis of `size` in ~4 m pieces so the
## texture keeps a believable scale (one stretched 20 m mesh reads as a blurry slab).
func _fit(path: String, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var along_z := size.z >= size.x
	var length := size.z if along_z else size.x
	var count := maxi(1, int(round(length / 4.0)))
	for i in count:
		var t := (i + 0.5) / count - 0.5
		var c := center + (Vector3(0, 0, t * length) if along_z else Vector3(t * length, 0, 0))
		var piece := Vector3(size.x, size.y, length / count * 1.15) if along_z else Vector3(length / count * 1.15, size.y, size.z)
		_fit_one(path, c, piece, yaw + (PI if i % 2 else 0.0))

func _fit_one(path: String, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var ps := KIT.packed(path)
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	inst.set_meta("collision", "none")
	add_child(inst)
	var b := KIT.model_bounds(path)
	# Rotate first, then scale in world axes so the piece fills the box whatever its yaw.
	var rb := Basis(Vector3.UP, yaw)
	var rotated := (rb * b.size).abs()
	var s := Vector3(size.x / maxf(rotated.x, 0.01), size.y / maxf(rotated.y, 0.01), size.z / maxf(rotated.z, 0.01))
	var basis := Basis.from_scale(s) * rb
	inst.transform = Transform3D(basis, center - basis * b.get_center())
	inst.add_to_group("wettable")
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = stone

func _corridor(center: Vector3, length: float, _unused: bool) -> void:
	var c := Vector3(center.x, FLOOR_Y, center.z)
	_box(self, c + Vector3(0, -0.5, 0), Vector3(HALF_W * 2 + 1.0, 1.0, length), false)
	_fit(FLOOR, c + Vector3(0, 0.05, 0), Vector3(HALF_W * 2 + 0.6, 0.3, length))
	for side in [-1.0, 1.0]:
		_box(self, c + Vector3(side * (HALF_W + 0.5), HEIGHT * 0.5, 0), Vector3(1.0, HEIGHT + 0.4, length), false)
		_fit(WALL, c + Vector3(side * (HALF_W + 0.3), HEIGHT * 0.5, 0), Vector3(0.9, HEIGHT + 0.6, length), 0.0 if side < 0 else PI)
	_box(self, c + Vector3(0, HEIGHT + 0.5, 0), Vector3(HALF_W * 2 + 2.0, 1.0, length), false)
	_fit(CEIL, c + Vector3(0, HEIGHT + 0.25, 0), Vector3(HALF_W * 2 + 1.0, 0.6, length))

func _chamber() -> void:
	var c := Vector3(-4.5, FLOOR_Y, 51)
	var size := Vector3(15.0, HEIGHT + 1.4, 10.0)
	_box(self, c + Vector3(0, -0.5, 0), Vector3(size.x, 1.0, size.z), false)
	_fit(FLOOR, c + Vector3(0, 0.05, 0), Vector3(size.x, 0.3, size.z))
	_box(self, c + Vector3(0, size.y + 0.5, 0), Vector3(size.x + 1.0, 1.0, size.z + 1.0), false)
	_fit(CEIL, c + Vector3(0, size.y + 0.25, 0), Vector3(size.x, 0.6, size.z))
	for side in [-1.0, 1.0]:
		_box(self, c + Vector3(side * (size.x * 0.5 + 0.5), size.y * 0.5, 0), Vector3(1.0, size.y, size.z), false)
		_fit(WALL, c + Vector3(side * (size.x * 0.5 + 0.3), size.y * 0.5, 0), Vector3(0.9, size.y + 0.4, size.z), 0.0 if side < 0 else PI)
	# End walls with openings: north (+z) to leg A at x=-9, south (-z) to leg B at x=0.
	for wall in [[56.0, -9.0], [46.0, 0.0]]:
		var z: float = wall[0]
		var gap_x: float = wall[1]
		var left_w := (gap_x - HALF_W) - (c.x - size.x * 0.5)
		var right_w := (c.x + size.x * 0.5) - (gap_x + HALF_W)
		for seg in [[c.x - size.x * 0.5 + left_w * 0.5, left_w], [gap_x + HALF_W + right_w * 0.5, right_w]]:
			if seg[1] > 0.1:
				_box(self, Vector3(seg[0], FLOOR_Y + size.y * 0.5, z), Vector3(seg[1], size.y, 1.0), false)
				_fit(WALL, Vector3(seg[0], FLOOR_Y + size.y * 0.5, z), Vector3(seg[1], size.y + 0.4, 0.9), PI * 0.5)
		_box(self, Vector3(gap_x, FLOOR_Y + HEIGHT + (size.y - HEIGHT) * 0.5, z), Vector3(HALF_W * 2, size.y - HEIGHT, 1.0), false)
	# Abandoned Meridian staging: crates and a work lamp make the chamber a place, not filler.
	KIT.place(self, BOULDER, Vector3(-10.0, FLOOR_Y, 48.0), 1.6, 0.7)
	KIT.place(self, BOULDER, Vector3(1.5, FLOOR_Y, 54.5), 1.2, 2.1)

func _ramp() -> void:
	# Leg B floor (3.0) down to the landing top (1.0) between z 31 and 25.5, through the doorway.
	var len := Vector3(0, FLOOR_Y - 1.0, 31.0 - 25.0).length()
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 2
	ramp.set_meta("collision", "none")
	add_child(ramp)
	ramp.position = Vector3(0, (FLOOR_Y + 1.0) * 0.5 - 0.5, 28.0)
	ramp.rotation.x = -atan((FLOOR_Y - 1.0) / 6.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_W * 2, 1.0, len)
	shape.shape = box
	ramp.add_child(shape)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	m.mesh = bm
	m.material_override = stone
	ramp.add_child(m)
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * (HALF_W + 0.5), 1.0 + HEIGHT * 0.5 + 1.0, 28.25), Vector3(1.0, HEIGHT + 2.0, 5.5), false)
		_fit(WALL, Vector3(side * (HALF_W + 0.3), 1.0 + HEIGHT * 0.5 + 1.0, 28.25), Vector3(0.9, HEIGHT + 2.2, 5.5), 0.0 if side < 0 else PI)
	_box(self, Vector3(0, FLOOR_Y + HEIGHT + 0.5, 28.25), Vector3(HALF_W * 2 + 2.0, 1.0, 5.5), false)
	_fit(CEIL, Vector3(0, FLOOR_Y + HEIGHT + 0.25, 28.25), Vector3(HALF_W * 2 + 1.0, 0.6, 5.5))

## Rock face closing the Ch5 basin around leg A's mouth, so the aqueduct reads as cut into the
## cliff rather than a free-standing structure. Spans between Ch5's cavern walls (x -28..11).
func _portal() -> void:
	var z := GATE.z + 0.6
	var top := FLOOR_Y + 14.0
	for seg in [[-28.0, GATE.x - HALF_W - 0.5], [GATE.x + HALF_W + 0.5, 11.0]]:
		var w: float = seg[1] - seg[0]
		_box(self, Vector3(seg[0] + w * 0.5, (FLOOR_Y - 3.0 + top) * 0.5, z), Vector3(w, top - FLOOR_Y + 3.0, 1.6))
		_fit(WALL, Vector3(seg[0] + w * 0.5, (FLOOR_Y - 3.0 + top) * 0.5, z - 0.9), Vector3(w, top - FLOOR_Y + 3.0, 1.2), PI * 0.5)
	_box(self, Vector3(GATE.x, (FLOOR_Y + HEIGHT + top) * 0.5, z), Vector3(HALF_W * 2 + 1.0, top - FLOOR_Y - HEIGHT, 1.6))
	_fit(WALL, Vector3(GATE.x, (FLOOR_Y + HEIGHT + top) * 0.5, z - 0.9), Vector3(HALF_W * 2 + 1.0, top - FLOOR_Y - HEIGHT, 1.2), PI * 0.5)
	for i in 6:
		KIT.place(self, BOULDER, Vector3(-24.0 + i * 6.5 + (i % 2) * 1.5, FLOOR_Y - 1.5, z + 1.5 + (i % 3) * 0.6), 2.0 + (i % 3) * 1.1, i * 0.9)

func _lights() -> void:
	# Meridian work lamps: warm, sparse, motivated (strung cable-lamps every ~10 m).
	for p in [Vector3(-9, 4.6, 70), Vector3(-9, 4.6, 60), Vector3(-4.5, 5.6, 51), Vector3(0, 4.6, 41), Vector3(0, 4.6, 33)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 1.1
		l.omni_range = 9.0
		l.shadow_enabled = false
		add_child(l)
		l.position = p

func _activation() -> void:
	activation_area = Area3D.new()
	activation_area.name = "RegionActivation"
	activation_area.collision_layer = 0
	activation_area.collision_mask = 1
	add_child(activation_area)
	activation_area.position = Vector3(0, FLOOR_Y + 1.5, 44.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_W * 2, 3.0, 2.0)
	shape.shape = box
	activation_area.add_child(shape)
