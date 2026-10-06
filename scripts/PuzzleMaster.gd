extends Node3D
class_name PuzzleMaster

## Combines multiple puzzle components to unlock physical obstacles
@export var required_components: Array[PuzzleComponent] = []
@export var target_door: Node3D
@export var solved_door_height_offset: float = 4.0

var is_puzzle_complete: bool = false
signal puzzle_completed

func _ready() -> void:
	for comp in required_components:
		if comp:
			comp.solved_state_changed.connect(_on_component_state_changed)

func _on_component_state_changed(_comp: PuzzleComponent, _solved: bool) -> void:
	check_status()

func check_status() -> void:
	for comp in required_components:
		if comp and not comp.is_solved:
			return # Still unresolved
			
	if not is_puzzle_complete:
		is_puzzle_complete = true
		print("[PUZZLE MASTER] All components resolved! Triggering door mechanism.")
		puzzle_completed.emit()
		open_mechanism()

func open_mechanism() -> void:
	if target_door:
		var tween = create_tween()
		tween.tween_property(target_door, "position:y", target_door.position.y + solved_door_height_offset, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
