extends Area3D
class_name Interactable3D

## Base class for interactive world objects
@export var prompt_message: String = "Press E to Interact"
@export var is_one_shot: bool = false
@export var is_enabled: bool = true

signal interacted(player: Node)

func _ready() -> void:
	collision_layer = 4 # Interactable layer
	collision_mask = 1  # Player layer

func trigger_interaction(player: Node) -> void:
	if not is_enabled:
		return
	print("[INTERACTION] Triggered on:", name)
	interacted.emit(player)
	if is_one_shot:
		is_enabled = false
