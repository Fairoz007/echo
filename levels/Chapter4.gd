extends Node3D

## Chapter 4: Beneath - Cave Navigation Level Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var radio_interactable: Interactable3D = $AbandonedCamp/FieldRadio/Interactable3D
@onready var subterranean_exit_trigger: Area3D = $ExitTunnel/ExitTrigger

var has_repaired_radio: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c04_find_way", "Navigate the deep subterranean cavern and seek radio signals")
	
	if radio_interactable:
		radio_interactable.interacted.connect(_on_radio_repaired)
	if subterranean_exit_trigger:
		subterranean_exit_trigger.body_entered.connect(_on_subterranean_exit)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "Underground... Water broke my fall. I need to find high ground and radio contact.", 5.0)

func _on_radio_repaired(_p: Node) -> void:
	if not has_repaired_radio:
		has_repaired_radio = true
		MissionManager.complete_objective("obj_c04_find_way")
		MissionManager.register_objective("obj_c04_reach_outpost", "Ascend through the upper tunnels toward the Meridian outpost")
		if hud:
			hud.show_subtitle("Nadiya (Radio)", "Mara?! Thank God! Be careful—armed contractors are breaching the valley!", 5.5)

func _on_subterranean_exit(body: Node) -> void:
	if body is Player and has_repaired_radio:
		print("[CHAPTER 4] Navigated subterranean caves! Transitioning to Chapter 5: Hunters.")
		if hud:
			hud.show_subtitle("Mara", "Voices ahead... Flashlights in the darkness. Meridian is here.", 4.0)
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(5, "res://levels/Chapter5.tscn")
