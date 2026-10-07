extends CharacterBody3D
class_name Player

## Third-Person Character Controller for Mara Vale
@export_group("Locomotion Speeds")
@export var walk_speed: float = 2.2
@export var run_speed: float = 4.8
@export var sprint_speed: float = 7.2
@export var crouch_speed: float = 1.5
@export var swim_speed: float = 3.2
@export var jump_velocity: float = 5.2
@export var rotation_speed: float = 12.0

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

# Kinematic Locomotion & Gait Simulation
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
	DEAD
}

var current_state: State = State.IDLE
var is_flashlight_on: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var nearby_interactable: Interactable3D = null

# Traversal Probes
var mantle_target_pos: Vector3 = Vector3.ZERO
var mantle_timer: float = 0.0

signal health_changed(new_health: float, max_h: float)
signal stamina_changed(new_stamina: float, max_s: float)
signal oxygen_changed(new_oxygen: float, max_o: float)
signal interactable_detected(prompt: String)
signal interactable_lost()

func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_oxygen = max_oxygen
	if flashlight:
		flashlight.visible = is_flashlight_on
	if visual_mesh:
		visual_base_y = visual_mesh.position.y
		if not anim_player:
			anim_player = visual_mesh.find_child("AnimationPlayer", true, false)
	_setup_interaction_detector()


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
		interaction_detector.collision_mask = 4 # Interactable layer
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
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact") and nearby_interactable:
		nearby_interactable.trigger_interaction(self)

func toggle_flashlight() -> void:
	is_flashlight_on = not is_flashlight_on
	if flashlight:
		flashlight.visible = is_flashlight_on
	print("[PLAYER] Flashlight toggled:", is_flashlight_on)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
		
	if current_state == State.MANTLE:
		_process_mantle(delta)
		return

	# Handle Gravity
	if not is_on_floor() and current_state != State.SWIM:
		velocity.y -= gravity * delta
		if velocity.y < 0 and current_state != State.FALL:
			current_state = State.FALL
			
	# Read Player Inputs
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_sprinting = Input.is_action_pressed("sprint") and current_stamina > 5.0
	var is_crouching = Input.is_action_pressed("crouch")
	
	# Determine Target Speed
	var target_speed = run_speed
	if current_state == State.SWIM:
		target_speed = swim_speed
	elif is_crouching:
		target_speed = crouch_speed
		current_state = State.CROUCH
	elif is_sprinting and input_dir.length() > 0.1:
		target_speed = sprint_speed
		current_state = State.SPRINT
		current_stamina = max(0.0, current_stamina - 15.0 * delta)
		stamina_changed.emit(current_stamina, max_stamina)
	elif input_dir.length() > 0.1:
		target_speed = run_speed
		current_state = State.RUN
		current_stamina = min(max_stamina, current_stamina + 10.0 * delta)
		stamina_changed.emit(current_stamina, max_stamina)
	else:
		target_speed = 0.0
		if is_on_floor() and current_state != State.SWIM:
			current_state = State.IDLE
		current_stamina = min(max_stamina, current_stamina + 20.0 * delta)
		stamina_changed.emit(current_stamina, max_stamina)

	# Transform input relative to camera orientation
	var cam_basis = camera_pivot.global_transform.basis if camera_pivot else Basis.IDENTITY
	var direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0.0
	direction = direction.normalized()
	
	if direction.length() > 0.1:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
		# Orient visual mesh towards moving direction
		if visual_mesh:
			var target_rot = atan2(-direction.x, -direction.z)
			visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_rot, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, run_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, run_speed * delta * 5.0)

	# Realistic Kinematic Gait Simulation (Walking, Running, Breathing, Leaning)
	_apply_gait_animation(delta, input_dir.length(), target_speed)

	# Traversal: Ledge / Mantle Probe

	if (is_on_wall() or not is_on_floor()) and Input.is_action_just_pressed("jump"):
		if _check_and_trigger_mantle(direction):
			return

	# Jump Logic
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		current_state = State.JUMP

	move_and_slide()

func _apply_gait_animation(delta: float, input_magnitude: float, target_speed: float) -> void:
	if not visual_mesh:
		return
		
	# Check if native AnimationPlayer with 'walk' clip exists
	if anim_player and anim_player.has_animation("walk"):
		if input_magnitude > 0.1 and is_on_floor():
			if not anim_player.is_playing() or anim_player.current_animation != "walk":
				anim_player.play("walk")
			anim_player.speed_scale = target_speed / walk_speed
		else:
			if anim_player.is_playing() and anim_player.current_animation == "walk":
				anim_player.stop()
		return

	# Secondary Procedural Kinematic Gait (eliminates rigid or floaty gliding)
	if is_on_floor() and input_magnitude > 0.1:
		var cadence = 9.0 if current_state == State.SPRINT else (7.2 if current_state == State.RUN else 5.2)
		gait_phase += delta * cadence
		
		# Vertical hip bounce (bobbing down on heel contact, pushing up on stride)
		var bob_height = 0.055 if current_state == State.RUN else 0.035
		var target_y = visual_base_y + abs(sin(gait_phase)) * bob_height
		visual_mesh.position.y = lerp(visual_mesh.position.y, target_y, delta * 18.0)
		
		# Lateral pelvic sway / weight shift (shifting weight over the supporting foot)
		var sway_angle = 0.065 if current_state == State.RUN else 0.04
		visual_mesh.rotation.z = lerp(visual_mesh.rotation.z, sin(gait_phase * 0.5) * sway_angle, delta * 14.0)
		
		# Torso forward pitch/lean proportional to speed
		var forward_pitch = 0.14 if current_state == State.SPRINT else (0.09 if current_state == State.RUN else 0.04)
		visual_mesh.rotation.x = lerp(visual_mesh.rotation.x, forward_pitch, delta * 12.0)
		
		# Cadence footstep sound trigger
		step_timer += delta * (cadence / PI)
		if step_timer >= 1.0:
			step_timer = 0.0
			AudioManager.play_sfx("footstep_stone", global_position)
	else:
		# Idle resting & breathing cycle
		gait_phase += delta * 2.2
		var breathing_bob = sin(gait_phase) * 0.008
		visual_mesh.position.y = lerp(visual_mesh.position.y, visual_base_y + breathing_bob, delta * 8.0)
		visual_mesh.rotation.z = lerp(visual_mesh.rotation.z, 0.0, delta * 10.0)
		visual_mesh.rotation.x = lerp(visual_mesh.rotation.x, 0.0, delta * 10.0)


func _check_and_trigger_mantle(forward_dir: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var move_forward = forward_dir if forward_dir.length() > 0.1 else -transform.basis.z
	
	# Ray 1: Forward wall ray at chest height (1.2m)
	var chest_origin = global_position + Vector3(0, 1.2, 0)
	var chest_target = chest_origin + move_forward * 1.0
	var query_wall = PhysicsRayQueryParameters3D.create(chest_origin, chest_target)
	query_wall.collision_mask = 2 # World geometry
	var hit_wall = space_state.intersect_ray(query_wall)
	
	if hit_wall:
		# Ray 2: Top-down probe for ledge landing surface (up to 2.2m high)
		var top_origin = hit_wall.position + move_forward * 0.4 + Vector3(0, 1.5, 0)
		var top_target = top_origin + Vector3(0, -2.0, 0)
		var query_ledge = PhysicsRayQueryParameters3D.create(top_origin, top_target)
		query_ledge.collision_mask = 2
		var hit_ledge = space_state.intersect_ray(query_ledge)
		
		if hit_ledge and hit_ledge.position.y > global_position.y + 0.6:
			mantle_target_pos = hit_ledge.position + Vector3(0, 0.9, 0)
			current_state = State.MANTLE
			mantle_timer = 0.0
			velocity = Vector3.ZERO
			print("[PLAYER] Mantle initiated towards:", mantle_target_pos)
			return true
	return false

func _process_mantle(delta: float) -> void:
	mantle_timer += delta * 3.5
	global_position = global_position.lerp(mantle_target_pos, delta * 8.0)
	if mantle_timer >= 1.0 or global_position.distance_to(mantle_target_pos) < 0.2:
		global_position = mantle_target_pos
		current_state = State.IDLE
		velocity = Vector3.ZERO
		print("[PLAYER] Mantle completed successfully.")

func enter_water() -> void:
	current_state = State.SWIM
	velocity.y = 0.0
	print("[PLAYER] Entered water body.")

func exit_water() -> void:
	current_state = State.IDLE
	print("[PLAYER] Exited water body.")

func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	print("[PLAYER] Took damage:", amount, "Remaining HP:", current_health)
	if current_health <= 0:
		die()

func die() -> void:
	current_state = State.DEAD
	print("[PLAYER] Protagonist perished. Restarting from checkpoint...")
	GameManager.change_state(GameManager.GameState.GAME_OVER)
