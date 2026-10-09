extends Node3D

## Chapter 3: The Fall - Bridge Collapse Sequence Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var bridge_section_1: RigidBody3D = $BridgeStructure/BridgeSection1
@onready var bridge_section_2: RigidBody3D = $BridgeStructure/BridgeSection2
@onready var bridge_trigger: Area3D = $BridgeStructure/CollapseTrigger
@onready var fissure_fall_trigger: Area3D = $FissureAbyssTrigger

var has_collapse_triggered: bool = false

var transition_started := false

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.STRONG, 0.0)
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(3)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C03", hud)
	MissionManager.register_objective("obj_c03_cross_bridge", "Cross the ancient cyclopean bridge span")
	
	if bridge_trigger:
		bridge_trigger.body_entered.connect(_on_bridge_collapse_entered)
	if fissure_fall_trigger:
		fissure_fall_trigger.body_entered.connect(_on_fissure_fell)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		AudioManager.play_story_line("Elias (Radio)", "Mara, take the center line! The stone anchors look brittle.", 4.5)

func _on_bridge_collapse_entered(body: Node) -> void:
	if body is Player and not has_collapse_triggered:
		has_collapse_triggered = true
		AudioManager.play_sfx("collapse", bridge_trigger.global_position)
		print("[CHAPTER 3] Structural failure triggered! Bridge collapsing.")
		if hud:
			AudioManager.play_story_line("Mara", "The anchors are giving way! JUMP!", 3.0)
			
		# Release physical bridge pieces
		if bridge_section_1:
			bridge_section_1.freeze = false
		if bridge_section_2:
			bridge_section_2.freeze = false

func _on_fissure_fell(body: Node) -> void:
	if body is Player and not transition_started:
		transition_started = true
		print("[CHAPTER 3] Player fell through subterranean fissure! Transitioning to Chapter 4: Beneath.")
		if hud:
			AudioManager.play_story_line("Mara", "ELIAS!...", 2.5)
		await get_tree().create_timer(2.5).timeout
		GameManager.load_chapter(4, "res://levels/Chapter4.tscn")
