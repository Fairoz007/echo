extends Node

## Mission and Objective Tracking Singleton
signal objective_updated(objective_id: String, description: String, is_completed: bool)
signal checkpoint_reached(checkpoint_id: String)

var active_objectives: Dictionary = {}
var completed_objectives: Array = []
var current_checkpoint_id: String = "cp_start"
var current_checkpoint_transform: Transform3D = Transform3D.IDENTITY

func register_objective(id: String, description: String) -> void:
	active_objectives[id] = description
	objective_updated.emit(id, description, false)
	print("[MISSION] New Objective:", id, "->", description)

func complete_objective(id: String) -> void:
	if active_objectives.has(id):
		var desc = active_objectives[id]
		active_objectives.erase(id)
		completed_objectives.append(id)
		objective_updated.emit(id, desc, true)
		print("[MISSION] Completed Objective:", id)

func set_checkpoint(checkpoint_id: String, xform: Transform3D) -> void:
	current_checkpoint_id = checkpoint_id
	current_checkpoint_transform = xform
	checkpoint_reached.emit(checkpoint_id)
	print("[MISSION] Checkpoint stored:", checkpoint_id)
	if SaveManager:
		SaveManager.save_game(0)
		SaveManager.save_game(1)
