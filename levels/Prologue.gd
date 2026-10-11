extends Node3D

## Prologue Level Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var monolithic_door: Node3D = $ArchPortalModel
@onready var resonant_artifact_interactable: Interactable3D = $ResonantArtifact/Interactable3D
@onready var exit_trigger: Area3D = $ExitTrigger
var artifact_acquired := false
var transition_started := false
var soundscape: Node3D
var save_restored := false
var _sequence_revision := 0

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)
	soundscape = preload("res://systems/PrologueSoundscape.gd").new()
	add_child(soundscape)
	preload("res://systems/environment/PhotoDressing.gd").apply(self, 0)
	preload("res://systems/environment/RelicHunt.gd").apply(self, 0)
	# Register Prologue Objective
	MissionManager.register_objective("obj_prologue_explore", "Navigate the collapsed subterranean tunnel")
	
	# HUD binds automatically via 'player' group
		
	# Hook up interaction
	if resonant_artifact_interactable:
		resonant_artifact_interactable.interacted.connect(_on_artifact_interacted)
		
	if exit_trigger:
		exit_trigger.body_entered.connect(_on_exit_entered)
		
	# Play opening monologue subtitle
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if not artifact_acquired and not transition_started and not save_restored:
		var duration := AudioManager.play_dialogue("PRO_MARA_001", hud, "Mara", "Ugh... Still breathing. Radio... Nadiya? Elias? Anyone?", 5.5)
		await get_tree().create_timer(duration).timeout
		if not is_inside_tree():
			return
		if not artifact_acquired and not transition_started and not save_restored:
			AudioManager.play_dialogue("PRO_MARA_002", hud, "Mara", "Right. Up. One step at a time.", 3.0)

func _on_artifact_interacted(_p: Node) -> void:
	if artifact_acquired or transition_started:
		return
	artifact_acquired = true
	resonant_artifact_interactable.is_enabled = false
	soundscape.play_event("res://audio/movement/FOL_PRO_CLOTH_SHIFT.wav", Vector3.ZERO, -23.0, false)
	soundscape.play_event("res://audio/vaelor/SFX_PRO_VAELOR_KEY_ACTIVATE.wav", $ResonantArtifact.global_position, -10.0)
	soundscape.play_event("res://audio/ui/SFX_PRO_UI_OBJECTIVE.wav", Vector3.ZERO, -20.0, false)
	print("[PROLOGUE] Player examined the Vaelor Acoustic Relic!")
	MissionManager.complete_objective("obj_prologue_explore")
	MissionManager.register_objective("obj_prologue_exit", "Examine the vibrating monolithic portal")
	
	AudioManager.play_dialogue("PRO_MARA_003", hud, "Mara", "This stone... it's vibrating. Not from seismic tremors. It's humming.", 5.0)

func _on_exit_entered(body: Node) -> void:
	if body is Player and artifact_acquired and not transition_started:
		transition_started = true
		var revision := _sequence_revision
		print("[PROLOGUE] Reached monolithic portal threshold! Transitioning to Chapter 1.")
		MissionManager.complete_objective("obj_prologue_exit")
		var duration := AudioManager.play_dialogue("PRO_MARA_004", hud, "Mara", "What did we find?", 3.0)
		await get_tree().create_timer(duration).timeout
		if not is_inside_tree():
			return
		if revision != _sequence_revision:
			return
		AudioManager.stop_dialogue()
		GameManager.load_chapter(1, "res://levels/Chapter1.tscn")

func on_save_restored() -> void:
	_sequence_revision += 1
	save_restored = true
	transition_started = false
	AudioManager.stop_dialogue()
	if artifact_acquired:
		resonant_artifact_interactable.is_enabled = false
		if player.nearby_interactable == resonant_artifact_interactable:
			player.nearby_interactable = null
			player.interactable_lost.emit()
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	if artifact_acquired and is_instance_valid(exit_trigger) and exit_trigger.overlaps_body(player):
		_on_exit_entered(player)
