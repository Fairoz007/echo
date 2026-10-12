extends Node3D

## Chapter 7: City of Echoes - Subterranean Hub & Optional Tomb Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var plaza_mural_interactable: Interactable3D = $CentralPlaza/HistoryMural/Interactable3D
@onready var optional_tomb_entrance: Area3D = $OptionalTomb/TombTrigger
@onready var causeway_exit_trigger: Area3D = $RoyalCauseway/CausewayExitTrigger

var has_read_mural: bool = false
var has_visited_tomb: bool = false

var transition_started := false
var city

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)
	# City of Echoes districts, main seals/gate progression and the three distinct tombs
	# (replaces the generic three-dial exploration rooms in this chapter).
	city = preload("res://systems/levelb/Chapter7City.gd").new()
	add_child(city)
	city.build(self)
	preload("res://systems/PlaytimeTracker.gd").attach(self, "c07", [
		["Central Plaza", Rect2(-12, -9, 24, 21)], ["Scholar's Quarter", Rect2(-23, 12, 16, 18)],
		["Echo Gardens", Rect2(7, 16, 16, 16)], ["Temple District", Rect2(-23, -24, 17, 22)],
		["Collapsed Aqueduct", Rect2(12, -24, 11, 25)], ["Meridian Forward Camp", Rect2(-6, -25, 18, 15)],
		["Royal Causeway", Rect2(-6, -55, 12, 30)], ["Hall of Weights", Rect2(-20, 30, 10, 8)],
		["Sunken Archive", Rect2(12, 7, 8, 6)], ["Resonant Chamber", Rect2(10.5, 34.5, 9, 7)]])
	preload("res://systems/environment/PhotoDressing.gd").apply(self, 7)
	preload("res://systems/environment/RelicHunt.gd").apply(self, 7)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C07", hud)
	MissionManager.register_objective("obj_c07_explore_city", "Explore the subterranean Vaelor ruins and examine the central plaza mural")
	
	if plaza_mural_interactable:
		plaza_mural_interactable.interacted.connect(_on_mural_examined)
	# The old XP-only "tomb" trigger is superseded by the playable tombs in Chapter7City.
	if optional_tomb_entrance:
		optional_tomb_entrance.monitoring = false
	if causeway_exit_trigger:
		causeway_exit_trigger.body_entered.connect(_on_causeway_exit)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		AudioManager.play_story_line("Mara", "The City of Echoes... Cyclopean towers stretching into the shadows. The Heart Vault is ahead.", 5.5)

func _on_mural_examined(_p: Node) -> void:
	if not has_read_mural:
		has_read_mural = true
		MissionManager.complete_objective("obj_c07_explore_city")
		city.begin_main_objectives()
		SkillManager.add_xp(120) # Grants XP for discovery
		if hud:
			AudioManager.play_story_line("Mara", "\"They knew the Vault was unstable... but they kept using it because it worked. Until it didn't.\"", 6.0)

func _on_optional_tomb_entered(body: Node) -> void:
	if body is Player and not has_visited_tomb:
		has_visited_tomb = true
		SkillManager.add_xp(150)
		print("[CHAPTER 7] Optional Challenge Tomb discovered: Tomb of Weights!")
		if hud:
			AudioManager.play_story_line("Mara", "An optional challenge chamber: The Tomb of Weights. Ancient counterweight engineering.", 4.5)

func _on_causeway_exit(body: Node) -> void:
	if body is Player and has_read_mural and city.gate_open and not transition_started:
		transition_started = true
		print("[CHAPTER 7] Reached expedition rendezvous! Transitioning to Chapter 8: The Betrayal.")
		if hud:
			AudioManager.play_story_line("Tomas (Radio)", "Mara, we're holding position at the forward camp! Hurry!", 4.0)
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(8, "res://levels/Chapter8.tscn")
