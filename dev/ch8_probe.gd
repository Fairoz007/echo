extends SceneTree
## DEV ONLY: loads Chapter 8 headless and runs a few seconds to catch Player errors.
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var t := Time.get_ticks_msec()
	var ps := load("res://levels/Chapter8.tscn") as PackedScene
	print("CH8 loaded ", Time.get_ticks_msec() - t)
	var lv := ps.instantiate()
	print("CH8 inst ", Time.get_ticks_msec() - t)
	root.add_child(lv)
	print("CH8 added ", Time.get_ticks_msec() - t)
	for i in 180:
		await physics_frame
		if i % 30 == 0: print("CH8 f", i, " ", Time.get_ticks_msec() - t)
	print("CH8 OK")
	quit()
