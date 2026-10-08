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
var _restoring_scene := false
var _pause_menu: CanvasLayer
var transition: CanvasLayer
var journal_screen: CanvasLayer

signal state_changed(new_state: GameState)
signal chapter_changed(chapter_num: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)
	_pause_menu = preload("res://ui/PauseMenu.gd").new()
	add_child(_pause_menu)
	transition = preload("res://ui/StoryTransition.gd").new()
	add_child(transition)
	journal_screen = preload("res://ui/JournalScreen.gd").new()
	add_child(journal_screen)
	print("[GAME_MANAGER] Initialized. Engine version:", Engine.get_version_info().string)

func change_state(new_state: GameState) -> void:
	var changed = current_state != new_state
	current_state = new_state
	
	match current_state:
		GameState.GAMEPLAY:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameState.PAUSED, GameState.MENU, GameState.CREDITS, GameState.GAME_OVER:
			get_tree().paused = current_state in [GameState.PAUSED, GameState.GAME_OVER]
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.CINEMATIC:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if changed:
		state_changed.emit(current_state)
		print("[GAME_MANAGER] State changed to:", GameState.keys()[current_state])

func start_new_game() -> void:
	_restoring_scene = false
	current_chapter = 0
	change_state(GameState.GAMEPLAY)
	if SaveManager:
		SaveManager.reset_data()
	_transition_to(0, "res://levels/Prologue.tscn")

func load_chapter(chapter_num: int, scene_path: String) -> void:
	_restoring_scene = SaveManager.restore_pending
	if not _restoring_scene:
		MissionManager.active_objectives.clear()
	current_chapter = chapter_num
	chapter_changed.emit(current_chapter)
	_transition_to.call_deferred(chapter_num, scene_path)

## Story card + background threaded load, then the level starts in GAMEPLAY.
func _transition_to(chapter_num: int, scene_path: String) -> void:
	# A request during an active card is queued, not dropped.
	while transition.is_active():
		await transition.finished
	AudioManager.stop_dialogue()
	change_state(GameState.CINEMATIC)
	get_tree().paused = true
	await transition.play(chapter_num, scene_path)
	change_state(GameState.CREDITS if chapter_num == 12 else GameState.GAMEPLAY)
	get_tree().paused = false

func _on_scene_changed() -> void:
	var scene = get_tree().current_scene
	if scene and scene.scene_file_path == "res://levels/Epilogue.tscn":
		var credits = scene.get_node_or_null("VBoxContainer/CreditsLabel")
		if credits:
			credits.visibility_changed.connect(func():
				if credits.visible and not transition.is_active():
					transition.play(13, ""), CONNECT_ONE_SHOT)
	if not scene or not scene.scene_file_path.begins_with("res://levels/") or current_chapter > 11:
		return
	if _restoring_scene:
		_restoring_scene = false
		return
	# scene_changed occurs after node _ready; wait for initial physics settling.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(scene) or get_tree().current_scene != scene:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player:
		MissionManager.set_checkpoint("chapter_%02d_start" % current_chapter, player.global_transform)

func chapter_scene(chapter: int) -> String:
	if chapter == 0:
		return "res://levels/Prologue.tscn"
	if chapter >= 1 and chapter <= 10:
		return "res://levels/Chapter%d.tscn" % chapter
	if chapter == 11:
		return "res://levels/Finale.tscn"
	if chapter == 12:
		return "res://levels/Epilogue.tscn"
	return ""

func continue_saved_game(slot: int = 0) -> bool:
	if not SaveManager.load_game(slot):
		return false
	var chapter = int(SaveManager.game_data["chapter"])
	load_chapter(chapter, chapter_scene(chapter))
	return true

func restart_checkpoint() -> void:
	if not continue_saved_game(1):
		load_chapter(current_chapter, chapter_scene(current_chapter))

func handle_player_death() -> void:
	AudioManager.stop_dialogue()
	change_state(GameState.GAME_OVER)
	_pause_menu.show_menu(true)

func return_to_menu() -> void:
	AudioManager.stop_dialogue()
	change_state(GameState.MENU)
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if transition and transition.is_active():
			return
		if event.keycode == KEY_ESCAPE and current_state in [GameState.GAMEPLAY, GameState.PAUSED]:
			if current_state == GameState.PAUSED:
				_pause_menu.close_menu()
			else:
				change_state(GameState.PAUSED)
				_pause_menu.show_menu(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5 and current_state == GameState.GAMEPLAY:
			SaveManager.manual_save()
		elif event.keycode == KEY_F9 and current_state == GameState.GAMEPLAY:
			continue_saved_game()
