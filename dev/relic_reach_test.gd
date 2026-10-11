extends SceneTree
## Physically walks Mara from the travel corridor to every relic shard and reads it.
## Proves shards are reachable with normal movement (headless OK; no mouse aim needed).
var fails := 0
func _init() -> void:
	call_deferred("_run")

func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)

func _run() -> void:
	var levels := ["Prologue", "Chapter1", "Chapter2", "Chapter3", "Chapter4", "Chapter5", "Chapter6", "Chapter7", "Chapter8", "Chapter9", "Chapter10", "Finale"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			levels = Array(a.substr(9).split(","))
	for l in levels:
		change_scene_to_file("res://levels/%s.tscn" % l)
		for i in 720:
			await physics_frame
		var lvl := current_scene
		var hunt := lvl.get_node_or_null("RelicHunt")
		var player = lvl.get_node("Player")
		# Patrols would shoot a test walker; this test is about reachability.
		for e in get_nodes_in_group("enemies"):
			if e.has_method("die"):
				e.die()
		var ok := 0
		for s in hunt.shards:
			var target: Vector3 = s.global_position
			player.velocity = Vector3.ZERO
			player.global_position = Vector3(0, target.y + 1.5, target.z)
			for i in 20:
				await physics_frame
			var reached := false
			for f in 3000:
				var off: Vector3 = target - player.global_position
				off.y = 0.0
				if player.nearby_interactable != null and off.length() < 2.0:
					reached = true
					break
				var dir: Vector3 = player.camera_pivot.global_basis.inverse() * off.normalized()
				_release()
				Input.action_press("move_right" if dir.x > 0.0 else "move_left", absf(dir.x))
				Input.action_press("move_back" if dir.z > 0.0 else "move_forward", absf(dir.z))
				await physics_frame
			_release()
			if reached:
				var ev := InputEventAction.new()
				ev.action = "interact"
				ev.pressed = true
				Input.parse_input_event(ev)
				await physics_frame
				ev = InputEventAction.new()
				ev.action = "interact"
				ev.pressed = false
				Input.parse_input_event(ev)
				for i in 10:
					await physics_frame
			if reached and s.collected:
				ok += 1
			else:
				print("RELICREACH FAIL ", l, " ", s.collectible_id, " at ", target, " player ", player.global_position)
				fails += 1
		print("RELICREACH ", l, " ", ok, "/", hunt.shards.size(), " collected=", hunt._announced)
	print("RELICREACH RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
