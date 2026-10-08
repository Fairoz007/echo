extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://ui/MainMenu.tscn")
	await process_frame
	await process_frame
	var menu = current_scene
	if not menu.btn_settings.pressed.is_connected(menu._on_settings_pressed) or not menu.btn_credits.pressed.is_connected(menu._on_credits_pressed):
		printerr("QA FAILED: menu callbacks disconnected")
		quit(1)
		return
	menu.btn_settings.pressed.emit()
	await process_frame
	var panel = menu.get_node_or_null("MenuPanel")
	if not panel or not panel.find_children("*", "HSlider", true, false).size() == 1 or not panel.find_children("*", "CheckButton", true, false).size() == 1:
		printerr("QA FAILED: settings controls missing")
		quit(1)
		return
	var selectors = panel.find_children("*", "OptionButton", true, false)
	if selectors.size() != 1 or selectors[0].item_count != 5 or selectors[0].selected != root.get_node("GraphicsSettings").quality_level or selectors[0].get_signal_connection_list("item_selected").is_empty():
		printerr("QA FAILED: graphics choices missing, disconnected or inconsistent with active profile")
		quit(1)
		return
	panel.queue_free()
	await process_frame
	menu.btn_credits.pressed.emit()
	await process_frame
	panel = menu.get_node_or_null("MenuPanel")
	if not panel or panel.find_children("*", "Label", true, false).size() < 2:
		printerr("QA FAILED: credits panel missing")
		quit(1)
		return
	print("QA PASS: Settings/Credits callbacks and 5-level graphics selection; visual QA required")
	quit(0)
