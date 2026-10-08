extends Area3D

var surface: Node3D
var swimmers: Array[Player] = []
var previous_height := NAN

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(func(body):
		if body is Player and not swimmers.has(body):
			swimmers.append(body))
	body_exited.connect(func(body):
		if body is Player:
			swimmers.erase(body)
			if body.current_state == Player.State.SWIM:
				body.exit_water())

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(surface):
		return
	var height := surface.global_position.y + 0.4
	var surface_velocity := 0.0 if is_nan(previous_height) else clampf((height - previous_height) / maxf(_delta, 0.001), -4.0, 4.0)
	previous_height = height
	for player in swimmers:
		if not is_instance_valid(player) or player.current_state == Player.State.DEAD:
			continue
		player.water_surface = height
		player.water_vertical_velocity = surface_velocity
		# Separate waist-depth entry from exit so drainage and shore movement
		# cannot switch locomotion and splash audio every physics frame.
		if player.current_state == Player.State.SWIM:
			if player.global_position.y > height - 0.55 or player.is_on_floor() and player.global_position.y > height - 0.8:
				player.exit_water()
		elif player.global_position.y < height - 0.8:
			player.enter_water()
