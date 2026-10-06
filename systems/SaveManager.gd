extends Node

## Save and Persistence System Singleton
const SAVE_PATH_TEMPLATE = "user://save_slot_%d.json"

var game_data: Dictionary = {
	"version": 1,
	"timestamp": 0,
	"chapter": 0,
	"checkpoint_id": "cp_start",
	"player": {
		"health": 100.0,
		"stamina": 100.0,
		"position": [0.0, 1.0, 0.0],
		"rotation_y": 0.0
	},
	"inventory": [],
	"skills": [],
	"puzzles_solved": [],
	"journal_entries": []
}

func reset_data() -> void:
	game_data["chapter"] = 0
	game_data["checkpoint_id"] = "cp_start"
	game_data["player"]["health"] = 100.0
	game_data["inventory"].clear()
	game_data["skills"].clear()
	game_data["puzzles_solved"].clear()

func save_game(slot: int = 0) -> bool:
	game_data["timestamp"] = Time.get_unix_time_from_system()
	game_data["chapter"] = GameManager.current_chapter
	game_data["checkpoint_id"] = MissionManager.current_checkpoint_id
	
	var path = SAVE_PATH_TEMPLATE % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SAVE] Failed to open file for writing: " + path)
		return false
		
	var json_string = JSON.stringify(game_data, "\t")
	file.store_string(json_string)
	file.close()
	print("[SAVE] Successfully saved game slot", slot, "to", path)
	return true

func load_game(slot: int = 0) -> bool:
	var path = SAVE_PATH_TEMPLATE % slot
	if not FileAccess.file_exists(path):
		print("[SAVE] No save file found at:", path)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
		
	var content = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SAVE] Corrupt save file format")
		return false
		
	game_data = parsed
	print("[SAVE] Loaded game slot", slot)
	return true
