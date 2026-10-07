extends SceneTree

var frame_count: int = 0
var current_phase: int = 0
var active_level: Node = null
var output_dir: String = "d:/new-dev/screenshots"

func _init() -> void:
	print("--- INITIALIZING SCREENSHOT CAPTURE IN GODOT SCENETREE ---")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scene_res = load("res://levels/Prologue.tscn")
	active_level = scene_res.instantiate()
	root.add_child(active_level)

func _process(delta: float) -> bool:
	frame_count += 1
	if current_phase == 0 and frame_count >= 15:
		# Capture Prologue
		var img = root.get_viewport().get_texture().get_image()
		if img:
			var err = img.save_png(output_dir + "/prologue_screenshot.png")
			print("Saved prologue_screenshot.png:", err)
		active_level.queue_free()
		
		# Load Chapter 1
		var c01_res = load("res://levels/Chapter1.tscn")
		active_level = c01_res.instantiate()
		root.add_child(active_level)
		current_phase = 1
		frame_count = 0

	elif current_phase == 1 and frame_count >= 15:
		# Capture Chapter 1
		var img = root.get_viewport().get_texture().get_image()
		if img:
			var err = img.save_png(output_dir + "/chapter1_screenshot.png")
			print("Saved chapter1_screenshot.png:", err)
		current_phase = 2
		quit(0)
	return false
