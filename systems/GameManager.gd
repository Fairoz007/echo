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
	chapter_changed.connect(func(_c): _advancing = false)
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

## Walkable chapter exits: the S-bend passage starts at this node in the current region.
## Chapters not listed (falls, cinematics, the flashback) advance with a short fade instead.
const IN_WORLD_EXITS := {1: "RidgeArea/ChapterEndTrigger", 4: "ExitTunnel/ExitTrigger", 6: "TempleSanctum/ExitTrigger",
	7: "RoyalCauseway/CausewayExitTrigger", 9: "VaultThreshold/VaultGateTrigger"}
const RegionHandoff := preload("res://systems/world/RegionHandoff.gd")
const SeamlessPassage := preload("res://systems/world/SeamlessPassage.gd")
var _advancing := false

func load_chapter(chapter_num: int, scene_path: String) -> void:
	# A dead Mara never advances the story: death goes through the checkpoint menu instead
	# (previously a death during a chapter-ending scene showed the game-over menu and then
	# loaded the next chapter anyway).
	if current_state == GameState.GAME_OVER and chapter_num == current_chapter + 1:
		print("[GAME_MANAGER] Ignored chapter advance while dead")
		return
	# During play, finishing a chapter continues in the same world with the same Mara:
	# no story card, no scene reload, no respawn at a chapter start.
	if _advance_in_world(chapter_num, scene_path):
		return
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

## A region loaded on its own (new chapter from the menu, continue, checkpoint) still gets the
## entry passage its predecessor would have joined, sealed at the far end, so the geography
## and any save position inside the passage stay valid.
func _ensure_entry_passage(scene: Node) -> void:
	var prev := current_chapter - 1
	if not IN_WORLD_EXITS.has(prev) or scene.get_node_or_null("EntryPassage") or not scene is Node3D:
		return
	var packed := load(scene.scene_file_path) as PackedScene
	var spawn := SeamlessPassage.authored_spawn(packed)
	var entry := SeamlessPassage.create(scene, SeamlessPassage.entry_transform(spawn), "EntryPassage", true)
	SeamlessPassage.clear_volume(scene, entry, spawn.origin)

func _advance_in_world(chapter_num: int, scene_path: String) -> bool:
	var scene := get_tree().current_scene as Node3D
	# Mid-game only: gameplay, or a story cinematic that ends the chapter (e.g. the betrayal).
	if _advancing or SaveManager.restore_pending or not current_state in [GameState.GAMEPLAY, GameState.CINEMATIC] or transition.is_active():
		return false
	if chapter_num != current_chapter + 1 or chapter_num >= 12 or scene == null or scene.get_node_or_null("Player") == null:
		return false
	_advancing = true
	print("[GAME_MANAGER] In-world advance %d -> %d (%s)" % [current_chapter, chapter_num, "passage" if IN_WORLD_EXITS.has(current_chapter) else "fade"])
	RegionHandoff.prepare(scene_path)
	var anchor := scene.get_node_or_null(IN_WORLD_EXITS.get(current_chapter, "")) as Node3D if IN_WORLD_EXITS.has(current_chapter) else null
	if anchor:
		var at := anchor.global_position
		# Mara has just stepped on the exit trigger: her floor is the reliable mouth height
		# (a ray from above can land on raised gates or the level below).
		var player := scene.get_node("Player") as Node3D
		if Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < 8.0:
			at.y = player.global_position.y
		else:
			var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 8.0, 3, [(player as CollisionObject3D).get_rid()])
			var hit := scene.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				at.y = hit.position.y
		var passage := SeamlessPassage.create(scene, SeamlessPassage.exit_transform(at, 0.0), "ExitPassage")
		print("[GAME_MANAGER] exit passage at %s (player %s, scene %s at %s)" % [at, player.global_position, scene.name, scene.global_position])
		SeamlessPassage.clear_volume(scene, passage, at + Vector3.UP * 0.3)
		passage.swap_entered.connect(func(): RegionHandoff.hand_off_passage.call_deferred(scene, passage, chapter_num, scene_path), CONNECT_ONE_SHOT)
	else:
		RegionHandoff.hand_off_fade(scene, chapter_num, scene_path)
	return true

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
	_ensure_entry_passage(scene)
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
