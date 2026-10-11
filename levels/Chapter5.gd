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
	RegionHandoff.prepare("res://levels/Chapter6.tscn") # background-loads the temple during Ch5
	var dressing := preload("res://systems/levelb/Chapter5Dressing.gd").new()
	add_child(dressing)
	dressing.build(self)
	preload("res://systems/environment/EnvironmentCollision.gd").attach(self)
	preload("res://systems/environment/RelicHunt.gd").apply(self, 5)
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
		# Unified world: the Drowned Temple builds beyond the gate while Mara heads for it.
		_stage_temple()
		MissionManager.complete_objective("obj_c05_observe_excavation")
		MissionManager.register_objective("obj_c05_enter_temple", "Enter the submerged Drowned Temple aqueduct")
		if hud:
			AudioManager.play_story_line("Drake (Below)", "\"Vale's team found the door. Secure the subterranean aqueduct immediately.\"", 5.0)

var temple: Node3D

## Adds Ch6 beyond the gate, joined by the Meridian aqueduct (Ch5Ch6Aqueduct). Mara walks
## through; Ch6 activates mid-aqueduct and this region fades out behind her.
func _stage_temple() -> void:
	if temple:
		return
	# Ch5's painted temple vista beyond the gate is replaced by the real temple.
	for n in ["LevelBDressing/TempleOverlook", "LevelBDressing/TempleBasinVista"]:
		var v := get_node_or_null(n) as Node3D
		if v:
			v.visible = false
	var gate := $TempleEntrance as Node3D
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(gate.global_position + Vector3.UP * 8.0, gate.global_position + Vector3.DOWN * 20.0, 2))
	var gate_floor: Vector3 = hit.position if hit else gate.global_position
	const AQUEDUCT := preload("res://systems/world/connectors/Ch5Ch6Aqueduct.gd")
	temple = RegionHandoff.stage(self, "res://levels/Chapter6.tscn", gate_floor, AQUEDUCT.GATE)
	temple.built.connect(func():
		temple.aqueduct.activation_area.body_entered.connect(func(body: Node):
			if body is Player:
				# Deferred: activation adds/removes physics objects, not allowed inside this callback.
				RegionHandoff.activate.call_deferred(self, temple, 6)), CONNECT_ONE_SHOT)

var gate_reached := false

func _on_chapter_end(body: Node) -> void:
	if body is Player and has_seen_drake and not gate_reached:
		gate_reached = true
		print("[CHAPTER 5] Infiltrated Drowned Temple! Entering the aqueduct to Chapter 6.")
		if hud:
			AudioManager.play_story_line("Mara", "Water's rushing into the temple basin. Time to dive.", 3.5)
		_stage_temple() # no-op if already staged (e.g. resumed from a save past the perch)
