extends Node3D

## Chapter 9: The Heart Road - Tremor Traversal & Seismic Collapse
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var falling_rock_1: RigidBody3D = $CollapsingRoute/FallingRock1
@onready var tremor_trigger: Area3D = $CollapsingRoute/TremorTrigger
@onready var vault_gate_trigger: Area3D = $VaultThreshold/VaultGateTrigger

var has_tremor_occurred: bool = false

var transition_started := false

func _ready() -> void:
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(9)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C09", hud)
	MissionManager.register_objective("obj_c09_cross_heart_road", "Traverse the seismic fractures along the Heart Road")
	
	if tremor_trigger:
		tremor_trigger.body_entered.connect(_on_tremor_triggered)
	if vault_gate_trigger:
		vault_gate_trigger.body_entered.connect(_on_vault_gate_reached)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		AudioManager.play_story_line("Mara", "The entire mountain is trembling. Meridian's blasting destabilized the resonance conduits.", 5.0)

func _on_tremor_triggered(body: Node) -> void:
	if body is Player and not has_tremor_occurred:
		has_tremor_occurred = true
		AudioManager.play_sfx("collapse", tremor_trigger.global_position)
		print("[CHAPTER 9] Seismic tremor! Falling debris.")
		if hud:
			AudioManager.play_story_line("Mara", "Ceiling collapse! Keep moving!", 3.0)
		if falling_rock_1:
			falling_rock_1.freeze = false

func _on_vault_gate_reached(body: Node) -> void:
	if body is Player and not transition_started:
		transition_started = true
		print("[CHAPTER 9] Reached Heart Vault threshold! Transitioning to Chapter 10: The Heart Vault.")
		if hud:
			AudioManager.play_story_line("Mara", "This is it. The threshold of the Heart Vault. Drake is inside.", 4.0)
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(10, "res://levels/Chapter10.tscn")
