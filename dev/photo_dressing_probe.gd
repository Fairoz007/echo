extends SceneTree
## Loads each dressed level and reports PhotoDressing counts (headless OK).
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	for l in ["Prologue", "Chapter2", "Chapter3", "Chapter4", "Chapter7", "Chapter9", "Chapter10", "Finale"]:
		var lvl: Node = load("res://levels/%s.tscn" % l).instantiate()
		root.add_child(lvl)
		for i in 30:
			await physics_frame
		var pd := lvl.get_node_or_null("PhotoDressing")
		print("PROBE ", l, " dressing children=", pd.get_child_count() if pd else -1)
		lvl.queue_free()
		await process_frame
	quit(0)
