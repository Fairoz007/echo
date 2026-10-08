extends CanvasLayer

var panel: Control
var title: Label
var status: Label
var resume: Button
var save: Button
var restart: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	panel = ColorRect.new()
	panel.color = Color(0.015, 0.025, 0.035, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = preload("res://ui/GameTheme.gd").get_theme()
	add_child(panel)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(400, 0)
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	title = Label.new()
	title.add_theme_color_override("font_color", preload("res://ui/GameTheme.gd").ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)
	resume = _button(column, "Resume", close_menu)
	save = _button(column, "Save game", _save)
	restart = _button(column, "Restart checkpoint", _restart)
	_button(column, "Main menu", _main_menu)
	# Built deferred: GraphicsSettings autoload is added after GameManager (which owns this menu).
	(func(): preload("res://ui/MainMenu.gd").add_graphics_controls(column)).call_deferred()
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	panel.hide()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 50
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func show_menu(dead: bool = false) -> void:
	title.text = "Mara has fallen" if dead else "Paused"
	resume.visible = not dead
	save.visible = not dead
	status.text = "Restart from the last checkpoint." if dead else "F5 saves • F9 loads • Escape resumes"
	panel.show()
	(restart if dead else resume).grab_focus()

func close_menu() -> void:
	panel.hide()
	GameManager.change_state(GameManager.GameState.GAMEPLAY)

func _save() -> void:
	status.text = "Game saved." if SaveManager.manual_save() else "Wait for movement and mechanisms to settle."

func _restart() -> void:
	panel.hide()
	GameManager.restart_checkpoint()

func _main_menu() -> void:
	panel.hide()
	GameManager.return_to_menu()
