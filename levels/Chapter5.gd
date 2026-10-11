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
## Stealth route: reaching the perch without any mercenary entering COMBAT bypasses the fight.
var was_detected: bool = false

var transition_started := false

const RegionHandoff := preload("res://systems/world/RegionHandoff.gd")

func _ready() -> void:
	WindSystem.set_preset(WindSystem.Preset.BREEZE, 0.0)
	var dressing := preload("res://systems/levelb/Chapter5Dressing.gd").new()
	add_child(dressing)
	dressing.build(self)
	preload("res://systems/environment/EnvironmentCollision.gd").attach(self)
	preload("res://systems/environment/BlockoutDresser.gd").apply(self)
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(5)
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C05", hud)
	dressing.hook_audio(preload("res://systems/audio/Soundscape.gd").attach(self, "C05"))
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
		AudioManager.play_story_line("Mara", "Meridian mercenaries ahead. Stay low, use cover, or take them down quietly.", 5.0)

func _physics_process(_delta: float) -> void:
	if was_detected or has_seen_drake:
		return
	for e in [enemy_1, enemy_2]:
		if is_instance_valid(e) and e.current_state == EnemyBase.AIState.COMBAT:
			was_detected = true
			return

func _on_enemy_defeated(_e: EnemyBase) -> void:
	enemies_remaining -= 1
	print("[CHAPTER 5] Enemy neutralized. Remaining:", enemies_remaining)
	if enemies_remaining <= 0 and not has_seen_drake:
		MissionManager.complete_objective("obj_c05_neutralize_patrol")
		MissionManager.register_objective("obj_c05_observe_excavation", "Reach the observation ledge overlooking the Drowned Temple")
		if drake_observation_trigger.overlaps_body(player):
			_on_drake_observed(player)

func _on_drake_observed(body: Node) -> void:
	if not (body is Player) or has_seen_drake:
		return
	if enemies_remaining > 0 and not was_detected:
		# Ghosted the checkpoint: the patrol never saw Mara.
		MissionManager.complete_objective("obj_c05_neutralize_patrol")
		if hud:
			AudioManager.play_story_line("Mara", "Past them. They never knew I was here.", 3.0)
	if enemies_remaining <= 0 or not was_detected:
		has_seen_drake = true
		# Unified world: start streaming the Drowned Temple while Mara heads for its entrance.
		RegionHandoff.prepare("res://levels/Chapter6.tscn")
		MissionManager.complete_objective("obj_c05_observe_excavation")
		MissionManager.register_objective("obj_c05_enter_temple", "Enter the submerged Drowned Temple aqueduct")
		if hud:
			AudioManager.play_story_line("Drake (Below)", "\"Vale's team found the door. Secure the subterranean aqueduct immediately.\"", 5.0)

func _on_chapter_end(body: Node) -> void:
	if body is Player and has_seen_drake and not transition_started:
		transition_started = true
		print("[CHAPTER 5] Infiltrated Drowned Temple! Transitioning to Chapter 6.")
		if hud:
			AudioManager.play_story_line("Mara", "Water's rushing into the temple basin. Time to dive.", 3.5)
		# Walk straight onto the temple's entry landing: no card, fade or respawn.
		RegionHandoff.hand_off(self, 6, "res://levels/Chapter6.tscn", Vector3(0.0, 1.0, 22.5))
