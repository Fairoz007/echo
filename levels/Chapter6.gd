extends Node3D

## Chapter 6: The Drowned Temple - Water Puzzle & Aqueduct Diving
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var sluice_wheel: Interactable3D = $TempleMechanisms/SluiceWheel/Interactable3D
@onready var water_plane: Node3D = $FloodedBasin/WaterPlane
@onready var sunken_gate: Node3D = $TempleSanctum/SunkenGate
@onready var exit_trigger: Area3D = $TempleSanctum/ExitTrigger

var is_reservoir_drained: bool = false

var transition_started := false

var dressing
var aqueduct

## Unified world: set by RegionHandoff.stage() before _ready. The world is then built over
## several frames while Mara is still in Ch5, and gameplay (objectives, audio, wind, dialogue)
## waits for activate(), which the aqueduct's RegionActivation area triggers out of sight.
var staged := false
var is_active := false
var is_built := false
signal activated
signal built

func _ready() -> void:
	if not staged:
		WindSystem.set_preset(WindSystem.Preset.CAVE, 0.0)
	dressing = preload("res://systems/levelb/Chapter6Dressing.gd").new()
	dressing.step_yield = staged
	add_child(dressing)
	await dressing.build(self)
	var _t := Time.get_ticks_msec()
	aqueduct = preload("res://systems/world/connectors/Ch5Ch6Aqueduct.gd").new()
	add_child(aqueduct)
	aqueduct.build(dressing.aqueduct_stone)
	aqueduct.open_to_previous_region(staged)
	if staged:
		print("[REGION] Ch6 aqueduct %d ms" % (Time.get_ticks_msec() - _t))
		await get_tree().process_frame
		_t = Time.get_ticks_msec()
	preload("res://systems/environment/EnvironmentCollision.gd").attach(self)
	if staged:
		print("[REGION] Ch6 collision %d ms" % (Time.get_ticks_msec() - _t))
		await get_tree().process_frame
		_t = Time.get_ticks_msec()
	preload("res://systems/environment/BlockoutDresser.gd").apply(self)
	if staged:
		print("[REGION] Ch6 blockout %d ms" % (Time.get_ticks_msec() - _t))
		await get_tree().process_frame
		_t = Time.get_ticks_msec()
	var exploration := preload("res://systems/CampaignExploration.gd").new()
	add_child(exploration)
	exploration.configure(6)
	$TempleSanctum/SunkenGate/GateMesh.hide()
	exploration._place_model(sunken_gate, "res://assets/environment/cave/cave_wall_limestone.glb", Vector3(8, 6, 1), Vector3.ZERO)
	var ramp := StaticBody3D.new()
	ramp.name = "AqueductExitRamp"
	ramp.collision_layer = 2
	add_child(ramp)
	ramp.position = Vector3(0, -1.8, -23)
	ramp.rotation.x = atan(3.8 / 24.0)
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	# Solid backing prevents approaching from below and walking under the ramp.
	# Keep its top face aligned with the original 0.25m art surface.
	ramp_box.size = Vector3(5, 4, 24)
	ramp_shape.position.y = -1.875
	ramp_shape.shape = ramp_box
	ramp.add_child(ramp_shape)
	exploration._place_model(ramp, "res://assets/environment/cave/cave_floor_sediment.glb", Vector3(5, 0.25, 24), Vector3.ZERO)
	is_built = true
	if staged:
		print("[REGION] Ch6 exploration+misc %d ms" % (Time.get_ticks_msec() - _t))
		built.emit()
		await activated
		WindSystem.set_preset(WindSystem.Preset.CAVE, 6.0) # eases in while walking the aqueduct
	is_active = true
	var campaign_dialogue := preload("res://systems/CampaignDialogue.gd").new()
	add_child(campaign_dialogue)
	campaign_dialogue.configure("C06", hud)
	dressing.hook_audio(preload("res://systems/audio/Soundscape.gd").attach(self, "C06"))
	# Production water: WaterBody FLOODED_TEMPLE owned by Chapter6Dressing (legacy WaterVolume retired).
	MissionManager.register_objective("obj_c06_drain_temple", "Navigate the submerged temple and rotate the sluice turbine")
	
	if sluice_wheel:
		sluice_wheel.interacted.connect(_on_sluice_wheel_rotated)
	if exit_trigger:
		exit_trigger.body_entered.connect(_on_temple_exit)
		
	await get_tree().create_timer(1.2).timeout
	if hud:
		AudioManager.play_story_line("Mara", "The temple is half-submerged. I need to drain the central basin to reach the inner sanctum.", 5.0)

func _on_sluice_wheel_rotated(_p: Node) -> void:
	if not is_reservoir_drained:
		is_reservoir_drained = true
		print("[CHAPTER 6] Temple sluice wheel turned! Water draining.")
		if hud:
			AudioManager.play_story_line("Mara", "The aqueduct is flushing out! The lower gate is emerging from the water.", 5.0)
			
		# Lower water level and raise gate
		dressing.drain(4.0)
		if water_plane:
			var tw_water = create_tween()
			tw_water.tween_property(water_plane, "position:y", -3.2, 4.0)
		if sunken_gate:
			var tw_gate = create_tween()
			tw_gate.tween_property(sunken_gate, "position:y", sunken_gate.position.y + 5.0, 4.0)
			
		MissionManager.complete_objective("obj_c06_drain_temple")
		MissionManager.register_objective("obj_c06_reach_city_passage", "Proceed through the drained gateway into the subterranean expanse")

func _on_temple_exit(body: Node) -> void:
	if body is Player and is_reservoir_drained and not transition_started:
		transition_started = true
		print("[CHAPTER 6] Drowned Temple solved! Transitioning to Chapter 7: City of Echoes.")
		if hud:
			AudioManager.play_story_line("Mara", "Nadiya... I found a city. A colossal subterranean metropolis.", 4.5)
		await get_tree().create_timer(4.5).timeout
		GameManager.load_chapter(7, "res://levels/Chapter7.tscn")


## Capture/QA helper: run the drain without walking to the wheel.
func debug_drain() -> void:
	_on_sluice_wheel_rotated(player)
