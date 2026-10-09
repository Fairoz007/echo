extends Control

## Controls customization screen. Built in code on the shared Echoes theme.
## Open with: ControlsMenu.open(parent_node)  (returns the instance; emits `closed`).
## Works while the tree is paused. Fully keyboard / gamepad navigable:
## arrows / D-pad move focus, Enter / A rebinds, Esc / B goes back, Esc cancels a capture.

signal closed

const GameTheme := preload("res://ui/GameTheme.gd")
const SCENE := "res://ui/controls/ControlsMenu.tscn"
const CAPTURE_TIMEOUT := 6.0

var _remap: Node
var _rows := {}          # action -> {kbm: Button, pad: Button, reset: Button, name: Label}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _back: Button
var _reset_all: Button
var _option_controls := {}
var _capture := {}       # {action, slot, button, armed, time}
var _modal: Control
var _modal_text: Label
var _modal_swap: Button
var _modal_cancel: Button
var _pending := {}       # {action, event, conflict}
var _first_focus: Control

static func open(parent: Node) -> Control:
	var menu: Control = load(SCENE).instantiate()
	parent.add_child(menu)
	return menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_remap = get_node_or_null("/root/InputRemap")
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if _remap:
		_remap.bindings_changed.connect(func(_a): _refresh())
	_refresh()
	GameTheme.wire_sounds(self)
	GameTheme.fade_in(self, Vector2.ZERO, 0.16)
	(func(): if is_instance_valid(_first_focus): _first_focus.grab_focus()).call_deferred()

# ------------------------------------------------------------------ layout

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.014, 0.012, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var card := PanelContainer.new()
	margin.add_child(card)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	card.add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(GameTheme.caption("SETTINGS", GameTheme.FS_SMALL, GameTheme.ECHO))
	titles.add_child(GameTheme.heading("Controls", GameTheme.FS_H1))
	var hint := GameTheme.caption("Select a binding and press a new key or button.\nEsc cancels a capture.", GameTheme.FS_SMALL)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(hint)
	root.add_child(GameTheme.rule())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	root.add_child(body)

	# Bindings column
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.55
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var cols := _binding_row_box()
	var lead := Control.new()
	lead.custom_minimum_size.x = 0
	cols.add_child(lead)
	cols.add_child(_col_label("ACTION", 0, true))
	cols.add_child(_col_label("KEYBOARD / MOUSE", 200))
	cols.add_child(_col_label("GAMEPAD", 200))
	cols.add_child(_col_label("", 64))
	left.add_child(cols)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	left.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_child(_list)
	_scroll.add_child(pad)
	var section := ""
	if _remap:
		for entry in _remap.ACTIONS:
			if entry[2] != section:
				section = entry[2]
				var sec := GameTheme.caption(section.to_upper(), GameTheme.FS_SMALL, GameTheme.ACCENT)
				if _list.get_child_count() > 0:
					var gap := Control.new()
					gap.custom_minimum_size.y = 6
					_list.add_child(gap)
				_list.add_child(sec)
			_add_binding_row(entry[0], entry[1])

	# Options column
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	right.add_child(GameTheme.caption("CAMERA", GameTheme.FS_SMALL, GameTheme.ACCENT))
	_add_slider(right, "mouse_sensitivity", "Mouse sensitivity", 0.1, 3.0, 0.05, "%.2fx")
	_add_slider(right, "fov", "Field of view", 60, 100, 1, "%d°")
	_add_toggle(right, "invert_y", "Invert look Y")
	right.add_child(GameTheme.caption("GAMEPAD", GameTheme.FS_SMALL, GameTheme.ACCENT))
	_add_slider(right, "stick_sensitivity", "Stick sensitivity", 0.1, 3.0, 0.05, "%.2fx")
	_add_slider(right, "deadzone", "Stick deadzone", 0.05, 0.9, 0.01, "%d%%", 100.0)
	right.add_child(GameTheme.caption("HOLD OR TOGGLE", GameTheme.FS_SMALL, GameTheme.ACCENT))
	_add_toggle(right, "toggle_sprint", "Toggle sprint")
	_add_toggle(right, "toggle_crouch", "Toggle crouch")
	_add_toggle(right, "toggle_aim", "Toggle aim")

	root.add_child(GameTheme.rule())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_status = GameTheme.caption("", GameTheme.FS_SMALL)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_status)
	_reset_all = _footer_button(footer, "Reset all", _on_reset_all)
	_back = _footer_button(footer, "Back", close)
	_build_modal()

func _binding_row_box() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	return h

func _col_label(text: String, width: float, expand := false) -> Label:
	var l := GameTheme.caption(text, 13, GameTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = width
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _add_binding_row(action: String, label: String) -> void:
	var row := _binding_row_box()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var kbm := _bind_button(action, _remap.SLOT_KBM)
	var pad := _bind_button(action, _remap.SLOT_PAD)
	row.add_child(kbm)
	row.add_child(pad)
	var reset := Button.new()
	reset.text = "↺"
	reset.tooltip_text = "Reset %s to default" % label
	reset.custom_minimum_size = Vector2(44, 40)
	reset.add_theme_font_size_override("font_size", GameTheme.FS_BODY)
	reset.add_theme_constant_override("h_separation", 0)
	reset.add_theme_stylebox_override("normal", _key_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05)))
	reset.add_theme_stylebox_override("hover", _key_box(Color(GameTheme.ACCENT, 0.16), Color(GameTheme.ACCENT, 0.7)))
	reset.add_theme_stylebox_override("pressed", _key_box(Color(GameTheme.ACCENT, 0.3), GameTheme.ACCENT))
	reset.add_theme_stylebox_override("disabled", _key_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	reset.pressed.connect(func():
		_remap.reset_action(action)
		_remap.save_config()
		_set_status("%s reset to default." % label))
	row.add_child(reset)
	_list.add_child(row)
	_rows[action] = {"kbm": kbm, "pad": pad, "reset": reset, "name": name_label}
	if _first_focus == null:
		_first_focus = kbm

func _key_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := GameTheme.box(bg, border, 1, 6, 0)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _bind_button(action: String, slot: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.add_theme_font_size_override("font_size", GameTheme.FS_BODY)
	b.add_theme_stylebox_override("normal", _key_box(Color(1, 1, 1, 0.06), Color(GameTheme.ACCENT, 0.32)))
	b.add_theme_stylebox_override("hover", _key_box(Color(GameTheme.ACCENT, 0.16), Color(GameTheme.ACCENT, 0.8)))
	b.add_theme_stylebox_override("pressed", _key_box(Color(GameTheme.ECHO, 0.18), GameTheme.ECHO))
	b.add_theme_stylebox_override("hover_pressed", _key_box(Color(GameTheme.ECHO, 0.18), GameTheme.ECHO))
	b.pressed.connect(_begin_capture.bind(action, slot, b))
	return b

func _option_row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 170
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	parent.add_child(row)
	return row

func _add_slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float, fmt: String, display_scale := 1.0) -> void:
	var row := _option_row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(120, 28)
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", GameTheme.ACCENT)
	row.add_child(v)
	var update_label := func(value: float):
		v.text = fmt % (roundi(value * display_scale) if fmt.contains("%d") else value)
	s.value_changed.connect(func(value: float):
		update_label.call(value)
		if _remap and not is_equal_approx(float(_remap.get(key)), value):
			_remap.set(key, value)
			_remap.save_config())
	_option_controls[key] = [s, update_label]

func _add_toggle(parent: Control, key: String, text: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.toggled.connect(func(on: bool):
		if _remap and bool(_remap.get(key)) != on:
			_remap.set(key, on)
			_remap.save_config())
	parent.add_child(c)
	_option_controls[key] = [c, null]

func _footer_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_modal() -> void:
	_modal = ColorRect.new()
	(_modal as ColorRect).color = Color(0, 0, 0, 0.6)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 480
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(GameTheme.heading("Binding in use", GameTheme.FS_H2))
	_modal_text = Label.new()
	_modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_text.custom_minimum_size.x = 430
	v.add_child(_modal_text)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	_modal_swap = _footer_button(h, "Swap", func(): _resolve_conflict(true))
	_modal_cancel = _footer_button(h, "Cancel", func(): _resolve_conflict(false))
	_modal.hide()

# ------------------------------------------------------------------ state

func _refresh() -> void:
	if not _remap:
		return
	for action in _rows:
		var r: Dictionary = _rows[action]
		if not (_capture and _capture.button == r.kbm):
			r.kbm.text = _remap.event_label(_remap.get_event(action, _remap.SLOT_KBM))
		if not (_capture and _capture.button == r.pad):
			r.pad.text = _remap.event_label(_remap.get_event(action, _remap.SLOT_PAD))
		var dflt: bool = _remap.is_default(action)
		r.reset.disabled = dflt
		r.reset.focus_mode = Control.FOCUS_NONE if dflt else Control.FOCUS_ALL
		r.reset.modulate.a = 0.35 if dflt else 1.0
	for key in _option_controls:
		var c = _option_controls[key][0]
		if c is HSlider:
			c.set_value_no_signal(float(_remap.get(key)))
			_option_controls[key][1].call(c.value)
		elif c is CheckButton:
			c.set_pressed_no_signal(bool(_remap.get(key)))

func _set_status(text: String, warn := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", GameTheme.DANGER if warn else GameTheme.MUTED)

func _begin_capture(action: String, slot: int, button: Button) -> void:
	if _capture or _modal.visible:
		return
	_capture = {"action": action, "slot": slot, "button": button, "armed": false, "time": 0.0}
	button.text = "Press a key…" if slot == _remap.SLOT_KBM else "Press a button…"
	button.add_theme_color_override("font_color", GameTheme.ECHO)
	button.add_theme_color_override("font_focus_color", GameTheme.ECHO)
	button.add_theme_color_override("font_hover_color", GameTheme.ECHO)
	_set_status("Rebinding %s. Esc cancels." % _remap.action_label(action))
	GameTheme.play_ui("open")
	# Arm next frame so the press that opened the capture is not captured itself.
	get_tree().create_timer(0.12, true).timeout.connect(func():
		if _capture:
			_capture.armed = true)

func _end_capture(message := "", warn := false) -> void:
	if _capture:
		var b: Button = _capture.button
		for c in ["font_color", "font_focus_color", "font_hover_color"]:
			b.remove_theme_color_override(c)
		var keep_focus := b
		_capture = {}
		_refresh()
		if not _modal.visible:
			keep_focus.grab_focus()
	if message != "":
		_set_status(message, warn)

func _process(delta: float) -> void:
	if _capture and _capture.armed:
		_capture.time += delta
		var left: float = CAPTURE_TIMEOUT - float(_capture.time)
		if left <= 0.0:
			_end_capture("Rebind timed out.")
		elif _capture.slot == _remap.SLOT_PAD:
			_set_status("Press a gamepad button for %s (%ds). Esc cancels." % [_remap.action_label(_capture.action), ceili(left)])

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _capture:
		get_viewport().set_input_as_handled()
		if not _capture.armed or not event.is_pressed() or event.is_echo():
			return
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			_end_capture("Rebind cancelled.")
			return
		var slot: int = _remap._slot_of(event)
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.6:
			return
		if slot != _capture.slot:
			return
		_try_bind(_capture.action, event)
		return
	if _modal.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			_resolve_conflict(false)
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()

func _try_bind(action: String, event: InputEvent) -> void:
	var ev: InputEvent = _remap.normalize(event)
	var conflict: String = _remap.find_conflict(action, ev)
	if conflict != "":
		_pending = {"action": action, "event": ev, "conflict": conflict, "button": _capture.button}
		_end_capture()
		_modal_text.text = "%s is already bound to %s.\nSwap the two bindings, or cancel to keep things as they are." % [
			_remap.event_label(ev), _remap.action_label(conflict)]
		_set_status("Conflict: %s is used by %s." % [_remap.event_label(ev), _remap.action_label(conflict)], true)
		_modal.show()
		GameTheme.fade_in(_modal, Vector2.ZERO, 0.12)
		_modal_swap.grab_focus()
		return
	_remap.rebind(action, ev)
	_remap.save_config()
	_end_capture("%s → %s" % [_remap.action_label(action), _remap.event_label(ev)])
	GameTheme.play_ui("click")

func _resolve_conflict(swap: bool) -> void:
	_modal.hide()
	var p := _pending
	_pending = {}
	if p.is_empty():
		return
	if swap:
		_remap.rebind(p.action, p.event, -1, "swap")
		_remap.save_config()
		_set_status("Swapped %s and %s." % [_remap.action_label(p.action), _remap.action_label(p.conflict)])
	else:
		_set_status("Rebind cancelled.")
	_refresh()
	if is_instance_valid(p.get("button")):
		p.button.grab_focus()

func _on_reset_all() -> void:
	_remap.reset_all()
	_remap.save_config()
	_refresh()
	_set_status("All controls reset to defaults.")

func close() -> void:
	if _remap:
		_remap.save_config()
	GameTheme.play_ui("back")
	closed.emit()
	queue_free()
