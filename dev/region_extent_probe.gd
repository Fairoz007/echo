extends SceneTree
## Lists visual instances of a level that extend past a Z plane (for region-overlap planning).
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := "res://levels/Chapter5.tscn"
	var plane := -35.0
	var dir := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): path = a.substr(8)
		if a.begins_with("--z="): plane = float(a.substr(4))
		if a.begins_with("--dir="): dir = float(a.substr(6))
	var lvl: Node3D = load(path).instantiate()
	root.add_child(lvl)
	for i in 5:
		await process_frame
	var total := AABB()
	var first := true
	for n in lvl.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		var b := g.global_transform * g.get_aabb()
		if first: total = b; first = false
		else: total = total.merge(b)
		var beyond := (b.position.z < plane) if dir < 0 else (b.end.z > plane)
		if beyond and b.size.length() > 4.0:
			print("BEYOND ", str(lvl.get_path_to(g)).substr(0, 70), " z[", snappedf(b.position.z, 0.1), ",", snappedf(b.end.z, 0.1), "] y[", snappedf(b.position.y, 0.1), ",", snappedf(b.end.y, 0.1), "] x[", snappedf(b.position.x,0.1), ",", snappedf(b.end.x,0.1), "]")
	print("TOTAL ", total)
	quit(0)
