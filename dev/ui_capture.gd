extends SceneTree

## UI screenshot harness. Usage: -s res://dev/ui_capture.gd -- --quality=1 --prefix=before
var prefix := "after"
var out_dir := "res://screenshots/ui"

func _init() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	var path := ProjectSettings.globalize_path(out_dir.path_join("%s_%s.png" % [prefix, name]))
	root.get_texture().get_image().save_png(path)
	print("[UICAP] ", path)

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prefix="):
			prefix = a.get_slice("=", 1)
	var gm = root.get_node("GameManager")
	root.get_node("GraphicsSettings").apply_quality(1, false)
	change_scene_to_file("res://ui/MainMenu.tscn")
	await _wait(1.5)
	await _shot("main_menu")
	var menu = current_scene
	menu.btn_settings.pressed.emit()
	await _wait(0.6)
	await _shot("settings")
	var panel = menu.get_node_or_null("MenuPanel")
	var tabs = panel.find_children("*", "TabContainer", true, false) if panel else []
	if tabs.size() > 0:
		for i in range(1, tabs[0].get_tab_count()):
			tabs[0].current_tab = i
			await _wait(0.3)
			await _shot("settings_tab%d" % i)
	if panel:
		panel.free()
	menu.btn_credits.pressed.emit()
	await _wait(0.6)
	await _shot("credits")
	panel = menu.get_node_or_null("MenuPanel")
	if panel:
		panel.free()
	# Chapter card (no load) and credits card.
	gm.transition.play(3, "")
	await _wait(5.0)
	await _shot("story_card")
	gm.transition._skip_requested = true
	await _wait(1.5)
	# Gameplay HUD
	change_scene_to_file("res://levels/Prologue.tscn")
	await _wait(6.0)
	gm.change_state(gm.GameState.GAMEPLAY)
	await _wait(1.0)
	var hud = current_scene.get_node_or_null("HUD")
	var player = get_first_node_in_group("player")
	await _shot("hud_idle")
	if hud:
		hud._on_objective_updated("ui_cap", "Find a way out of the flooded cavern", false)
		hud.show_prompt("Examine the carved relief")
		hud.show_subtitle("Mara", "The stone is humming... like it's answering something below.", 6.0)
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.emit(55.0, 100.0)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.emit(40.0, 100.0)
		if player.has_signal("oxygen_changed"):
			player.oxygen_changed.emit(14.0, 30.0)
	await _wait(0.8)
	await _shot("hud_active")
	gm._pause_menu.show_menu(false)
	await _wait(0.6)
	await _shot("pause")
	gm._pause_menu.panel.hide()
	gm._pause_menu.show_menu(true)
	await _wait(0.6)
	await _shot("death")
	gm._pause_menu.panel.hide()
	paused = false
	gm.change_state(gm.GameState.GAMEPLAY)
	await _wait(0.4)
	gm.journal_screen.open(0)
	await _wait(0.6)
	await _shot("journal")
	gm.journal_screen.tabs.current_tab = 1
	await _wait(0.3)
	await _shot("journal_inventory")
	gm.journal_screen.tabs.current_tab = 2
	await _wait(0.3)
	await _shot("journal_skills")
	gm.journal_screen.close()
	gm.transition.play(13, "")
	await _wait(3.5)
	await _shot("credits_card")
	print("[UICAP] done")
	quit(0)
