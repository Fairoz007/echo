extends Node3D

## Prologue Level Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var monolithic_door: Node3D = $MonolithicDoor
@onready var resonant_artifact_interactable: Interactable3D = $ResonantArtifact/Interactable3D
@onready var exit_trigger: Area3D = $ExitTrigger

func _ready() -> void:
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
	if hud:
		hud.show_subtitle("Mara", "Ugh... Still breathing. Flashlight works. Need to find a way through.", 4.5)

func _on_artifact_interacted(_p: Node) -> void:
	print("[PROLOGUE] Player examined the Vaelor Acoustic Relic!")
	MissionManager.complete_objective("obj_prologue_explore")
	MissionManager.register_objective("obj_prologue_exit", "Examine the vibrating monolithic portal")
	
	if hud:
		hud.show_subtitle("Mara", "This key... it's humming. Harmonizing with the stone walls.", 4.0)

func _on_exit_entered(body: Node) -> void:
	if body is Player:
		print("[PROLOGUE] Reached monolithic portal threshold! Transitioning to Chapter 1.")
		MissionManager.complete_objective("obj_prologue_exit")
		if hud:
			hud.show_subtitle("Mara", "What did we find?...", 3.0)
		await get_tree().create_timer(3.0).timeout
		GameManager.load_chapter(1, "res://levels/Chapter1.tscn")
