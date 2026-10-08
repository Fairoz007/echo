extends Control

## Main Menu Controller for ECHOES BENEATH
@onready var btn_continue: Button = $VBoxContainer/BtnContinue
@onready var btn_new_game: Button = $VBoxContainer/BtnNewGame
@onready var btn_settings: Button = $VBoxContainer/BtnSettings
@onready var btn_credits: Button = $VBoxContainer/BtnCredits
@onready var btn_quit: Button = $VBoxContainer/BtnQuit

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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

func _make_panel(title: String) -> VBoxContainer:
	var popup := Window.new()
	popup.name = "MenuPanel"
	popup.title = title
	popup.size = Vector2i(600, 520)
	popup.transient = true
	popup.exclusive = true
	popup.theme = preload("res://ui/GameTheme.gd").get_theme()
	add_child(popup)
	popup.close_requested.connect(func(): popup.queue_free())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(backdrop)
	backdrop.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	var heading := preload("res://ui/GameTheme.gd").heading(title, 28)
	content.add_child(heading)
	popup.popup_centered()
	return content

func _on_settings_pressed() -> void:
	var content := _make_panel("Settings")
	var label := Label.new()
	label.text = "Master volume"
	content.add_child(label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = AudioServer.get_bus_volume_linear(0)
	volume.value_changed.connect(func(value):
		AudioServer.set_bus_volume_linear(0, value)
		_save_settings(value, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN))
	content.add_child(volume)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
		_save_settings(AudioServer.get_bus_volume_linear(0), enabled))
	content.add_child(fullscreen)
	add_graphics_controls(content)

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
	details.add_theme_font_size_override("font_size", 14)
	content.add_child(details)
	var describe := func():
		var s: Dictionary = GraphicsSettings.settings
		var fx: PackedStringArray = []
		for key in ["ssao", "ssil", "ssr", "volumetric_fog", "glow", "taa"]:
			if s.get(key, false):
				fx.append(key.to_upper().replace("_", " "))
		details.text = "Render scale %d%% • shadows %s (%dm) • vegetation %d%% • water %s\nEffects: %s%s" % [
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
	var content := _make_panel("ECHOES BENEATH")
	var credits := Label.new()
	credits.text = "An original archaeological adventure\n\nBuilt with Godot Engine\n3D asset production: Tripo3D\nVoice and sound production: ElevenLabs\n\nDevelopment build — production and QA in progress"
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(credits)
