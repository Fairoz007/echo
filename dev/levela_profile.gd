extends SceneTree
## Level A: per-top-level-child _ready cost + following-frame costs. --scene=res://...
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://levels/Chapter9.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="): path = a.substr(8)
	var scene := (load(path) as PackedScene).instantiate()
	var kids := []
	for c in scene.get_children():
		kids.append(c)
		scene.remove_child(c)
	var t := Time.get_ticks_usec()
	root.add_child(scene)
	print("root ready %.0fms" % ((Time.get_ticks_usec() - t) / 1000.0))
	for c in kids:
		t = Time.get_ticks_usec()
		scene.add_child(c)
		var r := (Time.get_ticks_usec() - t) / 1000.0
		var f := ""
		for i in 4:
			var t2 := Time.get_ticks_usec()
			await process_frame
			f += " %.0f" % ((Time.get_ticks_usec() - t2) / 1000.0)
		print("%-28s ready=%6.0fms frames:%s" % [c.name, r, f])
	quit(0)
