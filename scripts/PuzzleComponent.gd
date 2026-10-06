extends Node3D
class_name PuzzleComponent

## Base class for physical puzzle components
@export var component_id: String = ""
@export var is_solved: bool = false

signal solved_state_changed(component: PuzzleComponent, solved: bool)

func set_solved(state: bool) -> void:
	if is_solved == state:
		return
	is_solved = state
	solved_state_changed.emit(self, is_solved)
	print("[PUZZLE] Component", name, "is_solved:", is_solved)
