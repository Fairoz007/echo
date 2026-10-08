class_name WaterBody
extends Area3D
## Drop-in water: visible animated surface + Area3D volume (group "water_volume").
## Contract (consumed by Player swimming, Buoyancy, VFX):
##   get_surface_height(world_pos) -> float   exact match of the rendered vertex waves
##   get_flow_velocity(world_pos)  -> Vector3
##   is_point_underwater(world_pos) -> bool
##   set_level(target_local_y, duration)       rising/draining, emits signals
## Assumes the node is not rotated/scaled (translation only); size is in world units.

signal level_changed(level_world_y: float)
signal level_target_reached(level_world_y: float)
signal rise_started(target_world_y: float)
signal drain_started(target_world_y: float)
signal body_entered_water(body: Node3D, impact_speed: float)
signal body_exited_water(body: Node3D)

const HIGH_SHADER := preload("res://shaders/water_surface.gdshader")
const LOW_SHADER := preload("res://shaders/water_surface_low.gdshader")
const WET_SHADER := preload("res://shaders/wet_overlay.gdshader")
const SPLASH := preload("res://vfx/Splash.gd")

@export var preset: WaterPreset
## Used when `preset` is null. One of WaterPreset.NAMES.
@export var preset_name := "CALM_CAVE_POOL"
@export var size := Vector2(10, 10)
## Water column below the surface covered by the Area3D (swim/buoyancy volume).
@export var depth := 3.0
## Local Y of the resting surface. Animated by set_level().
@export var surface_level := 0.0
@export_range(4, 256) var subdivisions := 96
## -1 = follow GraphicsSettings (Low preset => low quality). 0 = force high, 1 = force low.
@export_enum("Auto:-1", "High:0", "Low:1") var quality_override := -1
@export var splashes := true
## Optional looping water AudioStreamPlayer3D; pitch/volume follow level change speed.
@export var flow_audio: NodePath
## Seconds that surfaces stay darkened after the water drains off them.
@export var wet_dry_time := 25.0

var time := 0.0
var low_quality := false
var surface: MeshInstance3D
var material: ShaderMaterial
var shape: CollisionShape3D
var wet_material: ShaderMaterial
var _tween: Tween
var _level_speed := 0.0
var _audio: Node
var _audio_base_db := 0.0
var _wet_top := -INF
var _wet_targets: Array[GeometryInstance3D] = []
var _wet_clock_running := false

static var _noise_normal: Texture2D
static var _noise_normal_fine: Texture2D
static var _noise_foam: Texture2D

func _ready() -> void:
	add_to_group("water_volume")
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	monitorable = false
	if preset == null:
		preset = WaterPreset.make(preset_name)
	_make_textures()
	surface = MeshInstance3D.new()
	surface.name = "Surface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	shape = CollisionShape3D.new()
	shape.name = "Volume"
	shape.shape = BoxShape3D.new()
	add_child(shape)
	_audio = get_node_or_null(flow_audio)
	if _audio:
		_audio_base_db = _audio.volume_db
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	set_graphics_quality(int(graphics.preset) if graphics and quality_override == -1 else (2 if quality_override <= 0 else 0))
	_update_volume()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## Called by GraphicsSettings._apply_scene (0 = Low, 1 = Balanced, 2 = High).
func set_graphics_quality(preset_index: int) -> void:
	if quality_override != -1:
		preset_index = 2 if quality_override == 0 else 0
	low_quality = preset_index == 0
	var plane := PlaneMesh.new()
	plane.size = size
	var div := subdivisions if not low_quality else maxi(8, subdivisions / 4)
	if preset_index == 1:
		div = maxi(16, subdivisions / 2)
	plane.subdivide_width = div
	plane.subdivide_depth = int(div * size.y / maxf(size.x, 0.01))
	surface.mesh = plane
	material = ShaderMaterial.new()
	material.shader = LOW_SHADER if low_quality else HIGH_SHADER
	preset.apply_to(material, low_quality)
	material.set_shader_parameter("normal_a", _noise_normal)
	if not low_quality:
		material.set_shader_parameter("normal_b", _noise_normal_fine)
		material.set_shader_parameter("foam_noise", _noise_foam)
	material.set_shader_parameter("water_time", time)
	surface.material_override = material
	surface.position = Vector3(0, surface_level, 0)

func _process(delta: float) -> void:
	time += delta
	if material:
		material.set_shader_parameter("water_time", time)
	if _audio and _audio is AudioStreamPlayer3D:
		var s := clampf(absf(_level_speed), 0.0, 2.0)
		_audio.pitch_scale = lerpf(_audio.pitch_scale, 1.0 + 0.25 * s, 0.1)
		_audio.volume_db = lerpf(_audio.volume_db, _audio_base_db + 6.0 * s, 0.1)
	if not _wet_targets.is_empty() and wet_material:
		wet_material.set_shader_parameter("water_line", get_level())

# ---------------------------------------------------------------- contract

## Same formula as shaders/water_waves.gdshaderinc::wave_height.
func wave_height(xz: Vector2) -> float:
	var h := 0.0
	var q := xz - preset.flow_velocity * time
	var n := preset.wave_count(low_quality)
	for i in n:
		var w: Vector4 = preset.waves[i]
		var d := Vector2(w.x + 1e-5, w.y).normalized()
		var k := TAU / maxf(w.w, 0.01)
		var omega := sqrt(9.81 * k) * preset.wave_speed
		h += w.z * sin(k * d.dot(q) - omega * time + float(i) * 1.7)
	return h

## World-space resting level (no waves).
func get_level() -> float:
	return global_position.y + surface_level

func get_surface_height(world_pos: Vector3) -> float:
	return get_level() + wave_height(Vector2(world_pos.x, world_pos.z))

func contains_xz(world_pos: Vector3) -> bool:
	var l := world_pos - global_position
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.y * 0.5

func is_point_underwater(world_pos: Vector3) -> bool:
	if not contains_xz(world_pos):
		return false
	var bottom := get_level() - depth
	return world_pos.y > bottom and world_pos.y < get_surface_height(world_pos)

func get_flow_velocity(world_pos: Vector3) -> Vector3:
	if not contains_xz(world_pos):
		return Vector3.ZERO
	return Vector3(preset.flow_velocity.x, 0.0, preset.flow_velocity.y)

## Vertical speed of the resting level (m/s), for swimmers riding rising water.
func get_level_velocity() -> float:
	return _level_speed

func get_density() -> float:
	return preset.density

# ---------------------------------------------------------------- rising / draining

## target is the new local surface_level. duration <= 0 snaps.
func set_level(target: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	var start := surface_level
	if is_equal_approx(start, target):
		level_target_reached.emit(get_level())
		return
	var target_world := global_position.y + target
	if target > start:
		rise_started.emit(target_world)
	else:
		_begin_wetness(get_level())
		drain_started.emit(target_world)
	if duration <= 0.0:
		_apply_level(target)
		_level_speed = 0.0
		level_target_reached.emit(get_level())
		return
	_level_speed = (target - start) / duration
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_method(_apply_level, start, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		_level_speed = 0.0
		level_target_reached.emit(get_level()))

func _apply_level(v: float) -> void:
	surface_level = v
	if surface:
		surface.position.y = v
	_update_volume()
	level_changed.emit(get_level())

func _update_volume() -> void:
	if shape == null:
		return
	# Volume spans the water column plus 0.6 m above the surface so bodies
	# approaching from above are tracked before they touch the waves.
	var top := surface_level + 0.6
	var bottom := surface_level - depth
	(shape.shape as BoxShape3D).size = Vector3(size.x, top - bottom, size.y)
	shape.position = Vector3(0, (top + bottom) * 0.5, 0)

# ---------------------------------------------------------------- wetness

## Darkens every GeometryInstance3D in group "wettable" overlapping this water
## between the pre-drain level and the current water line; dries over wet_dry_time.
func _begin_wetness(from_level: float) -> void:
	_wet_top = maxf(from_level, _wet_top if wet_material else -INF)
	if wet_material == null:
		wet_material = ShaderMaterial.new()
		wet_material.shader = WET_SHADER
	wet_material.set_shader_parameter("wet_top", _wet_top)
	wet_material.set_shader_parameter("water_line", from_level)
	wet_material.set_shader_parameter("dry_start_time", Time.get_ticks_msec() / 1000.0)
	wet_material.set_shader_parameter("dry_duration", wet_dry_time)
	var m := 0.3
	wet_material.set_shader_parameter("wet_bounds", Vector4(global_position.x - size.x * 0.5 - m, global_position.z - size.y * 0.5 - m, global_position.x + size.x * 0.5 + m, global_position.z + size.y * 0.5 + m))
	_wet_targets.clear()
	var area := AABB(global_position + Vector3(-size.x * 0.5 - m, from_level - global_position.y - depth - 1.0, -size.y * 0.5 - m), Vector3(size.x + 2 * m, depth + 2.0, size.y + 2 * m))
	for node in get_tree().get_nodes_in_group("wettable"):
		for g in ([node] if node is GeometryInstance3D else []) + node.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if gi == surface:
				continue
			var box := gi.global_transform * gi.get_aabb()
			if box.intersects(area):
				gi.material_overlay = wet_material
				_wet_targets.append(gi)
	# Shader TIME and ticks differ; drive time explicitly.
	if not _wet_clock_running:
		_drive_wet_clock()

func _drive_wet_clock() -> void:
	_wet_clock_running = true
	while wet_material and is_inside_tree():
		var now := Time.get_ticks_msec() / 1000.0
		wet_material.set_shader_parameter("now", now)
		if now - float(wet_material.get_shader_parameter("dry_start_time")) > wet_dry_time + 1.0:
			for gi in _wet_targets:
				if is_instance_valid(gi) and gi.material_overlay == wet_material:
					gi.material_overlay = null
			_wet_targets.clear()
			wet_material = null
			_wet_top = -INF
			_wet_clock_running = false
			return
		await get_tree().process_frame

# ---------------------------------------------------------------- splashes

func _body_velocity(body: Node3D) -> Vector3:
	if body is RigidBody3D:
		return body.linear_velocity
	if body is CharacterBody3D:
		return body.velocity
	return Vector3.ZERO

func _on_body_entered(body: Node3D) -> void:
	var v := _body_velocity(body)
	body_entered_water.emit(body, -v.y)
	if splashes and v.y < -1.0 and not body.has_meta("buoyancy_splash"):
		var p := body.global_position
		p.y = get_surface_height(p)
		SPLASH.spawn(self, p, clampf(-v.y / 6.0, 0.2, 1.5))

func _on_body_exited(body: Node3D) -> void:
	body_exited_water.emit(body)
	var v := _body_velocity(body)
	if splashes and v.y > 1.0 and contains_xz(body.global_position):
		var p := body.global_position
		p.y = get_surface_height(p)
		SPLASH.spawn(self, p, clampf(v.y / 8.0, 0.15, 0.8))

# ---------------------------------------------------------------- textures

static func _make_textures() -> void:
	if _noise_normal:
		return
	_noise_normal = _noise_tex(0.012, 3, true, 3.0, 11)
	_noise_normal_fine = _noise_tex(0.03, 2, true, 2.0, 29)
	_noise_foam = _noise_tex(0.025, 4, false, 1.0, 7)

static func _noise_tex(freq: float, octaves: int, normal: bool, bump: float, seed_value: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_value
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	return t
