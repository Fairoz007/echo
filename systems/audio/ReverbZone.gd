extends Area3D
class_name ReverbZone

const _Buses := preload("res://systems/audio/AudioBuses.gd")

## Box volume that switches the zone reverb while the Player is inside, then restores the chapter default.
## Create with Soundscape.add_reverb_zone(center, size, "cave") or place in a scene and set preset/size.
@export var preset := "cave"
@export var size := Vector3(10, 6, 10)
static var _stack: Array = []  # innermost zone wins
static var default_preset := "outdoor"

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 0xFFFFFFFF
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		add_child(shape)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _is_player(body: Node) -> bool:
	return body is Player or body.is_in_group("player")

func _on_enter(body: Node) -> void:
	if _is_player(body):
		_stack.erase(self)
		_stack.append(self)
		_Buses.apply_reverb(preset)

func _on_exit(body: Node) -> void:
	if _is_player(body):
		_stack.erase(self)
		_restore()

func _exit_tree() -> void:
	if _stack.has(self):
		_stack.erase(self)
		_restore()

static func _restore() -> void:
	_stack = _stack.filter(func(z): return is_instance_valid(z))
	_Buses.apply_reverb(_stack.back().preset if not _stack.is_empty() else default_preset)
