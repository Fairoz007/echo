extends Control

## Main Menu Controller for ECHOES BENEATH
@onready var btn_continue: Button = $VBoxContainer/BtnContinue
@onready var btn_new_game: Button = $VBoxContainer/BtnNewGame
@onready var btn_settings: Button = $VBoxContainer/BtnSettings
@onready var btn_credits: Button = $VBoxContainer/BtnCredits
@onready var btn_quit: Button = $VBoxContainer/BtnQuit

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_quit.pressed.connect(func(): get_tree().quit())
	
	# Check if save file exists
	var save_exists = FileAccess.file_exists("user://save_slot_0.json")
	btn_continue.disabled = not save_exists
	if save_exists:
		btn_continue.pressed.connect(_on_continue_pressed)

func _on_new_game_pressed() -> void:
	GameManager.start_new_game()

func _on_continue_pressed() -> void:
	if SaveManager.load_game(0):
		var ch = SaveManager.game_data.get("chapter", 0)
		var level_file = "res://levels/Prologue.tscn" if ch == 0 else "res://levels/Chapter1.tscn"
		GameManager.load_chapter(ch, level_file)
