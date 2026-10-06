extends Node3D

## Chapter 8: The Betrayal - Narrative Confrontation & Relic Theft
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var elias_interactable: Interactable3D = $SurvivorCamp/InjuredElias/Interactable3D
@onready var adrian_trigger: Area3D = $Passage/AdrianConfrontationTrigger

var has_spoken_to_elias: bool = false
var has_confronted_adrian: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c08_reunite_expedition", "Reunite with the surviving expedition team at the forward sanctuary")
	
	if elias_interactable:
		elias_interactable.interacted.connect(_on_elias_spoke)
	if adrian_trigger:
		adrian_trigger.body_entered.connect(_on_adrian_confrontation)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "I see expedition gear ahead! Elias, Nadiya!", 4.0)

func _on_elias_spoke(_p: Node) -> void:
	if not has_spoken_to_elias:
		has_spoken_to_elias = true
		MissionManager.complete_objective("obj_c08_reunite_expedition")
		MissionManager.register_objective("obj_c08_pursue_adrian", "Pursue Adrian Kell through the Heart Road breach")
		if hud:
			hud.show_subtitle("Elias (Injured)", "Mara... Adrian took the Vaelor Key. He's been transmitting coordinates to Meridian all along.", 5.5)

func _on_adrian_confrontation(body: Node) -> void:
	if body is Player and has_spoken_to_elias and not has_confronted_adrian:
		has_confronted_adrian = true
		print("[CHAPTER 8] Adrian confrontation! Transitioning to Chapter 9: The Heart Road.")
		if hud:
			hud.show_subtitle("Adrian (Radio)", "\"I'm sorry Mara. They offered a life beyond research grants. But Drake brought guns...\"", 5.0)
		await get_tree().create_timer(5.0).timeout
		GameManager.load_chapter(9, "res://levels/Chapter9.tscn")
