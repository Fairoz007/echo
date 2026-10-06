extends Node

## Global Game Manager Singleton for ECHOES BENEATH
enum GameState {
	MENU,
	CINEMATIC,
	GAMEPLAY,
	PAUSED,
	GAME_OVER,
	CREDITS
}

var current_state: GameState = GameState.MENU
var current_chapter: int = 0
var is_first_time: bool = true

signal state_changed(new_state: GameState)
signal chapter_changed(chapter_num: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GAME_MANAGER] Initialized. Engine version:", Engine.get_version_info().string)

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	
	match current_state:
		GameState.GAMEPLAY:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameState.PAUSED, GameState.MENU, GameState.CREDITS:
			get_tree().paused = (current_state == GameState.PAUSED)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.CINEMATIC:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	state_changed.emit(current_state)
	print("[GAME_MANAGER] State changed to:", GameState.keys()[current_state])

func start_new_game() -> void:
	current_chapter = 0
	change_state(GameState.GAMEPLAY)
	if SaveManager:
		SaveManager.reset_data()
	get_tree().change_scene_to_file("res://levels/Prologue.tscn")

func load_chapter(chapter_num: int, scene_path: String) -> void:
	current_chapter = chapter_num
	chapter_changed.emit(current_chapter)
	change_state(GameState.GAMEPLAY)
	get_tree().change_scene_to_file(scene_path)
