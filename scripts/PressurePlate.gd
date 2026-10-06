extends PuzzleComponent

## Pressure Plate puzzle element activated when stepped on
@export var trigger_area: Area3D
@export var plate_mesh: Node3D

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D or body is RigidBody3D:
		set_solved(true)
		if plate_mesh:
			var tween = create_tween()
			tween.tween_property(plate_mesh, "position:y", -0.08, 0.2)

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D or body is RigidBody3D:
		# Check if any other bodies remain
		if trigger_area.get_overlapping_bodies().is_empty():
			set_solved(false)
			if plate_mesh:
				var tween = create_tween()
				tween.tween_property(plate_mesh, "position:y", 0.0, 0.2)
