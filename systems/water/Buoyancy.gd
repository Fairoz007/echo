class_name Buoyancy
extends Node
## Add as a child of a RigidBody3D. Multi-point Archimedes buoyancy against any
## WaterBody in group "water_volume", with linear/angular water drag and flow push
## (drag acts on velocity relative to the flowing water). Spawns entry/exit
## splashes and bobbing ripples.

signal entered_water(water: Node)
signal exited_water(water: Node)

## Local-space probe points. Empty = 8 corners of the body's collision AABB (inset 10%).
@export var probe_points: PackedVector3Array
## Displaced volume (m^3) when fully submerged. <= 0 = estimate from collision AABB.
@export var volume := 0.0
## Multiplies buoyant force (tune floaters without changing mass).
@export var buoyancy_scale := 1.0
@export var linear_drag := -1.0   ## <0 = use water preset value
@export var angular_drag := -1.0  ## <0 = use water preset value
@export var splashes := true

var body: RigidBody3D
var water: Node
var submerged := 0.0
var _height := 1.0
var _was_in := false
var _ripple_cd := 0.0
const SPLASH := preload("res://vfx/Splash.gd")

func _ready() -> void:
	body = get_parent() as RigidBody3D
	assert(body != null, "Buoyancy must be a child of RigidBody3D")
	body.set_meta("buoyancy_splash", true)
	var aabb := _collision_aabb()
	_height = maxf(aabb.size.y, 0.05)
	if volume <= 0.0:
		volume = aabb.size.x * aabb.size.y * aabb.size.z * 0.85
	if probe_points.is_empty():
		var c := aabb.get_center()
		var e := aabb.size * 0.45
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					probe_points.append(c + Vector3(e.x * x, e.y * y, e.z * z))

func _collision_aabb() -> AABB:
	var result := AABB()
	var first := true
	for cs in body.find_children("*", "CollisionShape3D", false, false):
		if cs.shape == null:
			continue
		var a: AABB = cs.transform * cs.shape.get_debug_mesh().get_aabb()
		result = a if first else result.merge(a)
		first = false
	return result if not first else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

func _find_water(p: Vector3) -> Node:
	if water and is_instance_valid(water) and water.contains_xz(p) and p.y > water.get_level() - water.depth - _height:
		return water
	for w in get_tree().get_nodes_in_group("water_volume"):
		if w.has_method("get_surface_height") and w.contains_xz(p) and p.y > w.get_level() - w.depth - _height and p.y < w.get_level() + 2.0 * _height:
			return w
	return null

func _physics_process(delta: float) -> void:
	water = _find_water(body.global_position)
	if water == null:
		_set_in(false)
		submerged = 0.0
		return
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var per_point: float = water.get_density() * volume * g * buoyancy_scale / probe_points.size()
	var total := 0.0
	var xf := body.global_transform
	for lp in probe_points:
		var wp := xf * lp
		var h: float = water.get_surface_height(wp)
		var frac := clampf((h - wp.y) / _height + 0.5, 0.0, 1.0)
		if frac <= 0.0:
			continue
		total += frac
		body.apply_force(Vector3.UP * per_point * frac, wp - body.global_position)
	submerged = total / probe_points.size()
	_set_in(submerged > 0.02)
	if submerged <= 0.0:
		return
	var preset: WaterPreset = water.preset
	var ld := linear_drag if linear_drag >= 0.0 else preset.linear_drag
	var ad := angular_drag if angular_drag >= 0.0 else preset.angular_drag
	var rel: Vector3 = body.linear_velocity - water.get_flow_velocity(body.global_position)
	rel.y -= water.get_level_velocity()
	body.apply_central_force(-rel * ld * body.mass * submerged)
	body.apply_torque(-body.angular_velocity * ad * body.mass * submerged * _height * _height)
	_ripple_cd -= delta
	if splashes and _ripple_cd <= 0.0 and submerged < 0.95 and (absf(body.linear_velocity.y) > 0.25 or rel.length() > 0.8):
		_ripple_cd = 0.6
		var p := body.global_position
		p.y = water.get_surface_height(p)
		SPLASH.spawn_ripple(body, p, 0.6, 0.6 + _height)

func _set_in(v: bool) -> void:
	if v == _was_in:
		return
	_was_in = v
	if v:
		entered_water.emit(water)
		if splashes and body.linear_velocity.y < -1.0:
			var p := body.global_position
			p.y = water.get_surface_height(p)
			SPLASH.spawn(body, p, clampf(-body.linear_velocity.y / 6.0, 0.2, 1.5))
	else:
		exited_water.emit(water)
