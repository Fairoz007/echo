extends SceneTree
## godot --headless --path . --script res://dev/generate_water_presets.gd
func _init() -> void:
	for n in WaterPreset.NAMES:
		var p := WaterPreset.make(n)
		var path := "res://systems/water/presets/%s.tres" % n
		print(n, " -> ", ResourceSaver.save(p, path))
	quit()
