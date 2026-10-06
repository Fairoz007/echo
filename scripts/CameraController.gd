extends Node3D
class_name CameraController

## Cinematic Third-Person Camera with Smooth SpringArm Follow
@export var target: Node3D
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -60.0
@export var max_pitch: float = 65.0
@export var smooth_speed: float = 12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var pitch: float = -15.0
var yaw: float = 0.0

func _ready() -> void:
	top_level = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

func _physics_process(delta: float) -> void:
	if not target:
		return
		
	# Smoothly follow player position
	global_position = global_position.lerp(target.global_position + Vector3(0, 1.4, 0), smooth_speed * delta)
	
	# Apply rotation
	rotation.y = yaw
	if spring_arm:
		spring_arm.rotation.x = pitch
