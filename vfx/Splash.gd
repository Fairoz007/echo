extends Node3D
## One-shot splash: droplet burst + spray mist + expanding ripple ring.
## Usage: preload("res://vfx/Splash.gd").spawn(parent, world_pos, strength 0.1..1.5)
## Also used standalone via vfx/Splash.tscn (call play(strength)).

const RIPPLE_SHADER := preload("res://shaders/water_ripple.gdshader")
static var _drop_mat: StandardMaterial3D
static var _drop_mesh: QuadMesh

var strength := 1.0
var _autoplay := false

func _ready() -> void:
	if _autoplay:
		play(strength)

static func spawn(parent: Node, world_pos: Vector3, s: float) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var host: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent
	if host.is_queued_for_deletion():
		return null
	var splash: Node3D = load("res://vfx/Splash.gd").new()
	splash.top_level = true
	splash.position = world_pos
	splash.strength = s
	splash._autoplay = true
	host.add_child.call_deferred(splash)
	return splash

static func spawn_ripple(parent: Node, world_pos: Vector3, s: float, radius := 1.2) -> void:
	var r := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	r.mesh = q
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = RIPPLE_SHADER
	m.set_shader_parameter("intensity", s)
	r.material_override = m
	if parent == null or not parent.is_inside_tree():
		return
	var host: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent
	r.top_level = true
	r.position = world_pos + Vector3(0, 0.02, 0)
	r.ready.connect(func():
		var tw := r.create_tween()
		tw.tween_method(func(a): m.set_shader_parameter("age", a), 0.0, 1.0, 1.4)
		tw.tween_callback(r.queue_free))
	host.add_child.call_deferred(r)

func play(s: float) -> void:
	strength = s
	_ensure_assets()
	var drops := CPUParticles3D.new()
	drops.one_shot = true
	drops.explosiveness = 0.9
	drops.amount = int(12 + 40 * s)
	drops.lifetime = 0.9
	drops.mesh = _drop_mesh
	drops.material_override = _drop_mat
	drops.direction = Vector3.UP
	drops.spread = 35.0
	drops.initial_velocity_min = 1.5 + 2.0 * s
	drops.initial_velocity_max = 3.0 + 4.0 * s
	drops.gravity = Vector3(0, -9.8, 0)
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	drops.emission_ring_axis = Vector3.UP
	drops.emission_ring_radius = 0.25 + 0.2 * s
	drops.emission_ring_inner_radius = 0.1
	drops.emission_ring_height = 0.0
	drops.scale_amount_min = 0.04
	drops.scale_amount_max = 0.10 + 0.06 * s
	add_child(drops)
	drops.emitting = true
	var mist := CPUParticles3D.new()
	mist.one_shot = true
	mist.explosiveness = 0.7
	mist.amount = int(4 + 6 * s)
	mist.lifetime = 1.4
	mist.mesh = _drop_mesh
	mist.material_override = _drop_mat
	mist.direction = Vector3.UP
	mist.spread = 60.0
	mist.initial_velocity_min = 0.5
	mist.initial_velocity_max = 1.2 + s
	mist.gravity = Vector3(0, -0.6, 0)
	mist.damping_min = 1.0
	mist.damping_max = 2.0
	mist.scale_amount_min = 0.15
	mist.scale_amount_max = 0.3 + 0.35 * s
	mist.color = Color(1, 1, 1, 0.18)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4)); curve.add_point(Vector2(0.3, 1)); curve.add_point(Vector2(1, 0))
	mist.scale_amount_curve = curve
	add_child(mist)
	mist.emitting = true
	spawn_ripple(self, global_position, clampf(s, 0.3, 1.2), 0.8 + 1.2 * s)
	get_tree().create_timer(2.0).timeout.connect(queue_free)

static func _ensure_assets() -> void:
	if _drop_mat:
		return
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.albedo_texture = tex
	_drop_mat.albedo_color = Color(0.85, 0.92, 0.95, 0.75)
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_drop_mat.vertex_color_use_as_albedo = true
	_drop_mesh = QuadMesh.new()
	_drop_mesh.size = Vector2.ONE
