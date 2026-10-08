extends Control

## Epilogue & Credits Sequence Controller
@onready var label_narrative: Label = $VBoxContainer/NarrativeLabel
@onready var label_credits: Label = $VBoxContainer/CreditsLabel
@onready var btn_menu: Button = $VBoxContainer/BtnReturnMenu

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_daylight()
	btn_menu.visible = false
	btn_menu.pressed.connect(_on_return_to_menu)
	
	var dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(dialogue)
	dialogue.configure("EPI")
	await dialogue.play_event("ending")
	_run_credits_sequence()

func _run_credits_sequence() -> void:
	label_narrative.text = "The mountain ridge collapsed into eternal silence.\n\nThe Vaelor's subterranean memory remains undisturbed.\n\nMara preserved history—not by taking it, but by leaving it buried."
	
	await get_tree().create_timer(6.0).timeout
	
	label_narrative.visible = false
	label_credits.visible = true
	label_credits.text = "ECHOES BENEATH\n\nOriginal archaeological adventure\nBuilt with Godot Engine • Jolt Physics\n3D models and characters: Tripo3D\nVoices and sound: ElevenLabs\n\nTHANK YOU FOR PLAYING"
	
	await get_tree().create_timer(6.0).timeout
	btn_menu.visible = true

func _on_return_to_menu() -> void:
	GameManager.change_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

## Level B: daylight vista behind the text (sunrise over the valley, survivors reunited).
func _build_daylight() -> void:
	var vista := SubViewportContainer.new()
	vista.set_script(preload("res://systems/levelb/EpilogueVista.gd"))
	add_child(vista)
	move_child(vista, 1) # above Background, below the text
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0, 0, 0, 1)
	# Readability: soft dark band behind the centred text.
	var band := ColorRect.new()
	band.color = Color(0.02, 0.02, 0.03, 0.42)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.3
	band.anchor_bottom = 0.72
	add_child(band)
	move_child(band, 2)
	for l in [label_narrative, label_credits]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
	var sc = preload("res://systems/audio/Soundscape.gd").attach(self, "EPI")
	if sc:
		sc.add_bed("res://audio/ambience/jungle/AMB_DAYLIGHT_RIDGE_WIND.ogg", -6.0)
		sc.add_bed("res://audio/ambience/jungle/AMB_JUNGLE_BIRDS_INSECTS.ogg", -10.0)