extends SceneTree
## Level A: hold W from Prologue spawn (no interaction) and log progress + slide colliders.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://levels/Prologue.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var gm = root.get_node("GameManager")
	gm.current_state = gm.GameState.GAMEPLAY
	await create_timer(1.5).timeout
	var player = get_first_node_in_group("player")
	print("start ", player.global_position)
	Input.action_press("move_forward")
	var min_z := INF
	var seen := {}
	for f in 1200:
		await physics_frame
		var p: Vector3 = player.global_position
		min_z = minf(min_z, p.z)
		for i in player.get_slide_collision_count():
			var c = player.get_slide_collision(i)
			var n: Vector3 = c.get_normal()
			if n.y < 0.7:
				var k := str(scene.get_path_to(c.get_collider())) if c.get_collider() else "?"
				if not seen.has(k):
					seen[k] = true
					print("wall hit z=%.2f pos=%s n=%s by %s" % [p.z, p, n, k])
		if f % 60 == 0:
			print("t=%d pos=%s vel=%s" % [f / 60, p, player.velocity])
	Input.action_release("move_forward")
	print("WALK min_z=%.2f final=%s" % [min_z, player.global_position])
	quit(0 if min_z < -24.0 else 1)
