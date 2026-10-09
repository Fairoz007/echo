extends Node3D
class_name CameraController

## Third-person follow camera. The SpringArm sweeps a sphere against world geometry
## only (player excluded), pulls in instantly on contact and eases back out.
@export var target: Node3D
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -60.0
@export var max_pitch: float = 65.0
@export var smooth_speed: float = 12.0 ## horizontal follow sharpness (1/s)
@export var vertical_smooth_speed: float = 7.0 ## vertical follow; absorbs steps/landings
@export var pivot_height: float = 1.55 ## overridden by target.camera_height when present
@export var shoulder_offset: float = 0.35 ## lateral framing via Camera3D.h_offset (cannot clip)
@export var collision_radius: float = 0.22
@export var world_collision_mask: int = 2
@export var arm_return_speed: float = 3.0 ## m/s the arm extends after an obstruction clears

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var pitch: float = deg_to_rad(-12.0)
var yaw: float = 0.0
var max_arm_length := 3.5
var _arm_length := 3.5
var _snapped := false

func _ready() -> void:
	top_level = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if spring_arm:
		max_arm_length = spring_arm.spring_length
		_arm_length = max_arm_length
		spring_arm.rotation.x = pitch
		spring_arm.collision_mask = world_collision_mask
		var sphere := SphereShape3D.new()
		sphere.radius = collision_radius
		spring_arm.shape = sphere
		spring_arm.margin = 0.05
		if target is CollisionObject3D:
			spring_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	if camera:
		camera.near = 0.05
		camera.h_offset = shoulder_offset

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		# Physical mouse sensitivity stays constant when the window is downscaled.
		var motion: Vector2 = event.screen_relative if event.screen_relative != Vector2.ZERO else event.relative
		yaw -= motion.x * mouse_sensitivity
		pitch -= motion.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

func _pivot_target() -> Vector3:
	var height := pivot_height
	if target and "camera_height" in target:
		height = target.camera_height
	var base := target.global_position
	var desired := base + Vector3.UP * height
	# Keep the pivot below low ceilings (crawl spaces) so the sweep never starts inside rock.
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(base + Vector3.UP * 0.4, desired + Vector3.UP * collision_radius, world_collision_mask, exclude)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		desired.y = maxf(base.y + 0.4, hit.position.y - collision_radius - 0.05)
	return desired

func snap_to_target() -> void:
	if target:
		global_position = _pivot_target()

func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired := _pivot_target()
	if not _snapped or global_position.distance_to(desired) > 4.0:
		global_position = desired # teleports / respawns
		_snapped = true
	else:
		var h_alpha := 1.0 - exp(-smooth_speed * delta)
		var v_alpha := 1.0 - exp(-vertical_smooth_speed * delta)
		var p := global_position
		p.x = lerpf(p.x, desired.x, h_alpha)
		p.z = lerpf(p.z, desired.z, h_alpha)
		p.y = lerpf(p.y, desired.y, v_alpha)
		# Never lag more than 0.6 m vertically (long falls).
		p.y = clampf(p.y, desired.y - 0.6, desired.y + 0.6)
		global_position = p
	rotation.y = yaw
	if spring_arm:
		spring_arm.rotation.x = pitch
		var hit_length := spring_arm.get_hit_length()
		if hit_length < _arm_length - 0.01:
			_arm_length = hit_length # pull in immediately: never show the inside of rock
		else:
			# Capped-speed return that eases into full length (a constant-rate return stopped
			# dead at max length: a visible camera kick after every obstruction).
			var step := maxf((max_arm_length - _arm_length) * (1.0 - exp(-6.0 * delta)), 0.8 * delta)
			_arm_length = minf(_arm_length + minf(step, arm_return_speed * delta), max_arm_length)
		spring_arm.spring_length = maxf(_arm_length, 0.0)
