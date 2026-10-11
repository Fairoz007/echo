extends SceneTree
## Loads each level and reports how many relic shards RelicHunt placed (headless OK).
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	for l in ["Prologue", "Chapter1", "Chapter2", "Chapter3", "Chapter4", "Chapter5", "Chapter6", "Chapter7", "Chapter8", "Chapter9", "Chapter10", "Finale"]:
		var lvl: Node = load("res://levels/%s.tscn" % l).instantiate()
		root.add_child(lvl)
		for i in 90:
			await physics_frame
		var h := lvl.get_node_or_null("RelicHunt")
		print("RELICPROBE ", l, " shards=", h.shards.size() if h else -1)
		lvl.queue_free()
		await process_frame
	quit(0)
