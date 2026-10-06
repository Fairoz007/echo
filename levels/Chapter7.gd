extends Node3D

## Chapter 7: City of Echoes - Subterranean Hub & Optional Tomb Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var plaza_mural_interactable: Interactable3D = $CentralPlaza/HistoryMural/Interactable3D
@onready var optional_tomb_entrance: Area3D = $OptionalTomb/TombTrigger
@onready var causeway_exit_trigger: Area3D = $RoyalCauseway/CausewayExitTrigger

var has_read_mural: bool = false
var has_visited_tomb: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c07_explore_city", "Explore the subterranean Vaelor ruins and examine the central plaza mural")
	
	if plaza_mural_interactable:
		plaza_mural_interactable.interacted.connect(_on_mural_examined)
	if optional_tomb_entrance:
		optional_tomb_entrance.body_entered.connect(_on_optional_tomb_entered)
	if causeway_exit_trigger:
		causeway_exit_trigger.body_entered.connect(_on_causeway_exit)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "The City of Echoes... Cyclopean towers stretching into the shadows. The Heart Vault is ahead.", 5.5)

func _on_mural_examined(_p: Node) -> void:
	if not has_read_mural:
		has_read_mural = true
		MissionManager.complete_objective("obj_c07_explore_city")
		MissionManager.register_objective("obj_c07_cross_causeway", "Proceed along the Royal Causeway toward the Expedition Rendezvous")
		SkillManager.add_xp(120) # Grants XP for discovery
		if hud:
			hud.show_subtitle("Mara", "\"They knew the Vault was unstable... but they kept using it because it worked. Until it didn't.\"", 6.0)

func _on_optional_tomb_entered(body: Node) -> void:
	if body is Player and not has_visited_tomb:
		has_visited_tomb = true
		SkillManager.add_xp(150)
		print("[CHAPTER 7] Optional Challenge Tomb discovered: Tomb of Weights!")
		if hud:
			hud.show_subtitle("Mara", "An optional challenge chamber: The Tomb of Weights. Ancient counterweight engineering.", 4.5)

func _on_causeway_exit(body: Node) -> void:
	if body is Player and has_read_mural:
		print("[CHAPTER 7] Reached expedition rendezvous! Transitioning to Chapter 8: The Betrayal.")
		if hud:
			hud.show_subtitle("Tomas (Radio)", "Mara, we're holding position at the forward camp! Hurry!", 4.0)
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(8, "res://levels/Chapter8.tscn")
