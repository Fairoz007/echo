class_name WindSystem
extends Node
## Global wind. Works without an autoload: the first register_material() call
## creates a driver node under the SceneTree root. (Optionally add as autoload
## "Wind" -> res://systems/nature/WindSystem.gd; behavior is identical.)
## Every registered ShaderMaterial that includes shaders/wind_common.gdshaderinc
## receives wind_direction / wind_strength / gust_amount / gust_frequency / wind_time.
## Gameplay can read the same values (sample_wind) e.g. for cloth, particles, audio.

static var direction := Vector2(1.0, 0.35)
static var strength := 1.0
static var gust_amount := 0.6
static var gust_frequency := 0.25
static var time := 0.0
static var _materials: Array[ShaderMaterial] = []
static var _driver: Node

static func register_material(m: ShaderMaterial) -> void:
	if m == null or _materials.has(m):
		return
	_materials.append(m)
	_push(m)
	_ensure_driver()

static func unregister_material(m: ShaderMaterial) -> void:
	_materials.erase(m)

static func set_wind(dir: Vector2, s: float, gust := -1.0, gust_freq := -1.0) -> void:
	direction = dir.normalized() if dir.length() > 0.001 else direction
	strength = s
	if gust >= 0.0: gust_amount = gust
	if gust_freq >= 0.0: gust_frequency = gust_freq

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(_driver):
		_driver = self

func _process(delta: float) -> void:
	if _driver != self:
		return
	if not get_tree().paused:
		time += delta
	var i := _materials.size() - 1
	while i >= 0:
		var m := _materials[i]
		if m == null or m.get_reference_count() <= 1:
			_materials.remove_at(i)  # only the registry holds it
		else:
			_push(m)
		i -= 1
