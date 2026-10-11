extends SceneTree
## Times each phase of a level's _ready by instancing it fresh (headless OK).
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := "res://levels/Chapter6.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			path = a.substr(8)
	var t0 := Time.get_ticks_usec()
	var packed := load(path) as PackedScene
	var t1 := Time.get_ticks_usec()
	var inst := packed.instantiate()
	var t2 := Time.get_ticks_usec()
	root.add_child(inst)
	var t3 := Time.get_ticks_usec()
	print("PROFILE %s load %.0f ms, instantiate %.0f ms, enter+ready %.0f ms" % [path, (t1-t0)/1000.0, (t2-t1)/1000.0, (t3-t2)/1000.0])
	quit(0)
