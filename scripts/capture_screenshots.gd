extends SceneTree

# Automated headless screenshot verification of Mara in Prologue and Chapter 1

func _init() -> void:
	print("--- CAPTURING GAMEPLAY VERIFICATION SCREENSHOTS FOR MARA VALE ---")
	call_deferred("_run_capture")

func _run_capture() -> void:
	# Load Chapter 1
	var c01_scene = load("res://levels/Chapter1.tscn")
	var c01 = c01_scene.instantiate()
	root.add_child(c01)
	
	# Wait for rendering frames
	for i in range(15):
		await process_frame
		
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("d:/new-dev/screenshots")
	var err = img.save_png("d:/new-dev/screenshots/review_mara_chapter1.png")
	print("Chapter 1 screenshot saved to d:/new-dev/screenshots/review_mara_chapter1.png, status code:", err)
	
	c01.queue_free()
	
	# Load Prologue
	var pro_scene = load("res://levels/Prologue.tscn")
	var pro = pro_scene.instantiate()
	root.add_child(pro)
	
	for i in range(15):
		await process_frame
		
	var img_pro = root.get_viewport().get_texture().get_image()
	var err_pro = img_pro.save_png("d:/new-dev/screenshots/review_mara_prologue.png")
	print("Prologue screenshot saved to d:/new-dev/screenshots/review_mara_prologue.png, status code:", err_pro)
	
	print("--- SCREENSHOT CAPTURE COMPLETE ---")
	quit(0)
