class_name FallingLeaves
extends Node3D
## Wind-driven falling leaves. GPUParticles3D, CPUParticles3D fallback (force_cpu, or when the
## renderer has no GPU particle path). Drift follows WindSystem direction/strength every frame;
## storm_intensity boosts the rate, speed and tumbling. Off on ULTRA LOW (foliage_wind_detail 0).
## Rate is scaled by GraphicsSettings "foliage_density".
##   var leaves := FallingLeaves.new(); leaves.area_size = Vector3(30, 6, 30); add_child(leaves)
## Place the node at canopy height; leaves spawn in the box and fall/drift out of it.

@export var area_size := Vector3(24.0, 4.0, 24.0)
@export var leaves_per_second := 6.0
@export var max_leaves := 160
@export var lifetime := 7.0
@export var leaf_size := 0.09
## Keep the emitter centred on the active camera (campaign use: leaves always around the player).
@export var follow_camera := false
@export var force_cpu := false
@export var colors: PackedColorArray = PackedColorArray([Color(0.42, 0.5, 0.16), Color(0.62, 0.55, 0.2), Color(0.55, 0.33, 0.12), Color(0.3, 0.42, 0.14)])

var particles: Node3D  # GPUParticles3D or CPUParticles3D
var using_gpu := false
var _pm: ParticleProcessMaterial
var _last_ratio := -1.0
static var _leaf_tex: Texture2D

func _ready() -> void:
	WindSystem.driver()
	WindSystem.read_graphics()
	_build()
	var gs := get_tree().root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_signal("quality_changed"):
		gs.quality_changed.connect(func(_l, _s): _update(0.0))
	_update(0.0)

static func _leaf_texture() -> Texture2D:
	if _leaf_tex:
		return _leaf_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			# Pointed leaf: ellipse narrowing toward the tip, darker midrib.
			var w := 0.55 * (1.0 - v * v) * (1.0 - 0.25 * v)
			var inside := absf(u) < w and absf(v) < 0.97
			var shade := 1.0 - 0.35 * float(absf(u) < 0.06) - 0.15 * absf(u) / maxf(w, 0.01)
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0 if inside else 0.0))
	img.generate_mipmaps()
	_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _leaf_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.25, 0.08)
	return m

func _ramp() -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / maxf(colors.size() - 1, 1))
	g.offsets = offs
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _build() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(leaf_size, leaf_size * 1.6)
	quad.material = _material()
	var method := RenderingServer.get_current_rendering_method()
	using_gpu = not force_cpu and method in ["forward_plus", "mobile", "gl_compatibility"]
	if using_gpu:
		var gp := GPUParticles3D.new()
		_pm = ParticleProcessMaterial.new()
		_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_pm.emission_box_extents = area_size * 0.5
		_pm.direction = Vector3(0, -1, 0)
		_pm.spread = 35.0
		_pm.initial_velocity_min = 0.2
		_pm.initial_velocity_max = 0.6
		_pm.damping_min = 0.3
		_pm.damping_max = 0.8
		_pm.angle_min = -180.0
		_pm.angle_max = 180.0
		_pm.angular_velocity_min = -160.0
		_pm.angular_velocity_max = 160.0
		_pm.scale_min = 0.7
		_pm.scale_max = 1.4
		_pm.color_initial_ramp = _ramp()
		_pm.turbulence_enabled = true
		_pm.turbulence_noise_scale = 4.0
		_pm.turbulence_noise_speed_random = 0.3
		_pm.turbulence_influence_min = 0.04
		_pm.turbulence_influence_max = 0.12
		gp.process_material = _pm
		gp.draw_pass_1 = quad
		gp.amount = max_leaves
		gp.lifetime = lifetime
		gp.preprocess = lifetime
		gp.local_coords = false
		gp.visibility_aabb = AABB(-area_size * 0.5 - Vector3(10, 14, 10), area_size + Vector3(20, 18, 20))
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles = gp
	else:
		var cp := CPUParticles3D.new()
		cp.mesh = quad
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cp.emission_box_extents = area_size * 0.5
		cp.direction = Vector3(0, -1, 0)
		cp.spread = 35.0
		cp.initial_velocity_min = 0.2
		cp.initial_velocity_max = 0.6
		cp.damping_min = 0.3
		cp.damping_max = 0.8
		cp.angle_min = -180.0
		cp.angle_max = 180.0
		cp.angular_velocity_min = -160.0
		cp.angular_velocity_max = 160.0
		cp.scale_amount_min = 0.7
		cp.scale_amount_max = 1.4
		cp.color_initial_ramp = _ramp().gradient
		cp.amount = max_leaves
		cp.lifetime = lifetime
		cp.preprocess = lifetime
		cp.local_coords = false
		cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles = cp
	particles.name = "Leaves"
	add_child(particles)

func _process(delta: float) -> void:
	_update(delta)

func _update(_delta: float) -> void:
	if particles == null:
		return
	if follow_camera:
		var cam := get_viewport().get_camera_3d()
		if cam:
			particles.global_position = cam.global_position + Vector3(0, area_size.y * 0.5 + 1.5, 0)
	var gs := get_tree().root.get_node_or_null("GraphicsSettings")
	var on := WindSystem.detail > 0 and (gs == null or int(gs.settings.get("leaf_particles", 1)) > 0)
	particles.visible = on
	particles.emitting = on
	if not on:
		return
	var w := WindSystem.sample_wind(particles.global_position)
	var storm := WindSystem.storm_intensity
	var drift := w * (0.45 + 0.35 * storm)
	var gravity := Vector3(drift.x, -0.45 - 0.4 * storm, drift.z)
	var spin := 160.0 * (1.0 + 1.5 * storm + 0.3 * WindSystem.turbulence)
	var rate := leaves_per_second * (0.5 + 0.5 * clampf(WindSystem.strength, 0.0, 2.0)) * (1.0 + 3.0 * storm) * WindSystem.foliage_density
	var ratio := clampf(rate * lifetime / float(max_leaves), 0.02, 1.0)
	if using_gpu:
		_pm.gravity = gravity
		_pm.angular_velocity_min = -spin
		_pm.angular_velocity_max = spin
		_pm.turbulence_influence_max = 0.12 + 0.2 * WindSystem.turbulence
		(particles as GPUParticles3D).amount_ratio = ratio
	else:
		var cp := particles as CPUParticles3D
		cp.gravity = gravity
		cp.angular_velocity_min = -spin
		cp.angular_velocity_max = spin
		if "amount_ratio" in cp:
			cp.set("amount_ratio", ratio)
		elif absf(ratio - _last_ratio) > 0.2:
			_last_ratio = ratio
			cp.amount = maxi(4, int(max_leaves * ratio))
