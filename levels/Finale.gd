extends Node3D

## Finale: The Mountain Breaks - High-Speed Escape & Epilogue Sequence
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var daylight_exit_trigger: Area3D = $DaylightRidge/DaylightExitTrigger

var transition_started := false

func _ready() -> void:
	preload("res://systems/environment/EnvironmentCollision.gd").attach(self)
	preload("res://systems/environment/BlockoutDresser.gd").apply(self)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("FIN", hud)
	MissionManager.register_objective("obj_finale_escape", "Sprint through the collapsing shafts toward daylight")
	
	if daylight_exit_trigger:
		daylight_exit_trigger.body_entered.connect(_on_daylight_reached)
		
	await get_tree().create_timer(1.0).timeout
	if hud:
		AudioManager.play_story_line("Mara", "I see daylight! Tomas, Nadiya, I'm almost through the eastern fissure!", 4.0)

func _on_daylight_reached(body: Node) -> void:
	if body is Player and not transition_started:
		transition_started = true
		print("[FINALE] Daylight reached! Mountain sealed behind Mara. Transitioning to Epilogue & Credits.")
		MissionManager.complete_objective("obj_finale_escape")
		var duration := 3.5
		if hud:
			duration = AudioManager.play_story_line("Tomas", "\"Tomas: Mara! Grab my hand! I've got you!\"", 3.5)
			await get_tree().create_timer(duration).timeout
			await $CampaignDialogue.play_event("rescue")
			duration = AudioManager.play_story_line("Mara", "\"Never again...\"", 3.0)
			
		await get_tree().create_timer(duration).timeout
		GameManager.load_chapter(12, "res://levels/Epilogue.tscn")
