extends Node3D

## Chapter 2: Whispers in Stone - Level Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var sluice_lever: Interactable3D = $HydraulicPuzzle/SluiceLever/Interactable3D
@onready var water_flow_mesh: CSGBox3D = $HydraulicPuzzle/WaterFlowMesh
@onready var counterweight: Node3D = $HydraulicPuzzle/Counterweight
@onready var sealed_gate: Node3D = $SanctuaryGate
@onready var puzzle_master: PuzzleMaster = $PuzzleMaster
@onready var inscription_tablet: Interactable3D = $Sanctuary/InscriptionTablet/Interactable3D
@onready var abyss_trigger: Area3D = $Sanctuary/AbyssTrigger

var is_water_diverted: bool = false
var has_read_inscription: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c02_open_gate", "Restore hydraulic water flow to lift the sanctuary gate")
	
	if sluice_lever:
		sluice_lever.interacted.connect(_on_sluice_lever_pulled)
	if inscription_tablet:
		inscription_tablet.interacted.connect(_on_inscription_examined)
	if abyss_trigger:
		abyss_trigger.body_entered.connect(_on_abyss_entered)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "The gate is locked by an ancient hydraulic counterweight. The water channel is blocked.", 5.0)

func _on_sluice_lever_pulled(_p: Node) -> void:
	if not is_water_diverted:
		is_water_diverted = true
		print("[CHAPTER 2] Sluice gate opened! Water flowing.")
		if hud:
			hud.show_subtitle("Mara", "Water's diverted into the conduit! The counterweight is filling.", 4.5)
			
		# Animate water channel and counterweight
		if water_flow_mesh:
			water_flow_mesh.visible = true
		if counterweight:
			var tw = create_tween()
			tw.tween_property(counterweight, "position:y", counterweight.position.y - 3.5, 3.0)
		if sealed_gate:
			var tw_gate = create_tween()
			tw_gate.tween_property(sealed_gate, "position:y", sealed_gate.position.y + 4.5, 3.5)
			
		MissionManager.complete_objective("obj_c02_open_gate")
		MissionManager.register_objective("obj_c02_explore_sanctuary", "Explore the inner sanctuary and examine the Vaelor inscription")

func _on_inscription_examined(_p: Node) -> void:
	if not has_read_inscription:
		has_read_inscription = true
		MissionManager.complete_objective("obj_c02_explore_sanctuary")
		MissionManager.register_objective("obj_c02_investigate_abyss", "Investigate the deep acoustic vertical shaft")
		if hud:
			hud.show_subtitle("Mara", "\"The Voice Below...\" It refers to a subterranean harmonic nexus deep in the mountain core.", 5.5)

func _on_abyss_entered(body: Node) -> void:
	if body is Player and has_read_inscription:
		print("[CHAPTER 2] Reached abyss overlook! Transitioning to Chapter 3: The Fall.")
		if hud:
			hud.show_subtitle("Tomas (Radio)", "Mara, Elias is bringing the bridge rig across now!", 4.0)
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(3, "res://levels/Chapter3.tscn")
