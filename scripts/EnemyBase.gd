extends CharacterBody3D
class_name EnemyBase

## Base Tactical AI for Meridian Mercenary Units
enum AIState {
	PATROL,
	SUSPICIOUS,
	ALERT,
	COMBAT,
	TAKE_COVER,
	DEAD
}

@export var max_health: float = 60.0
@export var current_health: float = 60.0
@export var patrol_speed: float = 1.8
@export var chase_speed: float = 4.2
@export var sight_range: float = 18.0
@export var sight_fov_deg: float = 85.0
@export var attack_range: float = 12.0
@export var attack_damage: float = 15.0

var current_state: AIState = AIState.PATROL
var target_player: Player = null
var patrol_points: Array[Vector3] = []
var current_patrol_idx: int = 0
var attack_cooldown: float = 0.0

@export var visual_mesh: Node3D
@export var eyes_marker: Marker3D

signal enemy_died(enemy: EnemyBase)

func _ready() -> void:
	current_health = max_health
	# Populate local patrol offsets
	patrol_points = [
		global_position,
		global_position + transform.basis.z * 6.0,
		global_position + transform.basis.x * 6.0
	]

func _physics_process(delta: float) -> void:
	if current_state == AIState.DEAD:
		return
		
	attack_cooldown = max(0.0, attack_cooldown - delta)
	_scan_for_player()
	
	match current_state:
		AIState.PATROL:
			_process_patrol(delta)
		AIState.ALERT:
			_process_alert(delta)
		AIState.COMBAT:
			_process_combat(delta)

	move_and_slide()

func _scan_for_player() -> void:
	var player = get_tree().get_first_node_in_group("player") as Player
	if not player or player.current_state == Player.State.DEAD:
		target_player = null
		if current_state == AIState.COMBAT:
			current_state = AIState.PATROL
		return
		
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	
	if dist <= sight_range:
		# Check FOV angle
		var forward = -transform.basis.z
		var angle = rad_to_deg(forward.angle_to(to_player.normalized()))
		if angle <= sight_fov_deg * 0.5 or dist < 3.0: # Close range auto-detects
			# Line of sight raycast
			var space = get_world_3d().direct_space_state
			var from = global_position + Vector3(0, 1.4, 0)
			var to = player.global_position + Vector3(0, 1.2, 0)
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.collision_mask = 3 # Player + Environment
			var hit = space.intersect_ray(query)
			if hit and hit.collider == player:
				target_player = player
				if current_state != AIState.COMBAT:
					current_state = AIState.COMBAT
					print("[AI] Mercenary acquired target! Entering COMBAT state.")
				return

func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target = patrol_points[current_patrol_idx]
	var dir = (target - global_position)
	dir.y = 0.0
	if dir.length() < 0.6:
		current_patrol_idx = (current_patrol_idx + 1) % patrol_points.size()
	else:
		velocity.x = dir.normalized().x * patrol_speed
		velocity.z = dir.normalized().z * patrol_speed
		_look_towards(dir.normalized(), delta)

func _process_alert(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, patrol_speed * _delta * 3.0)
	velocity.z = move_toward(velocity.z, 0, patrol_speed * _delta * 3.0)

func _process_combat(delta: float) -> void:
	if not target_player:
		current_state = AIState.PATROL
		return
		
	var dir = (target_player.global_position - global_position)
	dir.y = 0.0
	var dist = dir.length()
	
	_look_towards(dir.normalized(), delta)
	
	if dist > attack_range:
		velocity.x = dir.normalized().x * chase_speed
		velocity.z = dir.normalized().z * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0, chase_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0, chase_speed * delta * 4.0)
		if attack_cooldown <= 0.0:
			_attack_player()

func _look_towards(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		var target_yaw = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

func _attack_player() -> void:
	attack_cooldown = 1.8
	if target_player:
		print("[AI] Mercenary fires weapon at player!")
		target_player.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if current_state == AIState.DEAD:
		return
	current_health -= amount
	print("[AI] Mercenary hit! Remaining HP:", current_health)
	if current_health <= 0:
		die()
	else:
		current_state = AIState.COMBAT

func die() -> void:
	current_state = AIState.DEAD
	velocity = Vector3.ZERO
	enemy_died.emit(self)
	print("[AI] Mercenary defeated.")
	# Visual collapse animation
	var tw = create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(-80), 0.4)
	tw.tween_interval(2.0)
	tw.tween_callback(func(): queue_free())
