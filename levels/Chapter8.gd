extends Node3D

## Chapter 8: The Betrayal - Narrative Confrontation & Relic Theft
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var elias_interactable: Interactable3D = $SurvivorCamp/InjuredElias/Interactable3D
@onready var adrian_trigger: Area3D = $Passage/AdrianConfrontationTrigger

var has_spoken_to_elias: bool = false
var has_confronted_adrian: bool = false

var transition_started := false

var dressing

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.MODERATE, 0.0)
	dressing = preload("res://systems/levelb/Chapter8Dressing.gd").new()
	add_child(dressing)
	dressing.build(self)
	preload("res://systems/environment/EnvironmentCollision.gd").attach(self)
	preload("res://systems/environment/BlockoutDresser.gd").apply(self)
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(8)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C08", hud)
	dressing.hook_audio(preload("res://systems/audio/Soundscape.gd").attach(self, "C08"))
	MissionManager.register_objective("obj_c08_reunite_expedition", "Reunite with the surviving expedition team at the forward sanctuary")
	
	if elias_interactable:
		elias_interactable.interacted.connect(_on_elias_spoke)
	if adrian_trigger:
		adrian_trigger.body_entered.connect(_on_adrian_confrontation)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		AudioManager.play_story_line("Mara", "I see expedition gear ahead! Elias, Nadiya!", 4.0)

func _on_elias_spoke(_p: Node) -> void:
	if not has_spoken_to_elias:
		has_spoken_to_elias = true
		MissionManager.complete_objective("obj_c08_reunite_expedition")
		dressing.start_escalation()
		MissionManager.register_objective("obj_c08_pursue_adrian", "Pursue Adrian Kell through the Heart Road breach")
		if hud:
			AudioManager.play_story_line("Elias (Injured)", "Mara... Adrian took the Vaelor Key. He's been transmitting coordinates to Meridian all along.", 5.5)

func _on_adrian_confrontation(body: Node) -> void:
	if body is Player and has_spoken_to_elias and not has_confronted_adrian and not transition_started:
		transition_started = true
		has_confronted_adrian = true
		print("[CHAPTER 8] Adrian confrontation! Transitioning to Chapter 9: The Heart Road.")
		var duration := 5.0
		if hud:
			duration = AudioManager.play_story_line("Adrian (Radio)", "\"I'm sorry Mara. They offered a life beyond research grants. But Drake brought guns...\"", 5.0)
		await get_tree().create_timer(duration).timeout
		await $CampaignDialogue.play_event("aftermath")
		GameManager.load_chapter(9, "res://levels/Chapter9.tscn")
