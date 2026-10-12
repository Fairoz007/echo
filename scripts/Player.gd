extends CharacterBody3D
class_name Player
const RAGDOLL := preload("res://scripts/Ragdoll.gd")

## Third-person controller for Mara Vale.
## Movement contract and measured values: see MOVEMENT_TUNING.md.

@export_group("Locomotion Speeds (m/s)")
@export var walk_speed: float = 1.6
@export var run_speed: float = 3.6
@export var sprint_speed: float = 5.6
@export var crouch_speed: float = 1.3
@export var swim_speed: float = 1.6
@export var swim_sprint_speed: float = 2.4
@export var swim_vertical_speed: float = 1.4
@export var climb_speed: float = 1.1

@export_group("Acceleration (m/s^2)")
@export var ground_acceleration: float = 14.0
@export var ground_deceleration: float = 18.0
@export var air_acceleration: float = 3.5
@export var water_acceleration: float = 4.0
@export var rotation_speed: float = 10.0 ## rad/s turn rate of the body toward the move direction
@export var sprint_rotation_speed: float = 6.5

@export_group("Jump & Gravity")
@export var base_gravity: float = 9.8
@export var fall_gravity_multiplier: float = 1.9
@export var jump_cut_gravity_multiplier: float = 2.4 ## applied while rising with jump released
@export var jump_apex_height: float = 1.1
@export var terminal_velocity: float = 40.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15
@export var hard_landing_speed: float = 9.0
@export var damage_landing_speed: float = 15.0
@export var landing_damage_per_mps: float = 12.0

@export_group("Body")
@export var character_height: float = 1.70 ## visual height Mara is normalised to
@export var capsule_radius: float = 0.30
@export var capsule_height: float = 1.72
@export var crouch_capsule_height: float = 1.15
@export var max_slope_degrees: float = 44.0
@export var max_step_height: float = 0.35
@export var floor_snap: float = 0.32

@export_group("Traversal")
@export var mantle_min_height: float = 0.45
@export var mantle_max_height: float = 1.9
@export var mantle_reach: float = 0.75
@export var world_collision_mask: int = 2

@export_group("Vitals")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_oxygen: float = 30.0
var current_health: float = 100.0
var current_stamina: float = 100.0
var current_oxygen: float = 30.0

@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D
@export var visual_mesh: Node3D
@export var flashlight: SpotLight3D
@export var interaction_detector: Area3D
@export var anim_player: AnimationPlayer

@export_group("Animation Mapping")
## Logical animation slot -> candidate clip names (first existing wins). Data-driven
## so a re-rigged Mara with more clips only needs this dictionary edited.
@export var clip_candidates: Dictionary = {
	"idle": ["idle", "Idle", "idle_loop", "Idle_Loop"],
	"walk": ["walk", "Walk", "walk_loop", "Walking"],
	"run": ["run", "Run", "jog", "Running"],
	"sprint": ["sprint", "Sprint", "run_fast"],
	"jump": ["jump", "Jump", "jump_start"],
	"fall": ["fall", "Fall", "falling", "fall_loop"],
	"land": ["land", "Land", "landing"],
	"crouch_idle": ["crouch_idle", "Crouch_Idle", "crouch"],
	"crouch_walk": ["crouch_walk", "Crouch_Walk", "sneak"],
	"climb": ["climb", "Climb", "climb_loop"],
	"mantle": ["mantle", "Mantle", "vault", "climb_ledge"],
	"swim_idle": ["swim_idle", "tread", "treading_water"],
	"swim": ["swim", "Swim", "swim_forward", "dive"], # dive = stand-in until a swim clip exists
}
## Slot used when a slot has no clip. Chains always terminate at "idle".
@export var clip_fallback: Dictionary = {
	"walk": "idle", "run": "walk", "sprint": "run", "jump": "idle", "fall": "idle",
	"land": "idle", "crouch_idle": "idle", "crouch_walk": "walk", "climb": "idle",
	"mantle": "climb", "swim_idle": "swim", "swim": "idle",
}
## Clip -> ground speed (m/s) at playback scale 1. Measured from root travel when the
## clip has a Hip/Root translation track; otherwise taken from here.
@export var clip_cycle_speed_override: Dictionary = {}
## Playback scale used when the sprint slot falls back to the run clip.
@export var sprint_from_run_scale: float = 1.35
@export var default_cycle_speed: Dictionary = {"walk": 1.4, "run": 3.5, "sprint": 5.5, "crouch_walk": 1.0, "swim": 1.2, "climb": 0.8}

# Kept for compatibility with older callers.
var gait_phase: float = 0.0
var step_timer: float = 0.0
var visual_base_y: float = 0.0

enum State {
	IDLE,
	WALK,
	RUN,
	SPRINT,
	CROUCH,
	JUMP,
	FALL,
	VAULT,
	MANTLE,
	LEDGE_HANG,
	SWIM,
	DEAD,
	CLIMB,
}

var current_state: State = State.IDLE
var is_flashlight_on: bool = false
var gravity: float = 9.8
var nearby_interactable: Interactable3D = null

# Water (see MOVEMENT_TUNING.md "Water contract")
var water_surface: float = 0.0
var water_vertical_velocity := 0.0
var underwater := false
var in_water := false
var water_depth := 0.0 ## surface height minus feet height (<=0 when dry)
var _legacy_water := false
var _water_body: Node = null
const SWIM_ENTER_DEPTH := 1.25
const SWIM_EXIT_DEPTH := 1.0
const SWIM_FLOAT_DEPTH := 1.38 ## feet below surface while floating: shoulders at the waterline
const WADE_DEPTH := 0.5

# Mantle
var mantle_target_pos: Vector3 = Vector3.ZERO
var mantle_timer: float = 0.0
var _mantle_points: Array[Vector3] = []
var _mantle_durations: Array[float] = []
var _mantle_segment := 0

# Climb
var _climb_normal := Vector3.ZERO

# Combat (unchanged behaviour)
var ammunition := 12
var reserve_ammunition := 60
var magazine_capacity := 12
var weapon_cooldown := 0.0
var reload_timer := 0.0
var melee_cooldown := 0.0
var is_aiming := false
var sidearm_visual: Node3D
var pick_visual: Node3D

# Movement internals
var facing_yaw := 0.0
var is_crouching := false
var camera_height := 1.55 ## read by CameraController
var anim_state := "locomotion"
var horizontal_speed := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _air_peak_fall_speed := 0.0
var _land_lock := 0.0
var _land_lock_factor := 1.0
var _land_timer := 0.0
var _visual_offset := Vector3.ZERO
var _visual_root_pos := Vector3.ZERO
var _collision_shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _step_distance := 0.0
var _anim_tree: AnimationTree
var _clip_for_slot: Dictionary = {}
var _clip_speed: Dictionary = {}
var _loco_max_speed := {}
var _blend_points := {}
var _dominant_scale := 1.0
var last_landing_speed := 0.0
var last_step_up := 0.0

signal ammunition_changed(loaded: int, reserve: int)
signal health_changed(new_health: float, max_h: float)
signal stamina_changed(new_stamina: float, max_s: float)
signal oxygen_changed(new_oxygen: float, max_o: float)
signal interactable_detected(prompt: String)
signal interactable_lost()
signal landed(impact_speed: float, hard: bool)

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	gravity = base_gravity
	current_health = max_health
	current_stamina = max_stamina
	current_oxygen = max_oxygen
	if flashlight:
		flashlight.visible = is_flashlight_on
	_setup_body()
	if visual_mesh:
		_ensure_rigged_model()
		facing_yaw = visual_mesh.rotation.y + rotation.y
		_normalise_visual_height()
		_visual_root_pos = visual_mesh.position
		visual_base_y = visual_mesh.position.y
		if not anim_player:
			anim_player = visual_mesh.find_child("AnimationPlayer", true, false)
		_hide_stray_meshes()
	_setup_animation()
	_setup_crouch_pose()
	_setup_interaction_detector()
	_bind_gameplay_inputs()
	_attach_equipment()

# ---------------------------------------------------------------- body setup

## Canonical rigged Mara. Several levels still instance CHR_Mara_Optimized.glb (static, no
## skeleton -> frozen bind/T-pose) or CHR_Mara_Production.glb (idle+walk only); any model
## that is not this one is replaced at startup so every level animates identically.
@export_file("*.glb") var rigged_model_path := "res://assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb"

func _ensure_rigged_model() -> void:
	if rigged_model_path == "" or not ResourceLoader.exists(rigged_model_path):
		return
	for child in visual_mesh.get_children():
		if child.scene_file_path == rigged_model_path:
			return
	var packed := load(rigged_model_path) as PackedScene
	if not packed:
		return
	var old_rotation := Vector3(0, PI * 0.5, 0)
	for child in visual_mesh.get_children():
		if child is Node3D and child.scene_file_path.ends_with(".glb"):
			old_rotation = (child as Node3D).rotation
			visual_mesh.remove_child(child)
			child.queue_free()
	var model := packed.instantiate() as Node3D
	model.rotation = old_rotation
	visual_mesh.add_child(model)
	anim_player = null

func _setup_body() -> void:
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_snap_length = floor_snap
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true
	safe_margin = 0.01
	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			break
	if not _collision_shape:
		_collision_shape = CollisionShape3D.new()
		add_child(_collision_shape)
	# Levels share one CapsuleShape3D sub-resource with NPCs: never mutate it.
	_capsule = CapsuleShape3D.new()
	_capsule.radius = capsule_radius
	_capsule.height = capsule_height
	_collision_shape.shape = _capsule
	_collision_shape.position = Vector3(0, capsule_height * 0.5, 0)

func _normalise_visual_height() -> void:
	var lo := INF
	var hi := -INF
	var inv := global_transform.affine_inverse()
	for mesh in visual_mesh.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (inv * mesh.global_transform) * mesh.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	if hi <= lo:
		return
	var h := hi - lo
	if absf(h - character_height) > 0.05:
		var factor := character_height / h
		visual_mesh.scale *= factor
		visual_mesh.position.y = -(lo - visual_mesh.position.y) * factor
		push_warning("[PLAYER] Mara visual was %.2f m tall; normalised to %.2f m" % [h, character_height])
	elif absf(lo) > 0.03:
		visual_mesh.position.y -= lo

func _set_crouch(value: bool) -> void:
	if value == is_crouching:
		return
	if not value and not _can_stand():
		return
	is_crouching = value
	var h := crouch_capsule_height if value else capsule_height
	_capsule.height = h
	_collision_shape.position.y = h * 0.5

func _can_stand() -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = capsule_radius - 0.02
	probe.height = capsule_height - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (capsule_height * 0.5 + 0.03))
	query.collision_mask = world_collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

# ---------------------------------------------------------------- animation

## The Tripo/Blender export carries an 80-triangle "Icosphere" helper mesh.
func _hide_stray_meshes() -> void:
	for mesh in visual_mesh.find_children("Icosphere*", "MeshInstance3D", true, false):
		mesh.visible = false

# Procedural crouch (no crouch clip exists): drop the hips, bend knees so feet stay
# planted, and pitch the spine forward. Applied after the AnimationTree each frame.
var _crouch_blend := 0.0
var _skeleton: Skeleton3D
var _crouch_bones := {}
var _leg_length := 0.5
@export var crouch_knee_angle_deg: float = 62.0
@export var crouch_spine_angle_deg: float = 18.0

func _setup_crouch_pose() -> void:
	if not visual_mesh:
		return
	_skeleton = visual_mesh.find_child("Skeleton3D", true, false) as Skeleton3D
	if not _skeleton:
		return
	for b in ["Hip", "L_Thigh", "L_Calf", "L_Foot", "R_Thigh", "R_Calf", "R_Foot", "Spine01", "Spine02"]:
		var i := _skeleton.find_bone(b)
		if i < 0:
			_skeleton = null
			return
		_crouch_bones[b] = i
	var thigh := _skeleton.get_bone_global_rest(_crouch_bones["L_Thigh"]).origin
	var calf := _skeleton.get_bone_global_rest(_crouch_bones["L_Calf"]).origin
	var foot := _skeleton.get_bone_global_rest(_crouch_bones["L_Foot"]).origin
	_leg_length = thigh.distance_to(calf) + calf.distance_to(foot)
	if _anim_tree:
		_anim_tree.mixer_applied.connect(_apply_crouch_pose)
		_setup_foot_lock()
		_anim_tree.mixer_applied.connect(_apply_run_posture)
		_anim_tree.mixer_applied.connect(_apply_body_layers)
		_anim_tree.mixer_applied.connect(_apply_foot_lock)
		_anim_tree.mixer_applied.connect(_apply_hand_ik)

# ---------------------------------------------------------------- run posture layer
# The retargeted run lunges forward with the leading arm held straight out. After the
# AnimationTree applies, while running/sprinting: the torso lean is corrected to a target
# angle, the head is levelled, and the arms are replaced by an elbow-bent swing that is
# phase-locked to the legs (arm opposite leg), measured from the animated feet.
@export var run_posture_enabled := true
@export var run_torso_lean_deg := 4.0 ## steady-pace lean (small)
@export var sprint_torso_lean_deg := 6.0
@export var accel_lean_deg_per_ms2 := 0.8 ## extra lean per m/s^2 of forward acceleration
@export var accel_lean_max_deg := 8.0
var _lean_speed_prev := 0.0
var _lean_accel := 0.0
@export var run_elbow_bend_deg := 75.0
@export var run_pelvis_raise := 0.06 ## m; the clip runs in a deep crouch, foot lock re-straightens legs
@export var run_arm_swing_deg := 38.0
@export var sprint_arm_swing_deg := 40.0
@export var max_forearm_angle_deg := 80.0 ## forearm stays below horizontal, with the elbow flexed
@export var run_arm_forward_scale := 0.5 ## forward swing fraction of the backward swing
@export var run_hand_forward_limit := 0.27 ## m ahead of the chest; shared arm rotation preserves elbow bend
var _posture_w := 0.0
var _stance_lift := 0.0
@export var run_stance_extension := 0.93 ## stance leg extension target (fraction of leg length)
@export var run_stance_max_lift := 0.12 ## m
@export var idle_stance_extension := 0.995 ## ~169 degree knees while leaving a small bend
var _idle_w := 0.0

func _apply_run_posture() -> void:
	if not run_posture_enabled or not _skeleton:
		return
	var dt := get_physics_process_delta_time()
	var running := is_on_floor() and current_state in [State.RUN, State.SPRINT] and horizontal_speed > 1.7
	# Ramp in from 1.7 m/s (was 2.0-2.9): while accelerating/braking the raw clip's straight
	# forward-reaching arm used to show through.
	var target_w := clampf((horizontal_speed - 1.7) / 0.5, 0.0, 1.0) if running else 0.0
	_posture_w = move_toward(_posture_w, target_w, dt * 5.0)
	if _posture_w < 0.01:
		return
	var w := _posture_w
	var sprint := current_state == State.SPRINT
	var lateral := Vector3(0, 0, 1) # Mara faces +X in skeleton space; +Z is her lateral axis
	var b := func(n: String) -> int: return _skeleton.find_bone(n)
	var spine: int = b.call("Spine01")
	var head: int = b.call("Head")
	var neck: int = b.call("NeckTwist01")
	if spine < 0 or head < 0:
		return
	# 0. Pelvis: lift out of the clip's deep crouch (feet are re-planted by the foot lock).
	var hip_bone: int = b.call("Hip")
	if hip_bone >= 0 and run_pelvis_raise > 0.0:
		var hp0 := _skeleton.get_bone_global_pose(hip_bone)
		hp0.origin.y += run_pelvis_raise * w / maxf(_skeleton.global_basis.get_scale().x, 0.0001)
		_set_global_pose(hip_bone, hp0)
	# 1. Torso: measure lean of the Spine01 -> Head line, rotate Spine01 to the target lean.
	var s0 := _skeleton.get_bone_global_pose(spine).origin
	var h0 := _skeleton.get_bone_global_pose(head).origin
	var torso := h0 - s0
	var lean := atan2(torso.x, torso.y) # + = top ahead of hips
	# Lean = small base + smoothed forward acceleration (leans in when speeding up, back when braking).
	_lean_accel = lerpf(_lean_accel, (horizontal_speed - _lean_speed_prev) / maxf(dt, 0.001), 1.0 - exp(-6.0 * dt))
	_lean_speed_prev = horizontal_speed
	var accel_lean := clampf(_lean_accel * accel_lean_deg_per_ms2, -accel_lean_max_deg, accel_lean_max_deg)
	var target := deg_to_rad((sprint_torso_lean_deg if sprint else run_torso_lean_deg) + accel_lean)
	_rotate_bone_global(spine, lateral, (lean - target) * w)
	# 2. Head level: align the neck->head direction with vertical (partial).
	if neck >= 0:
		var n0 := _skeleton.get_bone_global_pose(neck).origin
		var hp := _skeleton.get_bone_global_pose(head)
		var up := (hp.origin - n0).normalized()
		hp.basis = _swing_basis(up, Vector3.UP, 0.85 * w) * hp.basis
		_set_global_pose(head, hp)
	# 3. Arms: phase from the animated feet (which foot is ahead), swing opposite.
	# The foot separation is normalised by a decaying running peak so the phase is a smooth
	# sine-like -1..1 (a hard clamp made the arms snap between extremes and both forearms
	# point forward together at the crossover).
	var lf: int = b.call("L_Foot")
	var rf: int = b.call("R_Foot")
	var phase := 0.0
	if lf >= 0 and rf >= 0:
		var diff := _skeleton.get_bone_global_pose(rf).origin.x - _skeleton.get_bone_global_pose(lf).origin.x
		_phase_peak = maxf(maxf(absf(diff), _phase_peak - dt * 0.05), _leg_length * 0.2)
		phase = clampf(diff / _phase_peak, -1.0, 1.0)
	var amp := deg_to_rad(sprint_arm_swing_deg if sprint else run_arm_swing_deg)
	var chest_bone: int = b.call("Spine02")
	var chest_x := _skeleton.get_bone_global_pose(chest_bone if chest_bone >= 0 else spine).origin.x
	var reach_limit := run_hand_forward_limit / maxf(_skeleton.global_basis.get_scale().x, 0.0001)
	for side in ["L_", "R_"]:
		var upper: int = b.call(side + "Upperarm")
		var fore: int = b.call(side + "Forearm")
		var hand: int = b.call(side + "Hand")
		if upper < 0 or fore < 0 or hand < 0:
			continue
		var sign := 1.0 if side == "L_" else -1.0 # left arm forward when right foot is ahead
		var swing := amp * phase * sign
		# Forward half of the swing is shorter than the back half: a full-amplitude forward
		# swing plus the elbow bend read as the leading hand reaching out ahead of the body.
		if swing > 0.0:
			swing *= run_arm_forward_scale
		var u := _skeleton.get_bone_global_pose(upper)
		var out := 1.0 if u.origin.z > 0.0 else -1.0
		# Elbow bend: tighter going forward, more open behind.
		var bend := deg_to_rad(lerpf(run_elbow_bend_deg - 20.0, run_elbow_bend_deg + 15.0, (phase * sign + 1.0) * 0.5))
		# Rotate both segments back when the forearm reaches its limit. Clamping only
		# the forearm collapses the requested elbow bend into a straight leading arm.
		swing -= maxf(swing + bend - deg_to_rad(max_forearm_angle_deg), 0.0)
		var fore_angle := swing + bend
		var down := Basis(lateral, swing) * Vector3(0, -1, 0)
		down = (down + Vector3(0, 0, out * 0.18)).normalized() # slight abduction clears the body
		# Forearm keeps an outward component so the hand never crosses the body midline.
		var fdir := (Basis(lateral, fore_angle) * Vector3(0, -1, 0) + Vector3(0, 0, out * sprint_forearm_splay if sprint else out * 0.12)).normalized()
		# Rebuild the arm from the bind pose (T-pose: arm lateral, palm down) by swinging it
		# down to the side first, then into the target: palms face the thighs and the wrist is
		# neutral, instead of inheriting the clip's palm-up forward reach.
		var r_up := _skeleton.get_bone_global_rest(upper)
		var r_fo := _skeleton.get_bone_global_rest(fore)
		var r_ha := _skeleton.get_bone_global_rest(hand)
		# Bound the whole arm's forward projection using its actual segment lengths
		# and shoulder position. A common sagittal rotation keeps the elbow and roll.
		var arm_tip := down * r_up.origin.distance_to(r_fo.origin) + fdir * r_fo.origin.distance_to(r_ha.origin)
		var allowed_x := chest_x + reach_limit - u.origin.x
		if arm_tip.x > allowed_x:
			var sagittal_length := Vector2(arm_tip.x, arm_tip.y).length()
			if sagittal_length > 0.0001:
				var correction := asin(clampf(allowed_x / sagittal_length, -1.0, 1.0)) - atan2(arm_tip.x, -arm_tip.y)
				var retract := Basis(lateral, correction)
				down = retract * down
				fdir = retract * fdir
		var up_t := _arm_from_rest(r_up.basis, r_fo.origin - r_up.origin, down)
		u.basis = Basis(u.basis.get_rotation_quaternion().slerp(up_t.get_rotation_quaternion(), w))
		_set_global_pose(upper, u)
		var fp := _skeleton.get_bone_global_pose(fore)
		var fo_t := _arm_from_rest(r_fo.basis, r_ha.origin - r_fo.origin, fdir)
		fp.basis = Basis(fp.basis.get_rotation_quaternion().slerp(fo_t.get_rotation_quaternion(), w))
		_set_global_pose(fore, fp)
		# Wrist and forearm twist: bind-pose relation to the forearm (straight wrist).
		for child in [hand, b.call(side + "ForearmTwist01")]:
			if child < 0:
				continue
			var rc := _skeleton.get_bone_global_rest(child)
			var cp := _skeleton.get_bone_global_pose(child)
			var want := fp.basis * (r_fo.basis.inverse() * rc.basis)
			cp.basis = Basis(cp.basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), w))
			_set_global_pose(child, cp)

var _phase_peak := 0.1
@export var sprint_forearm_splay := 0.16

## Bind-pose basis of an arm bone swung (rest dir -> hanging down -> `dir`), two minimal arcs so
## the roll is the natural "arm at the side" roll rather than an arbitrary twist.
func _arm_from_rest(rest_basis: Basis, rest_dir: Vector3, dir: Vector3) -> Basis:
	var hang := Vector3(0, -1, 0)
	var b1 := _swing_basis(rest_dir, hang, 1.0) * rest_basis.orthonormalized()
	return _swing_basis(hang, dir, 1.0) * b1

# ---------------------------------------------------------------- foot locking (two-bone IK)
# Retargeted clips (run especially) let the stance foot creep and dip ~2.5 cm into the floor.
# After the AnimationTree applies, each foot that is low is pinned at its touchdown point
# (world space) and lifted onto the real ground from a raycast; thigh/calf are re-solved
# analytically, keeping the animated knee plane and the animated foot orientation.
@export var foot_lock_enabled := true
@export var foot_plant_height := 0.10 ## ankle height above sole (m) below which a foot can plant
@export var foot_release_height := 0.16
@export var foot_idle_drift := 0.06 ## m, idle re-plant threshold
@export var foot_max_drift := 0.45 ## m the animated foot may wander from its lock before release
@export var foot_align_to_ground := true
@export var foot_align_max_deg := 30.0
var _feet := {}
var _sole_offset := 0.06
var _pelvis_offset := 0.0 ## m, <= 0, smoothed
var last_feet_ground_gap := Vector2.ZERO ## ankle height above ground minus sole, per foot (L, R); for tests

func _setup_foot_lock() -> void:
	if not _skeleton:
		return
	var scale := _skeleton.global_basis.get_scale().x
	var lowest := INF
	for side in ["L_", "R_"]:
		var ids := [_skeleton.find_bone(side + "Thigh"), _skeleton.find_bone(side + "Calf"), _skeleton.find_bone(side + "Foot")]
		if ids.has(-1):
			_feet.clear()
			return
		var thigh := _skeleton.get_bone_global_rest(ids[0]).origin
		var calf := _skeleton.get_bone_global_rest(ids[1]).origin
		var ankle := _skeleton.get_bone_global_rest(ids[2]).origin
		_feet[side] = {"ids": ids, "length": thigh.distance_to(calf) + calf.distance_to(ankle), "locked": false, "lock": Vector3.ZERO, "w": 0.0}
		lowest = minf(lowest, _skeleton.get_bone_global_rest(ids[2]).origin.y * scale)
	_sole_offset = clampf(lowest, 0.03, 0.12) # ankle height above the sole in bind pose

func _apply_foot_lock() -> void:
	if not foot_lock_enabled or not _skeleton or _feet.is_empty():
		return
	# Disabled in the air (JUMP/FALL), in water (SWIM) and on walls (CLIMB/MANTLE): those
	# states are not in this list, so feet unlock and the pelvis offset eases back to zero.
	var grounded := is_on_floor() and current_state in [State.IDLE, State.WALK, State.RUN, State.SPRINT, State.CROUCH]
	var dt := get_physics_process_delta_time()
	var to_skel := _skeleton.global_transform.affine_inverse()
	# Pelvis adaptation: on slopes/uneven ground drop the hips by the lower foot's ground so
	# that foot can reach it (the higher foot is lifted by the IK clamp below).
	var lowest := 0.0
	if grounded:
		for side in _feet:
			var a: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(_feet[side].ids[2]).origin
			lowest = minf(lowest, _ground_below(a) - global_position.y)
	_pelvis_offset = move_toward(_pelvis_offset, clampf(lowest, -0.3, 0.0), dt * 1.5)
	if _pelvis_offset < -0.002:
		var hip_i := _skeleton.find_bone("Hip")
		var hp := _skeleton.get_bone_global_pose(hip_i)
		hp.origin.y += _pelvis_offset / maxf(_skeleton.global_basis.get_scale().x, 0.0001)
		_set_global_pose(hip_i, hp)
	# Stance-leg extension (run/sprint): the retargeted run bends the stance knee to ~120 deg at
	# mid-stance. Raise the hips (same frame, before the leg solve) until every planted leg's
	# hip-to-ankle span is >= run_stance_extension x leg length; the IK then straightens the knee.
	# Idle uses the same lift: the idle clip stands with ~148 deg knees (reads as a flexed crouch).
	_idle_w = move_toward(_idle_w, 1.0 if grounded and current_state == State.IDLE else 0.0, dt * 2.5)
	var ext_w := maxf(_posture_w, _idle_w)
	# Mara's right leg is longer than her left. A small pelvis tilt lets both idle
	# legs extend naturally; lifting a level pelvis alone leaves the longer knee bent.
	if _idle_w > 0.01 and grounded and _turn_w < 0.05 and _feet["L_"].locked and _feet["R_"].locked:
		var raises := Vector2.ZERO
		var lateral_span := 0.0
		var scale_w := _skeleton.global_basis.get_scale().x
		for side in _feet:
			var foot: Dictionary = _feet[side]
			var thigh_s := _skeleton.get_bone_global_pose(foot.ids[0]).origin
			var thigh_w: Vector3 = _skeleton.global_transform * thigh_s
			var horizontal := Vector2(thigh_w.x - foot.lock.x, thigh_w.z - foot.lock.z).length()
			var reach: float = foot.length * scale_w * idle_stance_extension
			var raise: float = foot.lock.y + sqrt(maxf(reach * reach - horizontal * horizontal, 0.0)) - thigh_w.y
			if side == "L_":
				raises.x = raise
				lateral_span -= thigh_s.z * scale_w
			else:
				raises.y = raise
				lateral_span += thigh_s.z * scale_w
		var pelvis := _skeleton.find_bone("Pelvis")
		if pelvis >= 0 and absf(lateral_span) > 0.01:
			var tilt := clampf(-atan((raises.y - raises.x) / lateral_span), -deg_to_rad(8.0), deg_to_rad(8.0))
			_rotate_bone_global(pelvis, Vector3.RIGHT, tilt * _idle_w)
	if ext_w > 0.01 and grounded:
		var need := 0.0
		var cap := run_stance_max_lift
		var scale_w := _skeleton.global_basis.get_scale().x
		for side in _feet:
			var foot: Dictionary = _feet[side]
			if not foot.locked:
				continue
			var reach: float = foot.length * scale_w * (idle_stance_extension if _idle_w > _posture_w else run_stance_extension)
			var full: float = foot.length * scale_w * 0.998
			var thigh_w: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(foot.ids[0]).origin
			var horizontal := Vector2(thigh_w.x - foot.lock.x, thigh_w.z - foot.lock.z).length()
			var below: float = thigh_w.y - foot.lock.y
			if horizontal < reach:
				need = maxf(need, (sqrt(reach * reach - horizontal * horizontal) - below) * foot.w)
			# Never lift so far that a planted leg would have to over-stretch (the IK would
			# then drag the foot off its lock and it would slide).
			cap = minf(cap, sqrt(maxf(full * full - horizontal * horizontal, 0.0)) - below)
		_stance_lift = minf(move_toward(_stance_lift, clampf(need, 0.0, run_stance_max_lift) * ext_w, dt * 6.0), maxf(cap, 0.0))
	else:
		_stance_lift = move_toward(_stance_lift, 0.0, dt * 3.0)
	if _stance_lift > 0.001:
		var hip_s := _skeleton.find_bone("Hip")
		var hs := _skeleton.get_bone_global_pose(hip_s)
		hs.origin.y += _stance_lift / maxf(_skeleton.global_basis.get_scale().x, 0.0001)
		_set_global_pose(hip_s, hs)
	for side in _feet:
		var foot: Dictionary = _feet[side]
		var ids: Array = foot.ids
		var ankle_w: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(ids[2]).origin
		var ground := _ground_below(ankle_w)
		var ground_n := _last_ground_normal
		# Plant/release on the clip's own ankle height (thresholds were tuned for this; measuring
		# sole clearance instead kept moving feet locked until max drift and made them skate).
		var height := ankle_w.y - ground - _stance_lift
		var standing := current_state == State.IDLE and horizontal_speed < 0.1 and _turn_w < 0.05
		if not grounded:
			foot.locked = false
		elif foot.locked:
			var drift := Vector2(ankle_w.x - foot.lock.x, ankle_w.z - foot.lock.z).length()
			# Idle: let a foot re-plant where the idle clip wants it (no flexed, spread stance
			# left over from the last stride).
			var max_drift := foot_idle_drift if current_state == State.IDLE else foot_max_drift + 0.06 * horizontal_speed
			if (not standing and height > foot_release_height) or drift > max_drift:
				foot.locked = false
		# Both feet support an idle pose, including the high ankle in the retargeted clip.
		# Replant immediately after drift so an old stride cannot hold the idle stance apart.
		var just_released: bool = foot.get("was_locked", false) and not foot.locked
		foot.was_locked = foot.locked
		if grounded and not foot.locked and (standing or (height < foot_plant_height and not just_released)):
			foot.locked = true
			foot.lock = Vector3(ankle_w.x, ground + _sole_offset, ankle_w.z)
		foot.w = move_toward(foot.w, 1.0 if foot.locked else 0.0, dt * (40.0 if foot.locked else 6.0))
		var target := ankle_w
		if foot.w > 0.0:
			target = ankle_w.lerp(foot.lock, foot.w)
		if grounded:
			target.y = maxf(target.y, ground + _sole_offset) # never sink into the floor
		if target.distance_to(ankle_w) > 0.002:
			_solve_leg(ids, to_skel * target)
		# Foot pitch/roll follows the ground (slopes, stair nosings, rocks) while planted.
		if grounded and foot.w > 0.01 and foot_align_to_ground and ground_n.y > 0.5:
			var n_s: Vector3 = (_skeleton.global_basis.inverse() * ground_n).normalized()
			var tilt := minf(Vector3.UP.angle_to(n_s), deg_to_rad(foot_align_max_deg))
			if tilt > 0.01:
				var axis := Vector3.UP.cross(n_s).normalized()
				var fp := _skeleton.get_bone_global_pose(ids[2])
				fp.basis = Basis(axis, tilt * foot.w) * fp.basis
				_set_global_pose(ids[2], fp)
		var solved_w: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(ids[2]).origin
		if side == "L_":
			last_feet_ground_gap.x = solved_w.y - ground - _sole_offset
		else:
			last_feet_ground_gap.y = solved_w.y - ground - _sole_offset

var _last_ground_normal := Vector3.UP
func _ground_below(p: Vector3) -> float:
	var hit := _ray(p + Vector3.UP * 0.5, p + Vector3.DOWN * 0.6)
	_last_ground_normal = hit.normal if not hit.is_empty() else Vector3.UP
	return hit.position.y if not hit.is_empty() else global_position.y

## Analytic two-bone IK in skeleton space.
func _solve_leg(ids: Array, target: Vector3, pole_fallback := Vector3(1, 0, 0)) -> void:
	var thigh := _skeleton.get_bone_global_pose(ids[0])
	var calf := _skeleton.get_bone_global_pose(ids[1])
	var foot := _skeleton.get_bone_global_pose(ids[2])
	var a := thigh.origin
	var b := calf.origin
	var c := foot.origin
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var to_t := target - a
	var dist := clampf(to_t.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var dir := to_t.normalized()
	# Keep the animated knee plane: pole = knee offset from the hip-ankle line.
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole.length() < 0.0001:
		pole = pole_fallback # legs: +X (Mara faces +X in skeleton space, knees bend forward)
	pole = pole.normalized()
	var cos_a := clampf((la * la + dist * dist - lb * lb) / (2.0 * la * dist), -1.0, 1.0)
	var knee := a + dir * (la * cos_a) + pole * (la * sqrt(1.0 - cos_a * cos_a))
	var foot_basis := foot.basis
	thigh.basis = _swing_basis(b - a, knee - a, 1.0) * thigh.basis
	_set_global_pose(ids[0], thigh)
	calf = _skeleton.get_bone_global_pose(ids[1])
	var c_now := _skeleton.get_bone_global_pose(ids[2]).origin
	var end := a + dir * dist
	calf.basis = _swing_basis(c_now - calf.origin, end - calf.origin, 1.0) * calf.basis
	_set_global_pose(ids[1], calf)
	var solved := _skeleton.get_bone_global_pose(ids[2])
	solved.basis = foot_basis # keep the animated foot orientation
	_set_global_pose(ids[2], solved)

## Rotation taking direction `from` a fraction `w` of the way toward `to`. Identity when either
## vector is zero/non-finite (degenerate bones) so a bad frame never writes NaN into the skeleton.
func _swing_basis(from: Vector3, to: Vector3, w: float) -> Basis:
	if not from.is_finite() or not to.is_finite() or from.length_squared() < 1e-8 or to.length_squared() < 1e-8:
		return Basis()
	var a := from.normalized()
	var axis := a.cross(to.normalized())
	if axis.length_squared() < 1e-10:
		return Basis()
	var angle := a.signed_angle_to(to.normalized(), axis) * w
	return Basis(axis.normalized(), angle) if is_finite(angle) else Basis()

## All procedural layers write through here: the basis is re-orthonormalised so float error
## (or a skewed blended input) can never accumulate into the bones' persistent local scale.
## Non-orthonormal arm bases previously compounded frame over frame into NaN forearms.
func _set_global_pose(bone: int, pose: Transform3D) -> void:
	if not (pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite()):
		return
	pose.basis = pose.basis.orthonormalized()
	_skeleton.set_bone_global_pose(bone, pose)

func _rotate_bone_global(bone: int, axis: Vector3, angle: float) -> void:
	var pose := _skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(axis, angle) * pose.basis
	_set_global_pose(bone, pose)

func _apply_crouch_pose() -> void:
	if not _skeleton or _crouch_blend < 0.01:
		return
	var k := _crouch_blend
	var knee := deg_to_rad(crouch_knee_angle_deg) * k
	# Model space: Mara faces +X, up +Y, so her right-hand axis is +Z.
	var axis := Vector3(0, 0, 1)
	var hip: int = _crouch_bones["Hip"]
	var hip_pose := _skeleton.get_bone_global_pose(hip)
	hip_pose.origin.y -= _leg_length * (1.0 - cos(knee))
	_set_global_pose(hip, hip_pose)
	for side in ["L_", "R_"]:
		_rotate_bone_global(_crouch_bones[side + "Thigh"], axis, knee)
		_rotate_bone_global(_crouch_bones[side + "Calf"], axis, -2.0 * knee)
		_rotate_bone_global(_crouch_bones[side + "Foot"], axis, knee)
	var spine := -deg_to_rad(crouch_spine_angle_deg) * k
	_rotate_bone_global(_crouch_bones["Spine01"], axis, spine * 0.6)
	_rotate_bone_global(_crouch_bones["Spine02"], axis, spine * 0.4)

# ---------------------------------------------------------------- procedural body layers
# The rig ships only idle/walk/run/jump/fall/climb/dive/swim. These additive layers run after
# the AnimationTree (and the run posture) but before the foot lock, so anything that moves the
# hips is absorbed by the leg IK and the feet stay planted:
#   idle breathing, landing squash, hit reaction, turn-in-place upper-body lead.
@export var body_layers_enabled := true
@export var breath_rate_hz := 0.24
@export var breath_spine_deg := 1.6
@export var breath_shoulder_deg := 2.2
@export var breath_chest_rise := 0.003 ## m; subtle inhale/exhale without moving the planted hips
@export var land_squash_depth := 0.13 ## m hip drop at full squash (hard landing)
@export var hit_reaction_deg := 18.0
@export var turn_lead_deg := 22.0 ## max upper-body lead into a standing turn
var _breath_t := 0.0
var _land_squash := 0.0
var _land_squash_t := 9.0
var _hit_t := 9.0
var _hit_strength := 0.0
var _hit_dir := Vector3.ZERO
var _turn_w := 0.0
var _turn_diff := 0.0
var _prev_yaw := 0.0
var last_land_squash := 0.0 ## current hip drop (m), for tests
var last_hit_weight := 0.0
const HIT_TIME := 0.45
const HIT_ATTACK := 0.06
const LAND_ATTACK := 0.06

## Flinch away from `from_dir` (world direction the blow travels; zero = from the front).
func play_hit_reaction(from_dir := Vector3.ZERO, strength := 1.0) -> void:
	_hit_t = 0.0
	_hit_strength = clampf(strength, 0.0, 1.0)
	_hit_dir = from_dir

func _apply_body_layers() -> void:
	if not body_layers_enabled or not _skeleton or current_state == State.DEAD:
		return
	var dt := get_physics_process_delta_time()
	var to_skel := _skeleton.global_basis.inverse()
	var inv_scale := 1.0 / maxf(_skeleton.global_basis.get_scale().x, 0.0001)
	var lateral := Vector3(0, 0, 1)
	var spine: int = _crouch_bones.get("Spine01", -1)
	var spine2: int = _crouch_bones.get("Spine02", -1)
	var hip: int = _crouch_bones.get("Hip", -1)
	if spine < 0 or hip < 0:
		return
	# Imported clips retain rotation tracks but may omit constant chest translation.
	# Restore its authored local offset before adding the breath so it cannot accumulate.
	var chest := spine2 if spine2 >= 0 else spine
	_skeleton.set_bone_pose_position(chest, _skeleton.get_bone_rest(chest).origin)
	# 1. Breathing: idle only (fades with the idle weight from the foot lock).
	_breath_t = fmod(_breath_t + dt * breath_rate_hz, 1.0)
	var calm := _idle_w if current_state in [State.IDLE, State.CROUCH] else 0.0
	if calm > 0.01:
		var br := sin(_breath_t * TAU)
		_rotate_bone_global(chest, lateral, deg_to_rad(breath_spine_deg) * br * calm)
		var chest_pose := _skeleton.get_bone_global_pose(chest)
		chest_pose.origin.y += breath_chest_rise * br * calm * inv_scale
		_set_global_pose(chest, chest_pose)
		for side in ["L_", "R_"]:
			var clav := _skeleton.find_bone(side + "Clavicle")
			if clav < 0:
				continue
			var out := 1.0 if _skeleton.get_bone_global_pose(clav).origin.z > 0.0 else -1.0
			# Inhale lifts the shoulders slightly (rotation about the forward axis).
			_rotate_bone_global(clav, Vector3(1, 0, 0), -out * deg_to_rad(breath_shoulder_deg) * maxf(br, 0.0) * calm)
	# 2. Landing squash: fast drop, spring back; the knees bend through the foot-lock IK.
	_land_squash_t += dt
	var env := 0.0
	if _land_squash > 0.0:
		env = _land_squash_t / LAND_ATTACK if _land_squash_t < LAND_ATTACK else exp(-(_land_squash_t - LAND_ATTACK) * 7.0)
		if _land_squash_t > 0.9:
			_land_squash = 0.0
	var drop := land_squash_depth * _land_squash * env if is_on_floor() else 0.0
	last_land_squash = drop
	if drop > 0.001:
		var hp := _skeleton.get_bone_global_pose(hip)
		hp.origin.y -= drop * inv_scale
		_set_global_pose(hip, hp)
		_rotate_bone_global(spine, lateral, -deg_to_rad(16.0) * _land_squash * env)
	# 3. Hit reaction: torso and head snap away from the blow, then recover.
	_hit_t += dt
	last_hit_weight = 0.0
	if _hit_t < HIT_TIME:
		# Reach the requested impact strength before recovery starts. Simultaneous
		# attack and decay attenuated every hit to roughly 60% of that strength.
		var hw := smoothstep(0.0, HIT_ATTACK, _hit_t) * (1.0 - smoothstep(HIT_ATTACK, HIT_TIME, _hit_t)) * _hit_strength
		last_hit_weight = hw
		var push := Vector3(-1, 0, 0) # default: a blow from the front pushes her back
		if _hit_dir.length_squared() > 0.01:
			push = to_skel * _hit_dir
			push.y = 0.0
			push = push.normalized() if push.length_squared() > 0.0001 else Vector3(-1, 0, 0)
		var axis := Vector3.UP.cross(push).normalized()
		_rotate_bone_global(spine, axis, deg_to_rad(hit_reaction_deg) * 0.6 * hw)
		if spine2 >= 0:
			_rotate_bone_global(spine2, axis, deg_to_rad(hit_reaction_deg) * 0.4 * hw)
		var head := _skeleton.find_bone("Head")
		if head >= 0:
			_rotate_bone_global(head, axis, deg_to_rad(hit_reaction_deg) * 0.7 * hw)
		var hp2 := _skeleton.get_bone_global_pose(hip)
		hp2.origin += push * 0.04 * hw * inv_scale
		hp2.origin.y -= 0.03 * hw * inv_scale
		_set_global_pose(hip, hp2)
	# 4. Turn in place: the upper body leads into the turn (head, then chest, then hips).
	if _turn_w > 0.01:
		var lead := clampf(_turn_diff, -deg_to_rad(turn_lead_deg), deg_to_rad(turn_lead_deg)) * _turn_w
		_rotate_bone_global(spine, Vector3.UP, lead * 0.45)
		if spine2 >= 0:
			_rotate_bone_global(spine2, Vector3.UP, lead * 0.3)
		var head2 := _skeleton.find_bone("Head")
		if head2 >= 0:
			_rotate_bone_global(head2, Vector3.UP, lead * 0.5)

## Called from _update_animation: detects a standing turn (large heading change at low speed).
func _update_turn_in_place(delta: float) -> void:
	var rate := absf(wrapf(facing_yaw - _prev_yaw, -PI, PI)) / maxf(delta, 0.0001)
	_prev_yaw = facing_yaw
	var standing := is_on_floor() and current_state in [State.IDLE, State.WALK, State.RUN, State.SPRINT] and horizontal_speed < 1.0
	var turning := rate > 1.0 and absf(_turn_diff) > 0.2
	_turn_w = move_toward(_turn_w, 1.0 if standing and turning else 0.0, delta * (8.0 if standing and turning else 3.0))
	if not turning:
		_turn_diff = lerpf(_turn_diff, 0.0, 1.0 - exp(-10.0 * delta))

# ---------------------------------------------------------------- hand IK (after the foot lock)
# Climb: each animated hand is projected onto the wall it is reaching for (palm contact).
# Mantle: both hands plant on the ledge lip while she hauls up.
# Interact: the right hand reaches toward the interactable (pickup / lever / button).
@export var hand_ik_enabled := true
@export var interact_reach_time := 0.7
var _arms := {}
var _arm_length := 0.55
var _climb_hand_w := 0.0
var _mantle_hand_w := 0.0
var _mantle_ledge := Vector3.ZERO
var _mantle_into := Vector3.FORWARD
var _interact_t := 9.0
var _interact_target := Vector3.ZERO
var last_hand_contact_gap := Vector2(-1, -1) ## world distance hand -> contact target (L, R); for tests

func play_interact_reach(target: Vector3) -> void:
	_interact_t = 0.0
	_interact_target = target

func _setup_arms() -> void:
	for side in ["L_", "R_"]:
		var ids := [_skeleton.find_bone(side + "Upperarm"), _skeleton.find_bone(side + "Forearm"), _skeleton.find_bone(side + "Hand")]
		if ids.has(-1):
			_arms.clear()
			return
		_arms[side] = ids
	var r: Array = _arms["R_"]
	var a := _skeleton.get_bone_global_rest(r[0]).origin
	var b := _skeleton.get_bone_global_rest(r[1]).origin
	var c := _skeleton.get_bone_global_rest(r[2]).origin
	_arm_length = (a.distance_to(b) + b.distance_to(c)) * _skeleton.global_basis.get_scale().x

func _apply_hand_ik() -> void:
	if not hand_ik_enabled or not _skeleton or current_state == State.DEAD:
		return
	if _arms.is_empty():
		_setup_arms()
		if _arms.is_empty():
			return
	var dt := get_physics_process_delta_time()
	var xf := _skeleton.global_transform
	var to_skel := xf.affine_inverse()
	last_hand_contact_gap = Vector2(-1, -1)
	var right := _mantle_into.cross(Vector3.UP).normalized()
	_climb_hand_w = move_toward(_climb_hand_w, 1.0 if current_state == State.CLIMB else 0.0, dt * 5.0)
	var mantling := current_state in [State.MANTLE, State.VAULT]
	_mantle_hand_w = move_toward(_mantle_hand_w, 1.0 if mantling else 0.0, dt * (20.0 if mantling else 6.0))
	_interact_t += dt
	var reach_w := 0.0
	if _interact_t < interact_reach_time and current_state in [State.IDLE, State.WALK, State.RUN, State.CROUCH]:
		reach_w = smoothstep(0.0, 1.0, sin(_interact_t / interact_reach_time * PI))
	for side in _arms:
		var ids: Array = _arms[side]
		var hand_w: Vector3 = xf * _skeleton.get_bone_global_pose(ids[2]).origin
		var shoulder_w: Vector3 = xf * _skeleton.get_bone_global_pose(ids[0]).origin
		var target := hand_w
		var w := 0.0
		if _climb_hand_w > 0.01:
			var into := -_climb_normal
			var hit := _ray(hand_w - into * 0.45, hand_w + into * 0.6)
			if not hit.is_empty() and absf(hit.normal.y) < 0.6:
				target = hit.position + hit.normal * 0.05
				w = _climb_hand_w
		elif _mantle_hand_w > 0.01:
			var lat := -0.22 if side == "L_" else 0.22
			target = _mantle_ledge + right * lat + _mantle_into * 0.1 + Vector3.UP * 0.03
			w = _mantle_hand_w
		elif reach_w > 0.0 and side == "R_":
			var to_t := _interact_target - shoulder_w
			target = shoulder_w + to_t.limit_length(_arm_length * 0.92)
			w = reach_w
		if w <= 0.001:
			continue
		# Out-of-reach goals are clamped by the solver (the arm straightens toward them).
		_solve_leg(ids, to_skel * hand_w.lerp(target, w), Vector3(-1, -0.5, 0))
		var gap: float = (xf * _skeleton.get_bone_global_pose(ids[2]).origin).distance_to(target)
		if side == "L_":
			last_hand_contact_gap.x = gap
		else:
			last_hand_contact_gap.y = gap

func _resolve_slot(slot: String) -> String:
	var guard := 0
	var current := slot
	while current != "" and guard < 8:
		for candidate in clip_candidates.get(current, []):
			for full in anim_player.get_animation_list():
				if String(full) == candidate or String(full).get_file() == candidate or String(full).ends_with("/" + candidate):
					return String(full)
		current = clip_fallback.get(current, "idle" if current != "idle" else "")
		guard += 1
	var list := anim_player.get_animation_list()
	return String(list[0]) if list.size() > 0 else ""

## Comparison option: drive run/sprint from the walk clip (time-scaled) instead of `run`.
@export var synthesize_run_from_walk := false

func _setup_animation() -> void:
	if not anim_player or anim_player.get_animation_list().is_empty():
		return
	if synthesize_run_from_walk:
		clip_candidates = clip_candidates.duplicate(true)
		clip_candidates["run"] = []
		clip_candidates["sprint"] = []
	for slot in clip_candidates.keys():
		_clip_for_slot[slot] = _resolve_slot(slot)
	var looping := ["idle", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "climb", "swim_idle"]
	var one_shot := ["jump", "fall", "land", "mantle", "swim"]
	var processed := {}
	for slot in _clip_for_slot:
		var clip: String = _clip_for_slot[slot]
		if clip == "" or processed.has(clip):
			continue
		processed[clip] = true
		_make_in_place(clip)
	for slot in _clip_for_slot:
		var clip: String = _clip_for_slot[slot]
		if clip != "":
			var anim := anim_player.get_animation(clip)
			if slot in looping:
				anim.loop_mode = Animation.LOOP_LINEAR
			elif slot in one_shot and not _clip_used_by(clip, looping):
				anim.loop_mode = Animation.LOOP_NONE
	_build_anim_tree()

## Strips horizontal Hip/Root translation (movement belongs to the CharacterBody) and
## records the clip's natural ground speed so playback can be scaled to stop foot sliding.
func _make_in_place(clip: String) -> void:
	var source := anim_player.get_animation(clip)
	var in_place := source.duplicate(true) as Animation
	var travel := 0.0
	for track in in_place.get_track_count():
		if in_place.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(in_place.track_get_path(track))
		if not (path.ends_with(":Hip") or path.ends_with(":Root") or path.ends_with(":Hips")):
			continue
		var count := in_place.track_get_key_count(track)
		if count < 2:
			continue
		var first: Vector3 = in_place.track_get_key_value(track, 0)
		var last: Vector3 = in_place.track_get_key_value(track, count - 1)
		# Tripo rigs are Z-up in bone space: X/Y carry ground travel, Z carries bob.
		travel = maxf(travel, Vector2(last.x - first.x, last.y - first.y).length())
		for key in count:
			var value: Vector3 = in_place.track_get_key_value(track, key)
			# Pin to the rig origin, not the first key: retargeted clips (run) start 0.57
			# units off-centre, which would shove Mara ~1 m ahead of her capsule.
			value.x = 0.0
			value.y = 0.0
			in_place.track_set_key_value(track, key, value)
	var name_only := clip.get_file() if not clip.contains("/") else clip.split("/")[1]
	var skeleton := visual_mesh.find_child("Skeleton3D", true, false) as Skeleton3D if visual_mesh else null
	var world_scale := 1.0
	if skeleton:
		world_scale = skeleton.global_basis.get_scale().x / maxf(global_basis.get_scale().x, 0.0001)
	if clip_cycle_speed_override.has(name_only):
		_clip_speed[clip] = float(clip_cycle_speed_override[name_only])
	elif travel > 0.01 and source.length > 0.0:
		_clip_speed[clip] = travel * world_scale / source.length
	else:
		_clip_speed[clip] = 0.0
	var library_name := anim_player.find_animation_library(source)
	var library := anim_player.get_animation_library(library_name)
	var copy := library.duplicate() as AnimationLibrary
	copy.remove_animation(name_only)
	copy.add_animation(name_only, in_place)
	anim_player.remove_animation_library(library_name)
	anim_player.add_animation_library(library_name, copy)

func _clip_used_by(clip: String, slots: Array) -> bool:
	for s in slots:
		if _clip_for_slot.get(s, "") == clip:
			return true
	return false

func _slot_speed(slot: String) -> float:
	var clip: String = _clip_for_slot.get(slot, "")
	var s: float = _clip_speed.get(clip, 0.0)
	if s <= 0.0 and slot != "idle" and slot != "crouch_idle" and slot != "swim_idle":
		s = default_cycle_speed.get(slot, 1.4)
	return s

func _make_speed_blend(name: String, slots: Array) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 12.0
	blend.sync = false
	var used := {}
	var points := []
	var top := 0.0
	for slot in slots:
		var clip: String = _clip_for_slot.get(slot, "")
		if clip == "" or used.has(clip):
			continue
		var pos := 0.0 if slot.ends_with("idle") else _slot_speed(slot)
		if used.size() > 0 and pos <= top:
			continue
		used[clip] = pos
		top = pos
		# Each point is anim -> own TimeScale so every clip's stride is matched to ground
		# speed independently before blending (prevents foot sliding in mixed gaits).
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		var point := AnimationNodeBlendTree.new()
		point.add_node("anim", node, Vector2(0, 0))
		point.add_node("scale", AnimationNodeTimeScale.new(), Vector2(200, 0))
		point.connect_node("scale", 0, "anim")
		point.connect_node("output", 0, "scale")
		blend.add_blend_point(point, pos, -1, StringName(slot))
		points.append([slot, pos])
	_loco_max_speed[name] = maxf(top, 0.01)
	_blend_points[name] = points
	tree.add_node("blend", blend, Vector2(0, 0))
	tree.add_node("scale", AnimationNodeTimeScale.new(), Vector2(200, 0))
	tree.connect_node("scale", 0, "blend")
	tree.connect_node("output", 0, "scale")
	return tree

## Crossfade per transition: quick for impacts, long for water and posture changes.
func _xfade(from: String, to: String) -> float:
	if to in ["jump", "land"]:
		return 0.08
	if from == "land":
		return 0.18
	if to == "swim" or from == "swim":
		return 0.4
	if (from == "climb" and to == "mantle") or (from == "mantle" and to == "climb"):
		return 0.15
	if from == "mantle":
		return 0.3
	if to == "fall":
		return 0.25
	if to == "crouch" or from == "crouch":
		return 0.25
	return 0.2

func _build_anim_tree() -> void:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("locomotion", _make_speed_blend("locomotion", ["idle", "walk", "run", "sprint"]), Vector2(0, 0))
	sm.add_node("crouch", _make_speed_blend("crouch", ["crouch_idle", "crouch_walk"]), Vector2(0, 150))
	sm.add_node("swim", _make_speed_blend("swim", ["swim_idle", "swim"]), Vector2(0, 300))
	sm.add_node("climb", _make_speed_blend("climb", ["climb"]), Vector2(300, 300))
	for slot in ["jump", "fall", "land", "mantle"]:
		var node := AnimationNodeAnimation.new()
		node.animation = _clip_for_slot.get(slot, _clip_for_slot.get("idle", ""))
		sm.add_node(slot, node, Vector2(300, 0))
	var names := ["locomotion", "crouch", "swim", "climb", "jump", "fall", "land", "mantle"]
	for a in names:
		for b in names:
			if a == b:
				continue
			var t := AnimationNodeStateMachineTransition.new()
			t.xfade_time = _xfade(a, b)
			sm.add_transition(a, b, t)
	var entry := AnimationNodeStateMachineTransition.new()
	entry.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO # leave Start at once
	sm.add_transition("Start", "locomotion", entry)
	_anim_tree = AnimationTree.new()
	_anim_tree.name = "MaraAnimationTree"
	add_child(_anim_tree)
	_anim_tree.tree_root = sm
	_anim_tree.anim_player = _anim_tree.get_path_to(anim_player)
	_anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_anim_tree.active = true

## Returns measured cycle speed per clip (m/s at 1x) for diagnostics.
func get_clip_speeds() -> Dictionary:
	return _clip_speed.duplicate()

func get_clip_mapping() -> Dictionary:
	return _clip_for_slot.duplicate()

func _update_animation(delta: float) -> void:
	if not _anim_tree:
		return
	var target := "locomotion"
	match current_state:
		State.SWIM: target = "swim"
		State.CLIMB: target = "climb"
		State.MANTLE, State.VAULT: target = "mantle"
		State.JUMP: target = "jump"
		State.FALL: target = "fall"
		State.CROUCH: target = "crouch"
	if target == "locomotion" and _land_timer > 0.0:
		target = "land"
	var playback: AnimationNodeStateMachinePlayback = _anim_tree.get("parameters/playback")
	# Never sit in the state machine's Start node (no clip = frozen/bind pose).
	if playback and playback.get_current_node() in [&"", &"Start"]:
		playback.start(target)
		anim_state = target
	elif playback and anim_state != target:
		playback.travel(target)
		anim_state = target
	_update_turn_in_place(delta)
	var speed := horizontal_speed
	if current_state == State.CLIMB:
		speed = velocity.length()
	elif target == "locomotion" and _turn_w > 0.01:
		# Standing turn: drive the walk cycle slowly so the feet step around (the foot lock
		# re-plants each foot) instead of the whole body spinning on fixed feet.
		speed = maxf(speed, turn_step_speed * _turn_w)
	for blend_name in ["locomotion", "crouch", "swim", "climb"]:
		var top: float = _loco_max_speed.get(blend_name, 1.0)
		# Smoothed so speed jitter (slopes, stops) can't flick between clips.
		var raw_pos := _gait_position(blend_name, speed)
		var gait_pos: float = lerpf(_gait_smooth.get(blend_name, raw_pos), raw_pos, 1.0 - exp(-gait_blend_rate * delta))
		_gait_smooth[blend_name] = gait_pos
		_anim_tree.set("parameters/%s/blend/blend_position" % blend_name, gait_pos)
		_anim_tree.set("parameters/%s/scale/scale" % blend_name, 1.0)
		var best := INF
		for point in _blend_points.get(blend_name, []):
			var natural: float = point[1]
			var scale := 1.0
			if blend_name == "swim":
				# No ground contact: swim tempo follows effort (treading 0.9x .. sprint 2.0x; clip is 2 strokes in 5.7 s)
				# instead of the clip's 0.37 m/s root travel (which forced a 3x cap).
				scale = lerpf(0.9, 2.0, clampf(speed / swim_sprint_speed, 0.0, 1.0)) + (0.15 if absf(velocity.y) > 0.6 else 0.0)
			elif natural > 0.05:
				# Stride matching: playback rate = ground speed / clip's natural speed.
				# Floor 0.2 (was 0.5): while stopping, the walk must slow with her or the feet skate.
				scale = clampf(speed / natural, 0.2, 3.0)
				if blend_name == "locomotion" and point[0] == "run" and current_state == State.SPRINT and _clip_for_slot.get("sprint") == _clip_for_slot.get("run"):
					scale = maxf(scale, sprint_from_run_scale)
			_anim_tree.set("parameters/%s/blend/%s/scale/scale" % [blend_name, point[0]], scale)
			if blend_name == anim_state and absf(natural - gait_pos) < best:
				best = absf(natural - gait_pos)
				_dominant_scale = scale

## Blend position that keeps ONE stride-matched clip dominant: clips with different cycle
## lengths are not phase aligned, so mixing them (e.g. 16% run into a walk) drags the planted
## foot. Pure clips are used between switch points; a 0.6 m/s crossfade band joins them.
@export var turn_step_speed := 0.95 ## pseudo ground speed (m/s) driving the walk cycle in a standing turn
@export var gait_crossfade_band: float = 0.6
@export var gait_blend_rate := 12.0 ## 1/s smoothing of the gait blend position
var _gait_smooth := {}
func _gait_position(blend_name: String, speed: float) -> float:
	var pts: Array = _blend_points.get(blend_name, [])
	if pts.size() < 2:
		return 0.0
	var first_moving: float = pts[1][1]
	if speed <= first_moving:
		return speed # idle -> first gait
	for i in range(1, pts.size() - 1):
		var a: float = pts[i][1]
		var b: float = pts[i + 1][1]
		var switch := (a + b) * 0.5
		var lo := switch - gait_crossfade_band * 0.5
		var hi := switch + gait_crossfade_band * 0.5
		if speed <= lo:
			return a
		if speed < hi:
			return lerpf(a, b, (speed - lo) / (hi - lo))
	return pts[pts.size() - 1][1]

func get_animation_playback_scale() -> float:
	if not _anim_tree:
		return 1.0
	return _dominant_scale

# ---------------------------------------------------------------- equipment / input (unchanged)

## Hidden hand props (sidearm, climbing pick). Loading the two GLBs synchronously cost ~400 ms
## of a cold Player start-up, so they are requested on a loader thread and attached once ready
## (the visuals are only shown while aiming / climbing, and every use is null-guarded).
const EQUIPMENT := [["R_Hand", "res://assets/props/equipment/expedition_sidearm.glb", 0.23], ["L_Hand", "res://assets/props/equipment/climbing_pick.glb", 0.28]]
var _equipment_pending := []

func _attach_equipment() -> void:
	if not visual_mesh:
		return
	for equipment in EQUIPMENT:
		if ResourceLoader.exists(equipment[1]):
			if ResourceLoader.load_threaded_request(equipment[1], "PackedScene") == OK:
				_equipment_pending.append(equipment)

func _poll_equipment() -> void:
	for equipment in _equipment_pending.duplicate():
		var status := ResourceLoader.load_threaded_get_status(equipment[1])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_equipment_pending.erase(equipment)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_mount_equipment(equipment, ResourceLoader.load_threaded_get(equipment[1]) as PackedScene)

func _mount_equipment(equipment: Array, packed: PackedScene) -> void:
	var skeleton := visual_mesh.find_child("Skeleton3D", true, false) as Skeleton3D if visual_mesh else null
	if not skeleton or not packed or skeleton.find_bone(equipment[0]) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = equipment[0]
	skeleton.add_child(attachment)
	var model: Node3D = packed.instantiate()
	attachment.add_child(model)
	var bounds := AABB()
	var found := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if found:
		var scale_factor: float = equipment[2] / maxf(bounds.size[bounds.size.max_axis_index()], 0.001)
		model.scale = Vector3.ONE * scale_factor
		model.position = -bounds.get_center() * scale_factor
	if equipment[0] == "R_Hand":
		sidearm_visual = model
	else:
		pick_visual = model
	model.hide()

func _bind_gameplay_inputs() -> void:
	var keys := {"reload": KEY_R, "melee": KEY_Q, "walk": KEY_ALT, "dive": KEY_C}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = keys[action]
			InputMap.action_add_event(action, key)
	var buttons := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
	for action in buttons:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var button := InputEventMouseButton.new()
			button.button_index = buttons[action]
			InputMap.action_add_event(action, button)

func _setup_interaction_detector() -> void:
	if not interaction_detector:
		interaction_detector = Area3D.new()
		interaction_detector.name = "InteractionDetector"
		var shape = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 2.0
		shape.shape = sphere
		interaction_detector.add_child(shape)
		interaction_detector.collision_layer = 0
		interaction_detector.collision_mask = 4
		add_child(interaction_detector)
	interaction_detector.area_entered.connect(_on_interaction_area_entered)
	interaction_detector.area_exited.connect(_on_interaction_area_exited)

func _on_interaction_area_entered(area: Area3D) -> void:
	if area is Interactable3D and area.is_enabled:
		nearby_interactable = area
		interactable_detected.emit(area.prompt_message)

func _on_interaction_area_exited(area: Area3D) -> void:
	if nearby_interactable == area:
		nearby_interactable = null
		interactable_lost.emit()

func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.DEAD or get_tree().paused:
		return
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact") and nearby_interactable:
		_refresh_interactable()
		if not nearby_interactable:
			return
		play_interact_reach(nearby_interactable.global_position)
		nearby_interactable.trigger_interaction(self)
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("melee"):
		melee_attack()

func toggle_flashlight() -> void:
	is_flashlight_on = not is_flashlight_on
	if flashlight:
		flashlight.visible = is_flashlight_on

# ---------------------------------------------------------------- main loop

func get_facing_forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))

func _camera_relative(input_dir: Vector2) -> Vector3:
	var basis := camera_pivot.global_transform.basis if camera_pivot else Basis.IDENTITY
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var dir := right * input_dir.x - forward * input_dir.y
	return dir.limit_length(1.0)

func _physics_process(delta: float) -> void:
	_regen(delta)
	if current_state == State.DEAD:
		return
	_refresh_interactable()
	_update_combat(delta)
	if global_position.y < -80.0:
		take_damage(max_health)
		return
	_update_water()
	if current_state != State.SWIM and current_oxygen < max_oxygen:
		current_oxygen = minf(max_oxygen, current_oxygen + delta * 5.0)
		oxygen_changed.emit(current_oxygen, max_oxygen)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := _camera_relative(input_dir)

	match current_state:
		State.MANTLE, State.VAULT:
			_process_mantle(delta)
		State.CLIMB:
			_process_climb(delta, input_dir)
		State.SWIM:
			_process_swim(delta, move_dir)
		_:
			_process_ground_air(delta, move_dir)

	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	_update_visual(delta)
	_update_animation(delta)

func _update_combat(delta: float) -> void:
	weapon_cooldown = maxf(0.0, weapon_cooldown - delta)
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	is_aiming = Input.is_action_pressed("aim")
	if not _equipment_pending.is_empty():
		_poll_equipment()
	if sidearm_visual:
		sidearm_visual.visible = is_aiming or weapon_cooldown > 0.0 or reload_timer > 0.0
	if pick_visual:
		pick_visual.visible = current_state in [State.MANTLE, State.LEDGE_HANG, State.CLIMB]
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			var transfer := mini(magazine_capacity - ammunition, reserve_ammunition)
			ammunition += transfer
			reserve_ammunition -= transfer
			ammunition_changed.emit(ammunition, reserve_ammunition)
	if Input.is_action_pressed("fire"):
		fire_weapon()

func _rotate_toward(dir: Vector3, rate: float, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(-dir.x, -dir.z)
	var diff := wrapf(target - facing_yaw, -PI, PI)
	_turn_diff = diff
	# Capped turn rate for big turns, exponential ease for the last few degrees (no hard stop).
	var eased := diff * (1.0 - exp(-rate * 1.5 * delta))
	facing_yaw += clampf(eased, -rate * delta, rate * delta)

func _process_ground_air(delta: float, move_dir: Vector3) -> void:
	var on_floor := is_on_floor()
	_coyote = coyote_time if on_floor else maxf(0.0, _coyote - delta)
	_land_lock = maxf(0.0, _land_lock - delta)
	_land_timer = maxf(0.0, _land_timer - delta)

	# Crouch with ceiling check
	var want_crouch := Input.is_action_pressed("crouch") and on_floor
	_set_crouch(want_crouch or (is_crouching and not _can_stand()))

	var has_input := move_dir.length() > 0.1
	var sprinting := Input.is_action_pressed("sprint") and current_stamina > 5.0 and has_input and not is_crouching
	var walking := Input.is_action_pressed("walk") or is_aiming
	var target_speed := run_speed
	if is_crouching:
		target_speed = crouch_speed
	elif sprinting:
		target_speed = sprint_speed
	elif walking:
		target_speed = walk_speed
	target_speed *= move_dir.length()
	if water_depth > WADE_DEPTH:
		target_speed *= clampf(1.0 - (water_depth - WADE_DEPTH) * 0.6, 0.45, 1.0)
	if _land_lock > 0.0:
		target_speed *= _land_lock_factor

	# Stamina
	if sprinting:
		current_stamina = maxf(0.0, current_stamina - 15.0 * delta)
	else:
		current_stamina = minf(max_stamina, current_stamina + (10.0 if has_input else 20.0) * delta)
	stamina_changed.emit(current_stamina, max_stamina)

	# Facing: turn toward input; speed is gated by alignment so Mara never runs backwards.
	var turn_rate := sprint_rotation_speed if sprinting else rotation_speed
	if not on_floor:
		turn_rate *= 0.5
	if has_input:
		_rotate_toward(move_dir, turn_rate, delta)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var desired := Vector3.ZERO
	var brake := 1.0
	if has_input:
		var alignment := get_facing_forward().dot(move_dir.normalized())
		var gate := smoothstep(-0.1, 0.85, alignment) if on_floor else 1.0
		desired = move_dir.normalized() * target_speed * gate
		# Sharp reversal: plant and brake hard while the body turns (no backwards running).
		if horizontal.length() > 0.5 and horizontal.normalized().dot(move_dir.normalized()) < 0.0:
			brake = 1.6
	var rate := ground_acceleration if desired.length() >= horizontal.length() else ground_deceleration * brake
	if not on_floor:
		rate = air_acceleration
	horizontal = horizontal.move_toward(desired, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Gravity
	if not on_floor:
		var g := base_gravity
		if velocity.y < 0.0:
			g *= fall_gravity_multiplier
		elif not Input.is_action_pressed("jump"):
			g *= jump_cut_gravity_multiplier
		velocity.y = maxf(velocity.y - g * delta, -terminal_velocity)
		_air_peak_fall_speed = maxf(_air_peak_fall_speed, -velocity.y)

	# Jump / mantle / climb
	if _jump_buffer > 0.0:
		var probe_dir := move_dir if has_input else get_facing_forward()
		if _try_climb(probe_dir, true):
			_jump_buffer = 0.0
			return
		if _check_and_trigger_mantle(probe_dir):
			_jump_buffer = 0.0
			return
		if _coyote > 0.0 and not is_crouching:
			velocity.y = sqrt(2.0 * base_gravity * jump_apex_height)
			_coyote = 0.0
			_jump_buffer = 0.0
			current_state = State.JUMP
			on_floor = false
	elif not on_floor and has_input and velocity.y < 1.0:
		if _try_climb(move_dir, false):
			return

	# Step-up for small ledges (blocked above max_step_height)
	if on_floor and horizontal.length() > 0.05:
		_try_step_up(delta)

	var pre_fall := _air_peak_fall_speed
	move_and_slide()
	if is_on_ceiling() and velocity.y > 0.0:
		velocity.y = 0.0

	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		_on_landed(pre_fall)
	_was_on_floor = now_floor
	if now_floor:
		_air_peak_fall_speed = 0.0
		if is_crouching:
			current_state = State.CROUCH
		elif horizontal_speed < 0.15 and not has_input:
			current_state = State.IDLE
		elif sprinting:
			current_state = State.SPRINT
		elif target_speed <= walk_speed + 0.01:
			current_state = State.WALK
		else:
			current_state = State.RUN
		# Footsteps every stride (0.67 m measured from the walk clip)
		_step_distance += horizontal_speed * delta
		if _step_distance >= 0.67:
			_step_distance = 0.0
			var audio = get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_sfx"):
				audio.play_sfx("footstep_stone", global_position)
	elif velocity.y <= 0.0 and _air_grace < fall_grace_time and current_state in [State.IDLE, State.WALK, State.RUN, State.SPRINT, State.CROUCH] and _ground_within(max_step_height + 0.1):
		# Grace: stepping off a curb or cresting a slope briefly leaves the floor; keep the
		# ground state (and clip) unless the drop is real, so FALL never flickers on steps.
		_air_grace += delta
	else:
		current_state = State.JUMP if velocity.y > 0.0 else State.FALL
	if now_floor:
		_air_grace = 0.0

@export var fall_grace_time := 0.15 ## s off the floor before the fall clip, while ground is near
var _air_grace := 0.0

func _ground_within(dist: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position - Vector3.UP * dist, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _on_landed(impact: float) -> void:
	last_landing_speed = impact
	var hard := impact >= hard_landing_speed
	if hard:
		_land_lock = 0.35
		_land_lock_factor = 0.25
		_land_timer = 0.3
	elif impact > 4.0:
		_land_lock = 0.08
		_land_lock_factor = 0.8
		_land_timer = 0.12
	# Landing squash (hips drop, knees absorb via the leg IK; feet stay on the ground).
	_land_squash = maxf(_land_squash, clampf((impact - 2.5) / 9.0, 0.0, 1.0))
	_land_squash_t = 0.0
	if impact >= damage_landing_speed:
		take_damage((impact - damage_landing_speed) * landing_damage_per_mps)
	landed.emit(impact, hard)

func _try_step_up(delta: float) -> bool:
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	var probe := motion.normalized() * maxf(motion.length(), 0.1)
	var start := global_transform
	var hit := KinematicCollision3D.new()
	if not test_move(start, probe, hit, 0.001):
		return false
	if hit.get_normal().y > cos(floor_max_angle):
		return false
	var raised := start
	var up_hit := KinematicCollision3D.new()
	var up := Vector3.UP * max_step_height
	if test_move(raised, up, up_hit, 0.001):
		up = up_hit.get_travel()
	raised.origin += up
	if test_move(raised, probe, null, 0.001):
		return false # still blocked at step height: obstacle too tall
	raised.origin += probe
	var down_hit := KinematicCollision3D.new()
	if not test_move(raised, -up - Vector3.UP * 0.05, down_hit, 0.001):
		return false
	raised.origin += down_hit.get_travel()
	if down_hit.get_normal().y < cos(floor_max_angle):
		return false
	var rise := raised.origin.y - global_position.y
	if rise < 0.03 or rise > max_step_height + 0.01:
		return false
	_visual_offset -= raised.origin - global_position
	global_position = raised.origin
	last_step_up = rise
	return true

# ---------------------------------------------------------------- mantle

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, world_collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)

func _check_and_trigger_mantle(forward_dir: Vector3, from_water := false) -> bool:
	var forward := forward_dir
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = get_facing_forward()
	forward = forward.normalized()
	var feet := global_position
	var wall := {}
	for h: float in [0.35, 0.7, 1.05, 1.4]:
		var origin: Vector3 = feet + Vector3.UP * h
		var hit := _ray(origin, origin + forward * (capsule_radius + mantle_reach))
		if not hit.is_empty() and absf(hit.normal.y) < 0.6:
			wall = hit
			break
	if wall.is_empty():
		return false
	var max_h := mantle_max_height + (0.6 if from_water else 0.0)
	var min_h := 0.15 if from_water else mantle_min_height
	var wall_normal: Vector3 = wall.normal
	wall_normal.y = 0.0
	var into := -wall_normal.normalized() if wall_normal.length() > 0.1 else forward
	var top_origin: Vector3 = wall.position + into * 0.3
	top_origin.y = feet.y + max_h + 0.1
	var top := _ray(top_origin, Vector3(top_origin.x, feet.y + min_h - 0.05, top_origin.z))
	if top.is_empty() or top.normal.y < 0.75:
		return false
	# A hit at the very start means the probe began inside geometry (wall taller than reach).
	if top.position.y > feet.y + max_h:
		return false
	var height: float = top.position.y - feet.y
	if height < min_h or height > max_h:
		return false
	# Validate the full path with the real capsule: rise, then move over the edge.
	var t := global_transform
	var rise := Vector3.UP * (height + 0.04)
	if test_move(t, rise, null, 0.001):
		return false
	t.origin += rise
	var over: Vector3 = Vector3(top.position.x, 0, top.position.z) - Vector3(feet.x, 0, feet.z)
	over = over + into * (capsule_radius * 0.6)
	if test_move(t, over, null, 0.001):
		return false
	var end := t.origin + over
	_mantle_points = [global_position, global_position + rise, end]
	_mantle_durations = [0.16 + height * 0.18, 0.18]
	_mantle_segment = 0
	mantle_timer = 0.0
	mantle_target_pos = end
	_mantle_ledge = Vector3(wall.position.x, top.position.y, wall.position.z)
	_mantle_into = into
	velocity = Vector3.ZERO
	_rotate_toward(into, 1000.0, 1.0)
	_set_crouch(false)
	current_state = State.MANTLE
	return true

func _process_mantle(delta: float) -> void:
	if _mantle_points.size() < 2:
		current_state = State.IDLE
		return
	mantle_timer += delta
	var duration := _mantle_durations[_mantle_segment]
	var a := _mantle_points[_mantle_segment]
	var b := _mantle_points[_mantle_segment + 1]
	var t := clampf(mantle_timer / duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	global_position = a.lerp(b, eased)
	velocity = Vector3.ZERO
	if t >= 1.0:
		_mantle_segment += 1
		mantle_timer = 0.0
		if _mantle_segment >= _mantle_points.size() - 1:
			global_position = mantle_target_pos
			current_state = State.IDLE
			_was_on_floor = true
			apply_floor_snap()

# ---------------------------------------------------------------- climbing

func _is_climbable(node: Object) -> bool:
	var n := node as Node
	var depth := 0
	while n and depth < 3:
		if n.is_in_group("climbable") or (n.has_meta("climbable") and bool(n.get_meta("climbable"))):
			return true
		n = n.get_parent()
		depth += 1
	return false

func _try_climb(dir: Vector3, from_jump: bool) -> bool:
	var forward := Vector3(dir.x, 0, dir.z)
	if forward.length() < 0.1:
		return false
	forward = forward.normalized()
	var origin := global_position + Vector3.UP * 1.1
	var hit := _ray(origin, origin + forward * (capsule_radius + (0.5 if from_jump else 0.25)))
	if hit.is_empty() or absf(hit.normal.y) > 0.5 or not _is_climbable(hit.collider):
		return false
	if from_jump and _check_and_trigger_mantle(forward):
		return true # low enough to just mantle
	_climb_normal = Vector3(hit.normal.x, 0, hit.normal.z).normalized()
	_rotate_toward(-_climb_normal, 1000.0, 1.0)
	velocity = Vector3.ZERO
	_set_crouch(false)
	current_state = State.CLIMB
	return true

func _process_climb(delta: float, input_dir: Vector2) -> void:
	var into := -_climb_normal
	var chest := _ray(global_position + Vector3.UP * 1.2, global_position + Vector3.UP * 1.2 + into * (capsule_radius + 0.7))
	var hips := _ray(global_position + Vector3.UP * 0.5, global_position + Vector3.UP * 0.5 + into * (capsule_radius + 0.7))
	if chest.is_empty() or not _is_climbable(chest.collider):
		if not hips.is_empty() and _check_and_trigger_mantle(into):
			return
		if input_dir.y < 0.0 and not hips.is_empty():
			# Reached the top lip: haul up onto it.
			if _check_and_trigger_mantle(into, true):
				return
		current_state = State.FALL
		return
	_climb_normal = Vector3(chest.normal.x, 0, chest.normal.z).normalized()
	var right := Vector3.UP.cross(_climb_normal).normalized()
	var wall_dist: float = (chest.position - (global_position + Vector3.UP * 1.2)).dot(into)
	var stick := into * clampf((wall_dist - capsule_radius - 0.04) * 8.0, -1.0, 2.0)
	velocity = Vector3.UP * (-input_dir.y * climb_speed) + right * (input_dir.x * climb_speed) + stick
	current_stamina = maxf(0.0, current_stamina - 4.0 * delta)
	stamina_changed.emit(current_stamina, max_stamina)
	if Input.is_action_just_pressed("jump"):
		velocity = _climb_normal * 3.0 + Vector3.UP * 3.5
		_rotate_toward(_climb_normal, 1000.0, 1.0)
		current_state = State.JUMP
		move_and_slide()
		return
	if Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("dive") or current_stamina <= 0.0:
		current_state = State.FALL
		return
	move_and_slide()
	if is_on_floor() and input_dir.y > 0.0:
		current_state = State.IDLE

# ---------------------------------------------------------------- swimming

## Water contract: Area3D nodes in group "water_volume" exposing
## get_surface_height(world_pos: Vector3) -> float. Legacy WaterVolume.gd pushes
## water_surface + enter_water()/exit_water() instead; both are supported.
func _update_water() -> void:
	var found := false
	var surface := -INF
	for volume in get_tree().get_nodes_in_group("water_volume"):
		if not (volume is Area3D) or not volume.has_method("get_surface_height"):
			continue
		if not (volume as Area3D).overlaps_body(self):
			continue
		var h: float = volume.get_surface_height(global_position)
		if h > surface:
			surface = h
			found = true
			_water_body = volume
	if not found and _legacy_water:
		surface = water_surface
		found = true
	in_water = found
	if found:
		water_surface = surface
		water_depth = surface - global_position.y
	else:
		water_depth = 0.0
	underwater = in_water and global_position.y + 1.55 < water_surface
	if current_state == State.SWIM:
		if not in_water or (water_depth < SWIM_EXIT_DEPTH and is_on_floor()):
			_leave_swim()
	elif in_water and water_depth > SWIM_ENTER_DEPTH and current_state not in [State.MANTLE, State.CLIMB]:
		_enter_swim()

func _enter_swim() -> void:
	_set_crouch(false)
	current_state = State.SWIM
	velocity.y *= 0.35
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("splash", global_position)

func _leave_swim() -> void:
	current_state = State.IDLE
	_was_on_floor = is_on_floor()

func _process_swim(delta: float, move_dir: Vector3) -> void:
	var has_input := move_dir.length() > 0.1
	var fast := Input.is_action_pressed("sprint") and current_stamina > 5.0
	var target_speed := (swim_sprint_speed if fast else swim_speed) * move_dir.length()
	if has_input:
		_rotate_toward(move_dir, rotation_speed * 0.6, delta)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var desired := move_dir.normalized() * target_speed if has_input else Vector3.ZERO
	if is_instance_valid(_water_body) and _water_body.has_method("get_flow_velocity"):
		var flow: Vector3 = _water_body.get_flow_velocity(global_position)
		desired += Vector3(flow.x, 0, flow.z)
	horizontal = horizontal.move_toward(desired, water_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var rest_y := water_surface - SWIM_FLOAT_DEPTH
	var diving := Input.is_action_pressed("dive") or Input.is_action_pressed("crouch")
	var rising := Input.is_action_pressed("jump") and global_position.y < rest_y - 0.15
	var target_vy: float
	if diving:
		target_vy = -swim_vertical_speed
	elif rising:
		target_vy = swim_vertical_speed
	else:
		# Buoyancy: spring toward floating depth, gentle ascent when deep.
		target_vy = clampf((rest_y - global_position.y) * 2.5, -1.5, 0.8)
	velocity.y = move_toward(velocity.y, target_vy + water_vertical_velocity, 5.0 * delta)
	velocity.y *= exp(-1.2 * delta) # drag

	# Climb out: jump at the surface toward a ledge.
	if _jump_buffer > 0.0 and global_position.y > rest_y - 0.4:
		if _check_and_trigger_mantle(move_dir if has_input else get_facing_forward(), true):
			_jump_buffer = 0.0
			return

	if underwater:
		current_oxygen = maxf(0.0, current_oxygen - delta)
	else:
		current_oxygen = minf(max_oxygen, current_oxygen + delta * 5.0)
	oxygen_changed.emit(current_oxygen, max_oxygen)
	if current_oxygen <= 0.0:
		take_damage(delta * 12.0)
	move_and_slide()

## Legacy hooks (systems/WaterVolume.gd).
func enter_water() -> void:
	_legacy_water = true
	if current_state != State.SWIM and global_position.y < water_surface - SWIM_ENTER_DEPTH + 0.3:
		_enter_swim()

func exit_water() -> void:
	_legacy_water = false
	water_vertical_velocity = 0.0
	if current_state == State.SWIM:
		_leave_swim()

# ---------------------------------------------------------------- visuals

func _update_visual(delta: float) -> void:
	if not visual_mesh:
		return
	visual_mesh.rotation.y = facing_yaw - rotation.y
	# Smooth out step-up / mantle snaps so the camera and body do not pop.
	_visual_offset = _visual_offset.lerp(Vector3.ZERO, 1.0 - exp(-14.0 * delta))
	visual_mesh.position = _visual_root_pos + _visual_offset
	# Subtle athletic lean: forward with speed, banked into turns.
	var lean := 0.0
	if current_state in [State.RUN, State.SPRINT]:
		lean = 0.05 if current_state == State.RUN else 0.09
	elif current_state == State.SWIM and horizontal_speed > 0.3:
		lean = 0.2
	visual_mesh.rotation.x = lerpf(visual_mesh.rotation.x, -lean, 1.0 - exp(-8.0 * delta))
	visual_mesh.rotation.z = lerpf(visual_mesh.rotation.z, 0.0, 1.0 - exp(-8.0 * delta))
	camera_height = lerpf(camera_height, 1.05 if is_crouching else 1.55, 1.0 - exp(-8.0 * delta))
	_crouch_blend = move_toward(_crouch_blend, 1.0 if is_crouching else 0.0, delta * 6.0)

## Public rig accessors (character customisation depends on these).
func get_skeleton() -> Skeleton3D:
	if not _skeleton and visual_mesh:
		_skeleton = visual_mesh.find_child("Skeleton3D", true, false) as Skeleton3D
	return _skeleton

## Node that carries Mara's model (yawed to facing, offset for step smoothing).
func get_visual_root() -> Node3D:
	return visual_mesh

## Snapshot for tests / debug overlays.
func get_movement_debug() -> Dictionary:
	return {
		"state": State.keys()[current_state], "anim_state": anim_state, "speed": horizontal_speed,
		"vy": velocity.y, "on_floor": is_on_floor(), "crouching": is_crouching,
		"capsule_height": _capsule.height if _capsule else 0.0, "water_depth": water_depth,
		"facing": get_facing_forward(), "playback_scale": get_animation_playback_scale(),
	}

# ---------------------------------------------------------------- vitals / combat (unchanged)

func _refresh_interactable() -> void:
	if not interaction_detector:
		return
	var nearest: Interactable3D = null
	var nearest_distance := INF
	for area in interaction_detector.get_overlapping_areas():
		if area is Interactable3D and area.is_enabled:
			var distance: float = (global_position + Vector3.UP).distance_squared_to(area.global_position)
			if distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	if nearest != nearby_interactable:
		nearby_interactable = nearest
		if nearest:
			interactable_detected.emit(nearest.prompt_message)
		else:
			interactable_lost.emit()

func _sfx(sound: String, at: Vector3) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sound, at)

## Out-of-combat recovery: health persists across the connected world, so it regenerates
## after a quiet spell instead of being refilled at every chapter start.
const REGEN_DELAY := 6.0
const REGEN_RATE := 8.0
var _since_hit := 999.0

func _regen(delta: float) -> void:
	_since_hit += delta
	if current_state == State.DEAD or current_health >= max_health or _since_hit < REGEN_DELAY:
		return
	current_health = minf(max_health, current_health + REGEN_RATE * delta)
	health_changed.emit(current_health, max_health)

func take_damage(amount: float, from_dir := Vector3.ZERO) -> void:
	if amount > 0.0:
		_since_hit = 0.0
	if amount >= 1.0 and current_state != State.DEAD:
		play_hit_reaction(from_dir, clampf(amount / 25.0, 0.7, 1.0))
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		die()

## Seconds the ragdoll plays before Game Over pauses the tree.
@export var death_ragdoll_time: float = 1.6
var ragdoll: PhysicalBoneSimulator3D

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	_start_ragdoll()
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	if death_ragdoll_time > 0.0 and is_inside_tree():
		await get_tree().create_timer(death_ragdoll_time).timeout
	gm.change_state(gm.GameState.GAME_OVER)
	gm.handle_player_death()

func _start_ragdoll() -> void:
	if _anim_tree:
		_anim_tree.active = false
	_crouch_blend = 0.0
	var skeleton := visual_mesh.find_child("Skeleton3D", true, false) as Skeleton3D if visual_mesh else null
	ragdoll = RAGDOLL.start(skeleton, Vector3(velocity.x, 0.0, velocity.z) * 4.0, world_collision_mask)
	collision_layer = 0 # corpse no longer blocks enemies / camera

func start_reload() -> void:
	if reload_timer > 0.0 or ammunition == magazine_capacity or reserve_ammunition <= 0:
		return
	reload_timer = 1.4
	_sfx("reload", global_position)
	ammunition_changed.emit(ammunition, reserve_ammunition)

func fire_weapon() -> void:
	if weapon_cooldown > 0.0 or reload_timer > 0.0 or current_state == State.DEAD:
		return
	if ammunition <= 0:
		start_reload()
		return
	weapon_cooldown = 0.28
	ammunition -= 1
	ammunition_changed.emit(ammunition, reserve_ammunition)
	_sfx("fire", global_position)
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)
	# Third-person aim: start the crosshair ray level with Mara, so walls between the camera
	# and her (camera tucked behind a pillar) don't eat the shot; then fire from her chest to
	# the aimed point, so what she physically can't see she can't hit either.
	var chest := global_position + Vector3.UP * 1.3
	var ray_start := ray_origin + ray_dir * maxf(0.0, (chest - ray_origin).dot(ray_dir))
	var ray_end := ray_origin + ray_dir * 90.0
	var aim := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_end, 3, [get_rid()]))
	var aim_point: Vector3 = aim.position if not aim.is_empty() else ray_end
	var query := PhysicsRayQueryParameters3D.create(chest, chest + (aim_point - chest).normalized() * (chest.distance_to(aim_point) + 0.2), 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target = hit.collider
		if target.has_method("take_damage"):
			target.take_damage(30.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) < 30.0:
			enemy.hear_noise(global_position)

func melee_attack() -> void:
	if melee_cooldown > 0.0:
		return
	melee_cooldown = 0.8
	_sfx("melee", global_position)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.current_state == EnemyBase.AIState.DEAD:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		if offset.length() > 2.2:
			continue
		var direction := offset.normalized()
		var behind: bool = (-enemy.global_basis.z).dot(direction) > 0.5
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, 3, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == enemy:
			enemy.take_damage(100.0 if behind and current_state == State.CROUCH else 35.0)
			break
