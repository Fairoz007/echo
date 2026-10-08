extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud = load("res://ui/HUD.tscn").instantiate()
	var viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	root.add_child(viewport)
	viewport.add_child(hud)
	await process_frame
	await process_frame
	var before: Vector2 = hud.reticle.position
	viewport.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	if hud.reticle.position == before or hud.reticle.get_global_rect().get_center().distance_to(Vector2(640, 360)) > 4.0 or hud.reticle.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		printerr("QA FAILED: reticle did not follow viewport center after resize or intercepted mouse input")
		quit(1)
		return
	hud.show_subtitle("Mara", "First", 0.1)
	hud.show_subtitle("Mara", "Second", 0.5)
	await create_timer(0.2).timeout
	if not hud.subtitle_label.visible or not "Second" in hud.subtitle_label.text:
		printerr("QA FAILED: stale subtitle timer hid current line")
		quit(1)
		return
	hud._on_objective_updated("old", "Completed", true)
	hud._on_objective_updated("new", "Current", false)
	await create_timer(4.1).timeout
	if not "Current" in hud.objective_label.text:
		printerr("QA FAILED: stale completion timer erased current objective")
		quit(1)
		return
	print("QA PASS: subtitle/objective timer ownership and reticle center after viewport resize")
	quit(0)
