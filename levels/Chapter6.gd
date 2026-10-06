extends Node3D

## Chapter 6: The Drowned Temple - Water Puzzle & Aqueduct Diving
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var sluice_wheel: Interactable3D = $TempleMechanisms/SluiceWheel/Interactable3D
@onready var water_plane: CSGBox3D = $FloodedBasin/WaterPlane
@onready var sunken_gate: Node3D = $TempleSanctum/SunkenGate
@onready var exit_trigger: Area3D = $TempleSanctum/ExitTrigger

var is_reservoir_drained: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c06_drain_temple", "Navigate the submerged temple and rotate the sluice turbine")
	
	if sluice_wheel:
		sluice_wheel.interacted.connect(_on_sluice_wheel_rotated)
	if exit_trigger:
		exit_trigger.body_entered.connect(_on_temple_exit)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "The temple is half-submerged. I need to drain the central basin to reach the inner sanctum.", 5.0)

func _on_sluice_wheel_rotated(_p: Node) -> void:
	if not is_reservoir_drained:
		is_reservoir_drained = true
		print("[CHAPTER 6] Temple sluice wheel turned! Water draining.")
		if hud:
			hud.show_subtitle("Mara", "The aqueduct is flushing out! The lower gate is emerging from the water.", 5.0)
			
		# Lower water level and raise gate
		if water_plane:
			var tw_water = create_tween()
			tw_water.tween_property(water_plane, "position:y", -3.2, 4.0)
		if sunken_gate:
			var tw_gate = create_tween()
			tw_gate.tween_property(sunken_gate, "position:y", sunken_gate.position.y + 5.0, 4.0)
			
		MissionManager.complete_objective("obj_c06_drain_temple")
		MissionManager.register_objective("obj_c06_reach_city_passage", "Proceed through the drained gateway into the subterranean expanse")

func _on_temple_exit(body: Node) -> void:
	if body is Player and is_reservoir_drained:
		print("[CHAPTER 6] Drowned Temple solved! Transitioning to Chapter 7: City of Echoes.")
		if hud:
			hud.show_subtitle("Mara", "Nadiya... I found a city. A colossal subterranean metropolis.", 4.5)
		await get_tree().create_timer(4.5).timeout
		GameManager.load_chapter(7, "res://levels/Chapter7.tscn")
