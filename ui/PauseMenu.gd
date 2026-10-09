extends CanvasLayer

## Pause / death screen. Public API (panel, title, status, resume, save, restart, show_menu,
## close_menu, _restart) is used by GameManager and the QA scripts.
const GameTheme := preload("res://ui/GameTheme.gd")

var panel: Control
var title: Label
var status: Label
var resume: Button
var save: Button
var restart: Button
var _kicker: Label
var _card: PanelContainer
var _tabs: TabContainer
var _settings_built := false
var _controls_tab: VBoxContainer
var _controls_screen: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	panel = ColorRect.new()
	panel.color = Color(0.012, 0.018, 0.016, 0.82)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = GameTheme.get_theme()
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	_card = PanelContainer.new()
	center.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	_card.add_child(row)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(340, 0)
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)
	_kicker = GameTheme.caption("ECHOES BENEATH", GameTheme.FS_SMALL, GameTheme.ECHO)
	column.add_child(_kicker)
	title = Label.new()
	title.add_theme_color_override("font_color", GameTheme.ACCENT)
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	column.add_child(GameTheme.rule())
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	column.add_child(gap)
	resume = _button(column, "Resume", close_menu)
	save = _button(column, "Save game", _save)
	restart = _button(column, "Restart checkpoint", _restart)
	_button(column, "Main menu", _main_menu)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(fill)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 340
	status.add_theme_font_size_override("font_size", GameTheme.FS_SMALL)
	status.add_theme_color_override("font_color", GameTheme.MUTED)
	column.add_child(status)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(500, 420)
	row.add_child(_tabs)
	# Built deferred: GraphicsSettings autoload is added after GameManager (which owns this menu).
	(func():
		var gfx := VBoxContainer.new()
		gfx.name = "Graphics"
		gfx.add_theme_constant_override("separation", 14)
		_tabs.add_child(gfx)
		preload("res://ui/MainMenu.gd").add_graphics_controls(gfx)
		var controls := VBoxContainer.new()
		controls.name = "Controls"
		controls.add_theme_constant_override("separation", 6)
		_tabs.add_child(controls)
		_controls_tab = controls
		_build_controls_tab()
		GameTheme.wire_sounds(panel)
		_settings_built = true).call_deferred()
	panel.hide()

# Controls tab: live summary of the current bindings plus the full customization screen.
func _build_controls_tab() -> void:
	for c in _controls_tab.get_children():
		c.queue_free()
	var customize := _button(_controls_tab, "Customize controls…", _open_controls)
	customize.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	_controls_tab.add_child(gap)
	var remap := get_node_or_null("/root/InputRemap")
	var rows := [["move_forward", "Move"], ["sprint", "Sprint"], ["jump", "Jump / ascend"], ["crouch", "Crouch / dive"], ["interact", "Interact"], ["flashlight", "Flashlight"], ["journal", "Field journal"]]
	for pair in rows:
		var key := "?"
		if remap:
			key = remap.event_label(remap.get_event(pair[0], remap.SLOT_KBM))
			if pair[0] == "move_forward":
				key = "/".join(["move_forward", "move_left", "move_back", "move_right"].map(func(a): return remap.event_label(remap.get_event(a, remap.SLOT_KBM))))
		_controls_tab.add_child(_key_row(key, pair[1]))
	_controls_tab.add_child(_key_row("F5 / F9", "Quick save / load"))
	GameTheme.wire_sounds(_controls_tab)

func _open_controls() -> void:
	if is_instance_valid(_controls_screen):
		return
	_controls_screen = preload("res://ui/controls/ControlsMenu.gd").open(self)
	_controls_screen.closed.connect(func():
		_build_controls_tab()
		(func(): if _controls_tab.get_child_count() > 0: _controls_tab.get_child(0).grab_focus()).call_deferred())

func _key_row(key: String, action: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size.x = 92
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_size_override("font_size", GameTheme.FS_SMALL)
	k.add_theme_stylebox_override("normal", GameTheme.box(Color(1, 1, 1, 0.07), Color(GameTheme.ACCENT, 0.5), 1, 5, 4))
	r.add_child(k)
	var a := Label.new()
	a.text = action
	r.add_child(a)
	return r

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func show_menu(dead: bool = false) -> void:
	title.text = "Mara has fallen" if dead else "Paused"
	title.add_theme_color_override("font_color", GameTheme.DANGER if dead else GameTheme.ACCENT)
	_kicker.text = "THE MOUNTAIN TAKES ITS TOLL" if dead else "ECHOES BENEATH"
	panel.color = Color(0.06, 0.012, 0.01, 0.86) if dead else Color(0.012, 0.018, 0.016, 0.82)
	resume.visible = not dead
	save.visible = not dead
	_tabs.visible = not dead
	status.text = "Restart from the last checkpoint." if dead else "F5 saves  •  F9 loads  •  Esc resumes"
	panel.show()
	_set_hud_visible(false)
	GameTheme.fade_in(panel, Vector2.ZERO, 0.18)
	GameTheme.play_ui("open")
	(restart if dead else resume).grab_focus()

func close_menu() -> void:
	if is_instance_valid(_controls_screen):
		_controls_screen.close()
	panel.hide()
	_set_hud_visible(true)
	GameManager.change_state(GameManager.GameState.GAMEPLAY)

func _save() -> void:
	status.text = "Game saved." if SaveManager.manual_save() else "Wait for movement and mechanisms to settle."

func _restart() -> void:
	panel.hide()
	GameManager.restart_checkpoint()

func _main_menu() -> void:
	panel.hide()
	GameManager.return_to_menu()

func _set_hud_visible(on: bool) -> void:
	var scene := get_tree().current_scene
	var hud = scene.get_node_or_null("HUD") if scene else null
	if hud is CanvasLayer:
		hud.visible = on
