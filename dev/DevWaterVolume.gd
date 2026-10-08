extends Area3D
## DEV ONLY stand-in implementing the water contract the Player consumes:
## group "water_volume" + get_surface_height(world_pos) -> float.
@export var surface_height := 0.0

func _ready() -> void:
	add_to_group("water_volume")
	collision_layer = 0
	collision_mask = 1
	monitoring = true

func get_surface_height(_world_pos: Vector3) -> float:
	return global_position.y + surface_height
