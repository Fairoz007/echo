extends SceneTree
## Level A: LOW-preset screenshots of a level: player view + one view per HeroProps model.
## Args after --: --scene=res://levels/X.tscn  Output: screenshots/levela/<X>_<n>.png
func _init() -> void:
	call_deferred("_run")

func _shot(tag: String, base: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/levela/%s_%s.png" % [base, tag])
	print("SHOT ", base, "_", tag)

func _run() -> void:
	var path := "res://levels/Prologue.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="): path = a.substr(8)
	var base := path.get_file().get_basename()
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var gm = root.get_node("GameManager")
	gm.current_state = gm.GameState.GAMEPLAY
	await create_timer(5.0).timeout
	await _shot("00_player", base)
	var cam := Camera3D.new()
	cam.far = 400.0
	scene.add_child(cam)
	var n := 1
	for hp in scene.find_children("HeroProps*", "Node3D", true, false):
		for model in hp.get_children():
			if not model is Node3D:
				continue
			var b := AABB()
			var first := true
			for m in model.find_children("*", "MeshInstance3D", true, false):
				var a: AABB = m.global_transform * m.get_aabb()
				b = a if first else b.merge(a)
				first = false
			if first:
				continue
			var c := b.get_center()
			var r := maxf(b.size.length() * 0.5, 1.0)
			var player = get_first_node_in_group("player")
			var from_dir := Vector3(0.4, 0.35, 1).normalized()
			if player:
				var d: Vector3 = (player.global_position - c)
				d.y = 0
				if d.length() > 0.5:
					from_dir = (d.normalized() + Vector3(0, 0.35, 0)).normalized()
			cam.global_position = c + from_dir * r * 2.2
			cam.look_at(c, Vector3.UP)
			cam.make_current()
			await _shot("%02d_%s" % [n, String(model.name).left(30)], base)
			n += 1
	quit(0)
