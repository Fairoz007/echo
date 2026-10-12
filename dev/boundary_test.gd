extends SceneTree
## Every chapter boundary (except 5->6, covered by region_handoff_test) advances in-world:
## no story card, same Mara/HUD, health+ammo kept, one player, passage present for walkable
## exits, and a save taken just after the boundary reloads to the same spot.
## Usage: godot --headless -s res://dev/boundary_test.gd [-- --from=0 --to=10]
var fails := 0
func _check(label: String, ok: bool, info := "") -> void:
	print("BOUNDARY ", "PASS " if ok else "FAIL ", label, " ", info)
	if not ok:
		fails += 1
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var gm := root.get_node("GameManager")
	var sm := root.get_node("SaveManager")
	var from := 0
	var to := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="): from = int(a.substr(7))
		if a.begins_with("--to="): to = int(a.substr(5))
	for c in range(from, to + 1):
		if c == 5:
			continue
		change_scene_to_file(gm.chapter_scene(c))
		for i in 120:
			await physics_frame
		gm.current_chapter = c
		gm.change_state(gm.GameState.GAMEPLAY)
		var scene := current_scene
		var player = scene.get_node("Player")
		for e in get_nodes_in_group("enemies"):
			if e.has_method("die"):
				e.die()
		player.current_health = 77.0
		player.set("_since_hit", -1.0e9) # measure preservation, not regeneration
		player.set("ammunition", 5)
		var pid: int = player.get_instance_id()
		var hud = scene.get_node_or_null("HUD")
		var hid: int = hud.get_instance_id() if hud else 0
		var walkable: bool = gm.IN_WORLD_EXITS.has(c)
		# Stand at the exit, as a player would when the chapter's exit fires.
		if walkable:
			var anchor: Node3D = scene.get_node(gm.IN_WORLD_EXITS[c])
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(anchor.global_position + Vector3.UP, anchor.global_position + Vector3.DOWN * 6.0, 3, [player.get_rid()]))
			player.global_position = ((hit.position as Vector3) if hit else anchor.global_position) + Vector3(0, 0.05, 0.5)
			for i in 10:
				await physics_frame
		gm.load_chapter(c + 1, gm.chapter_scene(c + 1))
		_check("ch%d: no story card" % c, not gm.transition.is_active())
		if walkable:
			var passage = scene.get_node_or_null("ExitPassage")
			_check("ch%d: exit passage built" % c, passage != null)
			if passage:
				player.global_position = passage.to_global(Vector3(4.5, 0.1, -12.0))
		var waited := 0
		while gm.current_chapter != c + 1 and waited < 900:
			await physics_frame
			waited += 1
		for i in 30:
			await physics_frame
		var next := current_scene
		_check("ch%d->%d: chapter advanced" % [c, c + 1], gm.current_chapter == c + 1 and next != scene, "waited %d" % waited)
		_check("ch%d->%d: same Mara" % [c, c + 1], is_instance_valid(player) and player.get_instance_id() == pid and player.get_parent() == next)
		_check("ch%d->%d: same HUD" % [c, c + 1], hid == 0 or (next.get_node_or_null("HUD") and next.get_node("HUD").get_instance_id() == hid))
		_check("ch%d->%d: health kept" % [c, c + 1], is_instance_valid(player) and is_equal_approx(player.current_health, 77.0), str(player.current_health if is_instance_valid(player) else -1))
		_check("ch%d->%d: ammo kept" % [c, c + 1], is_instance_valid(player) and player.get("ammunition") == 5)
		_check("ch%d->%d: one player" % [c, c + 1], get_nodes_in_group("player").size() == 1)
		_check("ch%d->%d: no story card" % [c, c + 1], not gm.transition.is_active())
		if walkable:
			_check("ch%d->%d: entry passage" % [c, c + 1], next.get_node_or_null("EntryPassage") != null)
			# Save right after the boundary (Mara inside the entry passage) and reload it.
			var saved: Vector3 = player.global_position
			_check("ch%d->%d: save" % [c, c + 1], sm.save_game(0))
			sm.load_game(0)
			gm.load_chapter(c + 1, gm.chapter_scene(c + 1))
			var t := 0
			while t < 1500 and (current_scene == next or current_scene == null or gm.transition.is_active()):
				await process_frame
				t += 1
			for i in 90:
				await physics_frame
			var p2 = get_first_node_in_group("player")
			_check("ch%d->%d: reload keeps position" % [c, c + 1], p2 != null and p2.global_position.distance_to(saved) < 1.0, "%s vs %s" % [p2.global_position if p2 else Vector3.INF, saved])
			_check("ch%d->%d: reloaded entry passage sealed" % [c, c + 1], current_scene.get_node_or_null("EntryPassage") != null)
	print("BOUNDARY RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
