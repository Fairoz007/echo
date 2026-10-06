extends Node3D

## Chapter 5: Hunters - Tactical Stealth & Combat Controller
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var enemy_1: EnemyBase = $Enemies/EnemyMercenary1
@onready var enemy_2: EnemyBase = $Enemies/EnemyMercenary2
@onready var drake_observation_trigger: Area3D = $ObservationPerch/DrakeTrigger
@onready var chapter_end_trigger: Area3D = $TempleEntrance/ChapterEndTrigger

var enemies_remaining: int = 2
var has_seen_drake: bool = false

func _ready() -> void:
	MissionManager.register_objective("obj_c05_neutralize_patrol", "Infiltrate the Meridian checkpoint using stealth or combat")
	
	if enemy_1:
		enemy_1.enemy_died.connect(_on_enemy_defeated)
	if enemy_2:
		enemy_2.enemy_died.connect(_on_enemy_defeated)
	if drake_observation_trigger:
		drake_observation_trigger.body_entered.connect(_on_drake_observed)
	if chapter_end_trigger:
		chapter_end_trigger.body_entered.connect(_on_chapter_end)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		hud.show_subtitle("Mara", "Meridian mercenaries ahead. Stay low, use cover, or take them down quietly.", 5.0)

func _on_enemy_defeated(_e: EnemyBase) -> void:
	enemies_remaining -= 1
	print("[CHAPTER 5] Enemy neutralized. Remaining:", enemies_remaining)
	if enemies_remaining <= 0:
		MissionManager.complete_objective("obj_c05_neutralize_patrol")
		MissionManager.register_objective("obj_c05_observe_excavation", "Reach the observation ledge overlooking the Drowned Temple")

func _on_drake_observed(body: Node) -> void:
	if body is Player and not has_seen_drake:
		has_seen_drake = true
		MissionManager.complete_objective("obj_c05_observe_excavation")
		MissionManager.register_objective("obj_c05_enter_temple", "Enter the submerged Drowned Temple aqueduct")
		if hud:
			hud.show_subtitle("Drake (Below)", "\"Vale's team found the door. Secure the subterranean aqueduct immediately.\"", 5.0)

func _on_chapter_end(body: Node) -> void:
	if body is Player and has_seen_drake:
		print("[CHAPTER 5] Infiltrated Drowned Temple! Transitioning to Chapter 6.")
		if hud:
			hud.show_subtitle("Mara", "Water's rushing into the temple basin. Time to dive.", 3.5)
		await get_tree().create_timer(3.5).timeout
		GameManager.load_chapter(6, "res://levels/Chapter6.tscn")
