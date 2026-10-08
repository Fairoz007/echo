extends RefCounted
## Level B shared helpers: fitted model placement, colliders, rock material, NPCs,
## collectibles, lights. All static so level dressers stay small.

const ROCK_SHADER := preload("res://systems/levelb/rock_moss.gdshader")
const ROCK_TEX := "res://assets/environment/cave/cave_wall_limestone_Color_e63e799a-2e6c-41d4-966d-f77e80cd4719.jpg"
const ROCK_NRM := "res://assets/environment/cave/cave_wall_limestone_NormalGL_e63e799a-2e6c-41d4-966d-f77e80cd4719.png"
const INTERACT := preload("res://scripts/Interactable3D.gd")
const CHARACTER := preload("res://systems/ProductionCharacter.gd")
const COLLECTIBLE := preload("res://systems/levelb/LBCollectible.gd")

static var _scene_cache := {}
static var _bounds_cache := {}
static var _rock_mats := {}

static func packed(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _scene_cache[path]

static func model_bounds(path: String) -> AABB:
	if _bounds_cache.has(path):
		return _bounds_cache[path]
	var ps := packed(path)
	var b := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	if ps:
		var inst := ps.instantiate() as Node3D
		var started := false
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != inst and n is Node3D:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var box := xf * mi.get_aabb()
			b = b.merge(box) if started else box
			started = true
		inst.free()
	_bounds_cache[path] = b
	return b

## Places a model so its bounding-box bottom-centre sits at `ground` and its height
## (or its largest horizontal extent when fit_height is false) equals `target`.
## `stretch` multiplies the per-axis scale afterwards (non-uniform variation).
static func place(parent: Node, path: String, ground: Vector3, target: float, yaw := 0.0, stretch := Vector3.ONE, fit_height := true, node_name := "") -> Node3D:
	var ps := packed(path)
	if ps == null:
		push_warning("[LevelB] missing model " + path)
		return null
	var inst := ps.instantiate() as Node3D
	if node_name != "":
		inst.name = node_name
	var b := model_bounds(path)
	var ref := b.size.y if fit_height else maxf(b.size.x, b.size.z)
	var s := target / maxf(ref, 0.001)
	var sc := Vector3.ONE * s * stretch
	var basis := Basis(Vector3.UP, yaw).scaled(sc)
	var c := b.get_center()
	var bottom := Vector3(c.x, b.position.y, c.z)
	inst.transform = Transform3D(basis, ground - basis * bottom)
	parent.add_child(inst)
	return inst

## Rock re-grade material. `src` = the model's own albedo (UV atlas); defaults to limestone.
static func rock_material(tint := Color(0.62, 0.61, 0.56), moss := 0.55, wet_line := -1000.0, src: Texture2D = null, src_n: Texture2D = null) -> ShaderMaterial:
	var key := "%s_%.2f_%.2f_%s" % [tint.to_html(), moss, wet_line, str(src.get_rid()) if src else "lime"]
	if _rock_mats.has(key):
		return _rock_mats[key]
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	if src == null:
		src = load(ROCK_TEX)
		src_n = load(ROCK_NRM)
	m.set_shader_parameter("rock_tex", src)
	m.set_shader_parameter("rock_nrm", src_n)
	m.set_shader_parameter("has_normal", src_n != null)
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("tint_b", Vector3(tint.r, tint.g, tint.b) * 0.72)
	m.set_shader_parameter("moss_amount", moss)
	m.set_shader_parameter("wet_line", wet_line)
	_rock_mats[key] = m
	return m

## Re-grades every mesh of a placed rock model with the moss/tint shader, keeping each
## mesh's own albedo/normal atlas. `mat` supplies tint/moss/wet_line parameters.
static func override_material(node: Node, mat: Material) -> void:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		var m := mi as MeshInstance3D
		if not (mat is ShaderMaterial) or m.mesh == null:
			m.material_override = mat
			continue
		var src_mat := m.get_active_material(0) as BaseMaterial3D
		var tex: Texture2D = src_mat.albedo_texture if src_mat else null
		var ntex: Texture2D = src_mat.normal_texture if src_mat and src_mat.normal_enabled else null
		var t: Vector3 = mat.get_shader_parameter("tint")
		m.material_override = rock_material(Color(t.x, t.y, t.z), float(mat.get_shader_parameter("moss_amount")), float(mat.get_shader_parameter("wet_line")), tex, ntex)

static func noise_tex(freq: float, octaves: int, normal: bool, bump: float, seed_value: int, cellular := false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR if cellular else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_value
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	return t

static func box_body(parent: Node, center: Vector3, size: Vector3, yaw := 0.0, node_name := "Collider", layer := 3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), center)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	return body

static func npc(parent: Node, node_name: String, model_path: String, pos: Vector3, yaw: float, height: float, prompt := "") -> Node3D:
	var root := StaticBody3D.new()
	root.name = node_name
	root.collision_layer = 2
	parent.add_child(root)
	root.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	root.add_child(cs)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(CHARACTER)
	vis.set("model_path", model_path)
	vis.set("character_height", height)
	root.add_child(vis)
	if prompt != "":
		interaction(root, Vector3(0, 1.0, 0), Vector3(2.2, 2.2, 2.2), prompt)
	return root

static func interaction(parent: Node, local_pos: Vector3, size: Vector3, prompt: String) -> Area3D:
	var area := Area3D.new()
	area.name = "Interactable3D"
	area.set_script(INTERACT)
	area.set("prompt_message", prompt)
	area.position = local_pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)
	parent.add_child(area)
	return area

static func trigger(parent: Node, center: Vector3, size: Vector3, node_name: String) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = 0
	area.collision_mask = 1
	parent.add_child(area)
	area.global_position = center
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)
	return area

## Optional collectible (journal page / Vaelor tablet / Meridian document).
static func collectible(parent: Node, id: String, kind: String, title: String, body: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Collectible_" + id
	c.set_script(COLLECTIBLE)
	c.set("collectible_id", id)
	c.set("kind", kind)
	c.set("title", title)
	c.set("body", body)
	parent.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return c

static func omni(parent: Node, pos: Vector3, color: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	parent.add_child(l)
	l.global_position = pos
	return l

static var _grain: Texture2D

static func grain() -> Texture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.06
		n.fractal_octaves = 4
		var g := NoiseTexture2D.new()
		g.width = 256
		g.height = 256
		g.seamless = true
		g.noise = n
		g.color_ramp = Gradient.new()
		g.color_ramp.set_color(0, Color(0.78, 0.78, 0.78))
		g.color_ramp.set_color(1, Color(1, 1, 1))
		_grain = g
	return _grain

static func std_mat(color: Color, rough := 0.8, metal := 0.0, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	# Subtle world-space grain so procedural props never read as flat blockout.
	m.albedo_texture = grain()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.7, 0.7, 0.7)
	m.metallic = metal
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m

static func mesh(parent: Node, m: Mesh, xf: Transform3D,