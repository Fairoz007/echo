class_name WindSystem
extends Node
## Global wind. Works without an autoload: the first register_material() call
## creates a driver node under the SceneTree root. (Optionally add as autoload
## "Wind" -> res://systems/nature/WindSystem.gd; behavior is identical.)
## Every registered ShaderMaterial that includes shaders/wind_common.gdshaderinc
## receives wind_direction / wind_strength / gust_amount / gust_frequency / wind_time,
## turbulence / storm_intensity, the player interaction params and wind_detail.
## Gameplay can read the same values (sample_wind) e.g. for cloth, particles, audio.
##
## Presets: WindSystem.set_preset(WindSystem.Preset.STORM, 4.0) blends every value
## smoothly over 4 s. Audio / rain listen to WindSystem.driver().wind_changed.

signal wind_changed(strength: float, direction: Vector2, turbulence: float, storm_intensity: float)

enum Preset { CALM, BREEZE, MODERATE, STRONG, STORM, CAVE }
## strength, gust_amount, gust_frequency, turbulence, storm_intensity
const PRESETS := {
	Preset.CALM:     [0.25, 0.25, 0.12, 0.05, 0.0],
	Preset.BREEZE:   [0.7,  0.5,  0.22, 0.2,  0.0],
	Preset.MODERATE: [1.1,  0.6,  0.3,  0.35, 0.0],
	Preset.STRONG:   [1.7,  0.75, 0.42, 0.6,  0.15],
	Preset.STORM:    [2.4,  0.9,  0.6,  1.0,  1.0],
	Preset.CAVE:     [0.12, 0.35, 0.08, 0.05, 0.0],
}
const PRESET_NAMES := ["CALM", "BREEZE", "MODERATE", "STRONG", "STORM", "CAVE"]
## foliage_wind_detail by GraphicsSettings quality level (ULTRA LOW .. ULTRA).
## 0 = primary sway only, no interaction, no particles; 1 = full; 2 = + turbulence noise.
const DETAIL_BY_LEVEL := [0, 1, 2, 2, 2]
const INTERACT_RADIUS := 1.2

static var direction := Vector2(1.0, 0.35)
static var strength := 1.0
static var gust_amount := 0.6
static var gust_frequency := 0.25
static var turbulence := 0.2
static var storm_intensity := 0.0
static var time := 0.0
static var current_preset := -1
static var detail := 1
static var interaction_enabled := true
static var foliage_density := 1.0
static var player_position := Vector3(0, -1e5, 0)
static var player_trail := Vector3(0, -1e5, 0)
static var player_velocity := Vector3.ZERO
static var _materials: Array[ShaderMaterial] = []
static var _driver: Node
# Blend state: values lerp from _from to _to over _blend_len seconds.
static var _from := []
static var _to := []
static var _dir_from := Vector2.ONE
static var _dir_to := Vector2.ONE
static var _blend_t := 1.0
static var _blend_len := 0.0
static var _wind_phase := 0.0

static func driver() -> Node:
	_ensure_driver()
	return _driver

static func register_material(m: ShaderMaterial) -> void:
	if m == null or _materials.has(m):
		return
	_materials.append(m)
	_push(m)
	_ensure_driver()

static func unregister_material(m: ShaderMaterial) -> void:
	_materials.erase(m)

## Immediate set (legacy API). Cancels any running preset blend.
static func set_wind(dir: Vector2, s: float, gust := -1.0, gust_freq := -1.0) -> void:
	direction = dir.normalized() if dir.length() > 0.001 else direction
	strength = s
	if gust >= 0.0: gust_amount = gust
	if gust_freq >= 0.0: gust_frequency = gust_freq
	_blend_t = 1.0
	_emit_changed()

## Smoothly blend to a preset. dir = Vector2.ZERO keeps the current direction.
static func set_preset(preset: int, blend_seconds := 3.0, dir := Vector2.ZERO) -> void:
	if not PRESETS.has(preset):
		push_warning("WindSystem: unknown preset %s" % preset)
		return
	current_preset = preset
	_from = [strength, gust_amount, gust_frequency, turbulence, storm_intensity]
	_to = PRESETS[preset].duplicate()
	_dir_from = direction
	_dir_to = dir.normalized() if dir.length() > 0.001 else direction
	_blend_len = maxf(blend_seconds, 0.0)
	_blend_t = 0.0
	_ensure_driver()
	if _blend_len <= 0.0:
		_step_blend(1.0)

static func preset_from_name(n: String) -> int:
	return PRESET_NAMES.find(n.to_upper())

## World-space wind vector at a point (same gust function as the shaders).
static func sample_wind(world_pos: Vector3) -> Vector3:
	var d := Vector2(direction.x + 1e-5, direction.y).normalized()
	var front := Vector2(world_pos.x, world_pos.z).dot(d) * 0.08 - time * gust_frequency * TAU * 0.5
	var g := clampf(0.5 + 0.5 * sin(front) * 0.7 + 0.15 * sin(front * 2.7 + 1.3), 0.0, 1.0)
	var s := strength * (1.0 + gust_amount * (g * 2.0 - 0.6))
	return Vector3(d.x, 0.0, d.y) * s

static func _push(m: ShaderMaterial) -> void:
	m.set_shader_parameter("wind_direction", direction)
	m.set_shader_parameter("wind_strength", strength)
	m.set_shader_parameter("gust_amount", gust_amount)
	m.set_shader_parameter("gust_frequency", gust_frequency)
	m.set_shader_parameter("wind_time", time)
	m.set_shader_parameter("wind_phase", _wind_phase)
	m.set_shader_parameter("turbulence", turbulence)
	m.set_shader_parameter("storm_intensity", storm_intensity)
	m.set_shader_parameter("wind_detail", float(detail))
	m.set_shader_parameter("vegetation_interaction", interaction_enabled)
	m.set_shader_parameter("player_position", player_position)
	m.set_shader_parameter("player_trail", player_trail)
	m.set_shader_parameter("player_velocity", player_velocity)

static func _step_blend(t: float) -> void:
	_blend_t = clampf(t, 0.0, 1.0)
	var k := _blend_t * _blend_t * (3.0 - 2.0 * _blend_t)
	strength = lerpf(_from[0], _to[0], k)
	gust_amount = lerpf(_from[1], _to[1], k)
	gust_frequency = lerpf(_from[2], _to[2], k)
	turbulence = lerpf(_from[3], _to[3], k)
	storm_intensity = lerpf(_from[4], _to[4], k)
	var dd := _dir_from.slerp(_dir_to, k) if _dir_from.length() > 0.001 else _dir_to
	direction = dd.normalized() if dd.length() > 0.001 else direction

static func _emit_changed() -> void:
	if is_instance_valid(_driver):
		_driver.wind_changed.emit(strength, direction, turbulence, storm_intensity)

static func _ensure_driver() -> void:
	if is_instance_valid(_driver):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var existing := tree.root.get_node_or_null("Wind")
	if existing and existing.get_script() == load("res://systems/nature/WindSystem.gd"):
		_driver = existing
		return
	_driver = load("res://systems/nature/WindSystem.gd").new()
	_driver.name = "WindDriver"
	tree.root.add_child.call_deferred(_driver)

## Quality: foliage_wind_detail / foliage_density with safe defaults when the keys are missing.
static func apply_quality_settings(level: int, settings: Dictionary) -> void:
	var lvl := clampi(level, 0, DETAIL_BY_LEVEL.size() - 1)
	detail = int(settings.get("foliage_wind_detail", DETAIL_BY_LEVEL[lvl]))
	interaction_enabled = int(settings.get("vegetation_interaction", 1 if lvl > 0 else 0)) > 0
	foliage_density = float(settings.get("foliage_density", 1.0))

static func read_graphics() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("GraphicsSettings") if tree else null
	if gs and "settings" in gs and "quality_level" in gs:
		apply_quality_settings(int(gs.quality_level), gs.settings)

var _emit_accum := 0.0
var _last_emitted := Vector4(-1, -1, -1, -1)
var _player: Node3D
var _player_search := 0.0
var _last_player_pos := Vector3.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(_driver):
		_driver = self
	var gs := get_tree().root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_signal("quality_changed") and not gs.quality_changed.is_connected(_on_quality_changed):
		gs.quality_changed.connect(_on_quality_changed)
	read_graphics()

func _on_quality_changed(level: int, settings: Dictionary) -> void:
	apply_quality_settings(level, settings)

func _process(delta: float) -> void:
	if _driver != self:
		return
	var paused := get_tree().paused
	if not paused:
		time += delta
		# Integrated phase: oscillation speed follows strength without phase jumps when it changes.
		_wind_phase += delta * (0.6 + 0.4 * strength)
		if _blend_t < 1.0:
			_step_blend(_blend_t + delta / maxf(_blend_len, 0.001) if _blend_len > 0.0 else 1.0)
		_track_player(delta)
	_emit_accum += delta
	if _emit_accum >= 0.1:
		_emit_accum = 0.0
		var v := Vector4(strength, direction.angle(), turbulence, storm_intensity)
		if not v.is_equal_approx(_last_emitted):
			_last_emitted = v
			wind_changed.emit(strength, direction, turbulence, storm_intensity)
	var i := _materials.size() - 1
	while i >= 0:
		var m := _materials[i]
		if m == null or m.get_reference_count() <= 1:
			_materials.remove_at(i)  # only the registry holds it
		else:
			_push(m)
		i -= 1

func _track_player(delta: float) -> void:
	# Scene transitions detach the old level before its nodes are freed.
	if is_instance_valid(_player) and not _player.is_inside_tree():
		_player = null
		_player_search = 0.0
	if detail <= 0:
		player_position = Vector3(0, -1e5, 0)
		player_trail = player_position
		player_velocity = Vector3.ZERO
		return
	if not is_instance_valid(_player):
		_player_search -= delta
		if _player_search > 0.0:
			return
		_player_search = 0.5
		_player = get_tree().get_first_node_in_group("player") as Node3D
		_last_player_pos = Vector3.INF
		if _player == null:
			player_position = Vector3(0, -1e5, 0)
			player_trail = player_position
			player_velocity = Vector3.ZERO
			return
	var p := _player.global_position
	if _last_player_pos == Vector3.INF or p.distance_to(_last_player_pos) > 5.0:
		player_trail = p  # teleport / respawn: no smeared trail
		player_velocity = Vector3.ZERO
	elif delta > 0.0:
		player_velocity = player_velocity.lerp((p - _last_player_pos) / delta, clampf(delta * 10.0, 0.0, 1.0))
	_last_player_pos = p
	player_position = p
	# Lagged follower: foliage the player passed stays bent and recovers as this point moves on.
	player_trail = player_trail.lerp(p, clampf(delta * 1.6, 0.0, 1.0))
