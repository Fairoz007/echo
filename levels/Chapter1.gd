extends Node3D

## Chapter 1: The Arrival - Level Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var nadiya_interactable: Interactable3D = $CampArea/NadiyaNPC/Interactable3D
@onready var elias_interactable: Interactable3D = $CampArea/EliasNPC/Interactable3D
@onready var survey_table_interactable: Interactable3D = $CampArea/SurveyTable/Interactable3D
@onready var sealed_gate_interactable: Interactable3D = $RidgeArea/SealedPortal/Interactable3D
@onready var chapter_end_trigger: Area3D = $RidgeArea/ChapterEndTrigger

var has_spoken_to_nadiya: bool = false
var has_spoken_to_elias: bool = false
var has_examined_map: bool = false

func _ready() -> void:
	# Register starting objective
	MissionManager.register_objective("obj_c01_meet_team", "Regroup with Elias at the Expedition Camp")
	
	if nadiya_interactable:
		nadiya_interactable.interacted.connect(_on_nadiya_talk)
	if elias_interactable:
		elias_interactable.interacted.connect(_on_elias_talk)
	if survey_table_interactable:
		survey_table_interactable.interacted.connect(_on_survey_table_examined)
	if sealed_gate_interactable:
		sealed_gate_interactable.interacted.connect(_on_sealed_gate_examined)
	if chapter_end_trigger:
		chapter_end_trigger.body_entered.connect(_on_chapter_end_entered)
		
	# Opening monologue
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "Made it through the ridge. The expedition camp is just ahead.", 4.0)

func _on_nadiya_talk(_p: Node) -> void:
	if not has_spoken_to_nadiya:
		has_spoken_to_nadiya = true
		if hud:
			hud.show_subtitle("Nadiya", "Three days late, Mara! Elias is over by the survey table waiting for you.", 4.5)
	else:
		if hud:
			hud.show_subtitle("Nadiya", "Get moving, Mara. The satellite pass was clear, but clouds are gathering.", 3.5)

func _on_elias_talk(_p: Node) -> void:
	if not has_spoken_to_elias:
		has_spoken_to_elias = true
		if hud:
			hud.show_subtitle("Elias", "Mara! Look at the satellite telemetry on the table. We found a sub-ridge anomaly.", 5.0)
		MissionManager.register_objective("obj_c01_inspect_map", "Examine the topographic survey table")
	else:
		if hud:
			hud.show_subtitle("Elias", "Head up the eastern trail toward the waterfall gorge. Be careful on the rock ledges.", 4.5)

func _on_survey_table_examined(_p: Node) -> void:
	if not has_examined_map:
		has_examined_map = true
		MissionManager.complete_objective("obj_c01_meet_team")
		MissionManager.complete_objective("obj_c01_inspect_map")
		MissionManager.register_objective("obj_c01_reach_ridge", "Ascend the Eastern Ridge trail and locate the sealed portal")
		if hud:
			hud.show_subtitle("Mara", "Symmetrical subterranean chambers... That's not a natural fault. I'll check the eastern ridge.", 5.0)

func _on_sealed_gate_examined(_p: Node) -> void:
	MissionManager.complete_objective("obj_c01_reach_ridge")
	MissionManager.register_objective("obj_c01_investigate_gate", "Report the discovered portal to Elias via radio")
	if hud:
		hud.show_subtitle("Mara", "Elias... I found it. A massive sealed stone doorway carved right into the mountain cliff.", 5.0)
		await get_tree().create_timer(5.2).timeout
		hud.show_subtitle("Elias (Radio)", "Incredible! Don't touch anything yet. I'm bringing Tomas and the equipment.", 5.0)

func _on_chapter_end_entered(body: Node) -> void:
	if body is Player and has_examined_map:
		print("[CHAPTER 1] Reached Eastern Ridge Portal! Transitioning to Chapter 2.")
		if hud:
			hud.show_subtitle("Mara", "The carvings match the Vaelor texts... This is where it begins.", 3.5)
		await get_tree().create_timer(3.5).timeout
		GameManager.load_chapter(2, "res://levels/Chapter2.tscn")
