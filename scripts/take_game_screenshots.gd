extends Node

func _ready() -> void:
	print("--- SCREENSHOT CAPTURE PROCESS RUNNING ---")
	call_deferred("_capture_loop")

func _capture_loop() -> void:
	var screenshots_dir = "d:/new-dev/screenshots"
	DirAccess.make_dir_recursive_absolute(screenshots_dir)
	
	# Wait for initial frames to settle rendering
	for i in range(30):
		await get_tree().process_frame
		
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	if img:
		var err = img.save_png(screenshots_dir + "/gameplay_prologue.png")
		print("[SCREENSHOT] Saved gameplay_prologue.png result code: ", err)
	
	# Transition to Chapter 1
	var c01_res = load("res://levels/Chapter1.tscn")
	if c01_res:
		var c01 = c01_res.instantiate()
		get_tree().root.add_child(c01)
		
		# Allow camera and lighting to render
		for i in range(30):
			await get_tree().process_frame
			
		var img_c01 = vp.get_texture().get_image()
		if img_c01:
			var err2 = img_c01.save_png(screenshots_dir + "/gameplay_chapter1.png")
			print("[SCREENSHOT] Saved gameplay_chapter1.png result code: ", err2)
			
	print("--- SCREENSHOTS CAPTURED CLEANLY ---")
	get_tree().quit(0)
