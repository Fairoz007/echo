extends Node3D

## Chapter 4: Beneath - Cave Navigation Level Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var radio_interactable: Interactable3D = $AbandonedCamp/FieldRadio/Interactable3D
@onready var subterranean_exit_trigger: Area3D = $ExitTunnel/ExitTrigger

var has_repaired_radio: bool = false

var transition_started := false

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(4)
	preload("res://systems/environment/PhotoDressing.gd").apply(self, 4)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C04", hud)
	MissionManager.register_objective("obj_c04_find_way", "Navigate the deep subterranean cavern and seek radio signals")
	
	if radio_interactable:
		radio_interactable.interacted.connect(_on_radio_repaired)
	if subterranean_exit_trigger:
		subterranean_exit_trigger.body_entered.connect(_on_subterranean_exit)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		AudioManager.play_story_line("Mara", "Underground... Water broke my fall. I need to find high ground and radio contact.", 5.0)

func _on_radio_repaired(_p: Node) -> void:
	if not has_repaired_radio:
		has_repaired_radio = true
		MissionManager.complete_objective("obj_c04_find_way")
		MissionManager.register_objective("obj_c04_reach_outpost", "Ascend through the upper tunnels toward the Meridian outpost")
		if hud:
			AudioManager.play_story_line("Nadiya (Radio)", "Mara?! Thank God! Be careful—armed contractors are breaching the valley!", 5.5)

func _on_subterranean_exit(body: Node) -> void:
	if body is Player and has_repaired_radio and not transition_started:
		transition_started = true
		print("[CHAPTER 4] Navigated subterranean caves! Transitioning to Chapter 5: Hunters.")
		if hud:
			AudioManager.play_story_line("Mara", "Voices ahead... Flashlights in the darkness. Meridian is here.", 4.0)
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(5, "res://levels/Chapter5.tscn")
