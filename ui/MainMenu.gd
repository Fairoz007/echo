extends Control

## Main Menu Controller for ECHOES BENEATH
const GameTheme := preload("res://ui/GameTheme.gd")

@onready var btn_continue: Button = $VBoxContainer/BtnContinue
@onready var btn_new_game: Button = $VBoxContainer/BtnNewGame
@onready var btn_settings: Button = $VBoxContainer/BtnSettings
@onready var btn_credits: Button = $VBoxContainer/BtnCredits
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
var _last_opener: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = GameTheme.get_theme()
	var bg_mat := GameTheme.mist_material(0.14)
	bg_mat.set_shader_parameter("tint", Vector3(0.36, 0.34, 0.26))
	$Background.material = bg_mat
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		AudioServer.set_bus_volume_linear(0, clampf(float(settings.get_value("audio", "master_volume", 1.0)), 0.0, 1.0))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get_value("display", "fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_quit.pressed.connect(func(): get_tree().quit())

	# Check if save file exists
	var save_exists = FileAccess.file_exists(SaveManager.save_path(0))
	btn_continue.disabled = not save_exists
	if save_exists:
		btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.tooltip_text = "" if save_exists else "No saved expedition yet"
	GameTheme.wire_sounds(self)
	(btn_continue if save_exists else btn_new_game).grab_focus()
	# Staggered entrance: kicker, title, rule, tagline, buttons, footer.
	var items: Array = [$Kicker, $TitleLabel, $TitleRule, $SubtitleLabel, $VBoxContainer, $Footer]
	for i in items.size():
		var c: CanvasItem = items[i]
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_new_game_pressed() -> void:
	GameManager.start_new_game()

func _on_continue_pressed() -> void:
	if SaveManager.load_game(0):
		var ch = SaveManager.game_data.get("chapter", 0)
		var level_file = chapter_scene(ch)
		if level_file.is_empty():
			push_error("[MENU] Unsupported saved chapter: " + str(ch))
			return
		GameManager.load_chapter(ch, level_file)

func chapter_scene(chapter: int) -> String:
	if chapter == 0:
		return "res://levels/Prologue.tscn"
	if chapter >= 1 and chapter <= 10:
		return "res://levels/Chapter%d.tscn" % chapter
	if chapter == 11:
		return "res://levels/Finale.tscn"
	if chapter == 12:
		return "res://levels/Epilogue.tscn"
	return ""

## Borderless themed modal (node name "MenuPanel" is relied on by QA scripts).
func _make_panel(title: String) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.014, 0.012, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var popup := Window.new()
	popup.name = "MenuPanel"
	popup.tree_exiting.connect(dim.queue_free)
	popup.title = title
	popup.borderless = true
	popup.transient = true
	popup.exclusive = true
	popup.theme = GameTheme.get_theme()
	var vp := get_viewport().get_visible_rect().size
	popup.size = Vector2i(int(clampf(vp.x * 0.42, 660.0, 900.0)), int(clampf(vp.y * 0.62, 520.0, 760.0)))
	add_child(popup)
	popup.close_requested.connect(func(): _close_panel(popup))
	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(backdrop)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	backdrop.add_child(outer)
	var header := HBoxContainer.new()
	header.add_child(GameTheme.heading(title.to_upper(), GameTheme.FS_H1))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", GameTheme.FS_BODY)
	back.pressed.connect(func(): _close_panel(popup))
	header.add_child(back)
	outer.add_child(header)
	outer.add_child(GameTheme.rule())
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	outer.add_child(content)
	popup.window_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_cancel"):
			popup.set_input_as_handled()
			_close_panel(popup))
	popup.popup_centered()
	GameTheme.play_ui("open")
	GameTheme.fade_in(backdrop, Vector2.ZERO, 0.2)
	(func():
		if is_instance_valid(popup):
			GameTheme.wire_sounds(popup)
			var tabs := popup.find_children("*", "TabContainer", true, false)
			if tabs.size() > 0:
				tabs[0].get_tab_bar().grab_focus()
			else:
				back.grab_focus()).call_deferred()
	return content

func _close_panel(popup: Window) -> void:
	if not is_instance_valid(popup) or popup.is_queued_for_deletion():
		return
	GameTheme.play_ui("back")
	popup.queue_free()
	if is_instance_valid(_last_opener):
		_last_opener.grab_focus()

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 14)
	tabs.add_child(page)
	return page

func _on_settings_pressed() -> void:
	_last_opener = btn_settings
	var content := _make_panel("Settings")
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var audio := _tab(tabs, "Audio")
	var label := Label.new()
	label.text = "Master volume"
	audio.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.value = AudioServer.get_bus_volume_linear(0)
	var pct := Label.new()
	pct.custom_minimum_size.x = 60
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_color_override("font_color", GameTheme.ACCENT)
	pct.text = "%d%%" % int(round(volume.value * 100.0))
	volume.value_changed.connect(func(value):
		AudioServer.set_bus_volume_linear(0, value)
		pct.text = "%d%%" % int(round(value * 100.0))
		_save_settings(value, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN))
	row.add_child(volume)
	row.add_child(pct)
	audio.add_child(row)
	audio.add_child(GameTheme.caption("Music, dialogue and effects all follow the master level."))
	var display := _tab(tabs, "Display")
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
		_save_settings(AudioServer.get_bus_volume_linear(0), enabled))
	display.add_child(fullscreen)
	display.add_child(GameTheme.caption("The interface scales automatically with the window size."))
	add_graphics_controls(_tab(tabs, "Graphics"))

## Shared by MainMenu and PauseMenu: quality selector + live description, persisted by GraphicsSettings.
static func add_graphics_controls(content: Control) -> OptionButton:
	var graphics_label := Label.new()
	graphics_label.text = "Graphics quality"
	content.add_child(graphics_label)
	var graphics := OptionButton.new()
	graphics.name = "GraphicsQuality"
	for quality in GraphicsSettings.QUALITY_NAMES:
		graphics.add_item(quality)
	graphics.select(GraphicsSettings.quality_level)
	content.add_child(graphics)
	var details := Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 15)
	details.add_theme_color_override("font_color", GameTheme.MUTED)
	content.add_child(details)
	var describe := func():
		var s: Dictionary = GraphicsSettings.settings
		var fx: PackedStringArray = []
		for key in ["ssao", "ssil", "ssr", "volumetric_fog", "glow", "taa"]:
			if s.get(key, false):
				fx.append(key.to_upper().replace("_", " "))
		details.text = "Render scale %d%%  •  shadows %s (%dm)  •  vegetation %d%%  •  water %s\nEffects: %s%s" % [
			int(float(s.render_scale) * 100.0), "off" if not s.shadows else str(s.shadow_atlas), int(s.shadow_distance),
			int(float(s.vegetation_density) * 100.0), ["low", "medium", "high"][int(s.water_quality)],
			", ".join(fx) if fx.size() > 0 else "none",
			"" if GraphicsSettings.is_forward_plus() else "\n(Compatibility renderer: screen-space effects unavailable)"]
	describe.call()
	graphics.item_selected.connect(func(index):
		GraphicsSettings.apply_quality(index)
		describe.call())
	return graphics

func _save_settings(volume: float, fullscreen: bool) -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("audio", "master_volume", volume)
	settings.set_value("display", "fullscreen", fullscreen)
	settings.save("user://settings.cfg")

func _on_credits_pressed() -> void:
	_last_opener = btn_credits
	var content := _make_panel("Credits")
	content.add_theme_constant_override("separation", 6)
	content.add_child(GameTheme.caption("ECHOES BENEATH", GameTheme.FS_H2, GameTheme.TEXT))
	content.add_child(GameTheme.caption("An original archaeological adventure", GameTheme.FS_BODY))
	for pair in [["ENGINE", "Built with Godot Engine"], ["3D ASSET PRODUCTION", "Tripo3D"], ["VOICE AND SOUND", "ElevenLabs"]]:
		var gap := Control.new()
		gap.custom_minimum_size.y = 16
		content.add_child(gap)
		content.add_child(GameTheme.caption(pair[0], GameTheme.FS_SMALL, GameTheme.ACCENT))
		var line := Label.new()
		line.text = pair[1]
		content.add_child(line)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	content.add_child(GameTheme.caption("Development build — production and QA in progress"))
