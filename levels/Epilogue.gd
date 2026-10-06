extends Control

## Epilogue & Credits Sequence Controller
@onready var label_narrative: Label = $VBoxContainer/NarrativeLabel
@onready var label_credits: Label = $VBoxContainer/CreditsLabel
@onready var btn_menu: Button = $VBoxContainer/BtnReturnMenu

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	btn_menu.visible = false
	btn_menu.pressed.connect(_on_return_to_menu)
	
	_run_credits_sequence()

func _run_credits_sequence() -> void:
	label_narrative.text = "The mountain ridge collapsed into eternal silence.\n\nThe Vaelor's subterranean memory remains undisturbed.\n\nMara preserved history—not by taking it, but by leaving it buried."
	
	await get_tree().create_timer(6.0).timeout
	
	label_narrative.visible = false
	label_credits.visible = true
	label_credits.text = "ECHOES BENEATH\n\nDIRECTED & ARCHITECTED BY ANTIGRAVITY\nPOWERED BY GODOT ENGINE 4.7.2 (D3D12 & JOLT PHYSICS 3D)\nASSET GENERATION VIA TRIPO3D AI PIPELINE\n\nTHANK YOU FOR PLAYING"
	
	await get_tree().create_timer(6.0).timeout
	btn_menu.visible = true

func _on_return_to_menu() -> void:
	GameManager.change_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
