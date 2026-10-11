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
var disabled_nodes: Array[String] = []

var transition_started := false

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(10)
	preload("res://systems/environment/PhotoDressing.gd").apply(self, 10)
	preload("res://systems/environment/RelicHunt.gd").apply(self, 10)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C10", hud)
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
		AudioManager.play_story_line("Mara", "The Heart Vault... The resonance in this chamber is deafening. There's Drake.", 5.0)

func _on_drake_encounter(body: Node) -> void:
	if body is Player and not has_drake_spoken:
		has_drake_spoken = true
		MissionManager.complete_objective("obj_c10_confront_drake")
		MissionManager.register_objective("obj_c10_disable_nodes", "Deactivate the four peripheral resonance nodes to stop catastrophic frequency overload")
		if hud:
			AudioManager.play_story_line("Drake", "\"Do you know what this is, Vale? A machine capable of transmitting tectonic kinetic energy across continents!\"", 6.0)

func _disable_node(node_name: String) -> void:
	if not has_drake_spoken or disabled_nodes.has(node_name):
		return
	disabled_nodes.append(node_name)
	active_nodes_disabled = disabled_nodes.size()
	var node_map := {"North": node_north, "South": node_south, "East": node_east, "West": node_west}
	node_map[node_name].is_enabled = false
	print("[CHAPTER 10] Resonance node disabled:", node_name, "Total disabled:", active_nodes_disabled)
	if hud:
		AudioManager.play_story_line("Mara", "Node deactivated! Resonance dampening.", 3.0)
		
	if active_nodes_disabled >= 4 and not is_overload_triggered:
		is_overload_triggered = true
		MissionManager.complete_objective("obj_c10_disable_nodes")
		MissionManager.register_objective("obj_c10_escape_mountain", "The Vault is collapsing! Sprint to the extraction breach!")
		if hud:
			AudioManager.play_story_line("Drake", "\"No! What did you do?! The feedback is tearing the platform apart!\"", 5.0)
			await get_tree().create_timer(5.0).timeout
			AudioManager.play_story_line("Mara", "Drake, get out! It's over! RUN!", 4.0)

func _on_escape_entered(body: Node) -> void:
	if body is Player and is_overload_triggered and not transition_started:
		transition_started = true
		print("[CHAPTER 10] Escaping the Heart Vault! Transitioning to Finale: The Mountain Breaks.")
		GameManager.load_chapter(11, "res://levels/Finale.tscn")

func get_persistent_state() -> Dictionary:
	return {"disabled_nodes": disabled_nodes.duplicate()}

func restore_persistent_state(data: Dictionary) -> void:
	disabled_nodes.assign(data.get("disabled_nodes", []))
	active_nodes_disabled = disabled_nodes.size()
	var nodes := {"North": node_north, "South": node_south, "East": node_east, "West": node_west}
	for key in disabled_nodes:
		if nodes.has(key):
			nodes[key].is_enabled = false
