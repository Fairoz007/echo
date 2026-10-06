extends Node3D

## Chapter 10: The Heart Vault - Confrontation & Resonance Disruption
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var node_north: Interactable3D = $ResonanceChamber/NodeNorth/Interactable3D
@onready var node_south: Interactable3D = $ResonanceChamber/NodeSouth/Interactable3D
@onready var node_east: Interactable3D = $ResonanceChamber/NodeEast/Interactable3D
@onready var node_west: Interactable3D = $ResonanceChamber/NodeWest/Interactable3D

@onready var drake_encounter_trigger: Area3D = $CentralPlatform/DrakeTrigger
@onready var escape_trigger: Area3D = $CentralPlatform/EscapeTrigger

var active_nodes_disabled: int = 0
var has_drake_spoken: bool = false
var is_overload_triggered: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c10_confront_drake", "Approach the central harmonic platform and confront Lucian Drake")
	
	if drake_encounter_trigger:
		drake_encounter_trigger.body_entered.connect(_on_drake_encounter)
	if node_north:
		node_north.interacted.connect(func(_p): _disable_node("North"))
	if node_south:
		node_south.interacted.connect(func(_p): _disable_node("South"))
	if node_east:
		node_east.interacted.connect(func(_p): _disable_node("East"))
	if node_west:
		node_west.interacted.connect(func(_p): _disable_node("West"))
	if escape_trigger:
		escape_trigger.body_entered.connect(_on_escape_entered)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "The Heart Vault... The resonance in this chamber is deafening. There's Drake.", 5.0)

func _on_drake_encounter(body: Node) -> void:
	if body is Player and not has_drake_spoken:
		has_drake_spoken = true
		MissionManager.complete_objective("obj_c10_confront_drake")
		MissionManager.register_objective("obj_c10_disable_nodes", "Deactivate the four peripheral resonance nodes to stop catastrophic frequency overload")
		if hud:
			hud.show_subtitle("Drake", "\"Do you know what this is, Vale? A machine capable of transmitting tectonic kinetic energy across continents!\"", 6.0)

func _disable_node(node_name: String) -> void:
	active_nodes_disabled += 1
	print("[CHAPTER 10] Resonance node disabled:", node_name, "Total disabled:", active_nodes_disabled)
	if hud:
		hud.show_subtitle("Mara", "Node deactivated! Resonance dampening.", 3.0)
		
	if active_nodes_disabled >= 4 and not is_overload_triggered:
		is_overload_triggered = true
		MissionManager.complete_objective("obj_c10_disable_nodes")
		MissionManager.register_objective("obj_c10_escape_mountain", "The Vault is collapsing! Sprint to the extraction breach!")
		if hud:
			hud.show_subtitle("Drake", "\"No! What did you do?! The feedback is tearing the platform apart!\"", 5.0)
			await get_tree().create_timer(5.0).timeout
			hud.show_subtitle("Mara", "Drake, get out! It's over! RUN!", 4.0)

func _on_escape_entered(body: Node) -> void:
	if body is Player and is_overload_triggered:
		print("[CHAPTER 10] Escaping the Heart Vault! Transitioning to Finale: The Mountain Breaks.")
		GameManager.load_chapter(11, "res://levels/Finale.tscn")
