extends CanvasLayer
## Full-screen world map (M / D-pad Right). Pauses gameplay while open, so no movement/firing
## can leak through; restores pause + mouse capture on close.
## Mouse: wheel zoom (about cursor), drag pan, right-click / double-click place waypoint.
## Keys: F centre on Mara, X clear waypoint, Q/E cycle layer, R mini-map rotation, N nav indicator.
## Gamepad: left stick moves the cursor, right stick pans, LT/RT zoom, A waypoint, Y clear,
## LB/RB layer, B / D-pad Right close. No fast travel (not a supported feature).
class_name WorldMap

const GameTheme := preload("res://ui/GameTheme.gd")
const MIN_ZOOM := 0.25
const MAX_ZOOM := 8.0
const LEGEND := [["objective", "Objective"], ["waypoint", "Waypoint"], ["tomb", "Optional tomb"], ["landmark", "Landmark"],
	["exit", "Route onward"], ["cave", "Cave entrance"], ["connection", "Stairs / ladder"], ["enemy", "Hostile (alerted)"], ["collectible", "Relic (Resource Awareness)"]]

var view: MapView
var _root: Control
var _cursor := Vector2.ZERO ## screen-space gamepad/keyboard cursor
var _dragging := false
var _drag_moved := 0.0
var _was_paused := false
var _layer_kind := "" ## "" = auto
var _layer_buttons := {}
var _region_list: VBoxContainer
var _info: Label
var _hint: Label
var _status: Label
var _legend_box: VBoxContainer
var _target_zoom := 2.0
var _pad_used := false
var _layer_box: VBoxContainer

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameTheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.028, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_map_mouse)
	_root.add_child(bg)
	view = MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.show_labels = true
	_root.add_child(view)
	var vign := Control.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vign.draw.connect(func(): _draw_frame(vign))
	_root.add_child(vign)
	_root.resized.connect(func(): vign.queue_redraw())

	# Header.
	var title := Label.new()
	title.text = "EXPEDITION ATLAS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", MapView.GOLD)
	title.position = Vector2(48, 30)
	_root.add_child(title)
	_status = Label.new()
	_status.position = Vector2(50, 72)
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	_root.add_child(_status)

	# Left column: regions (fast navigation) + layers.
	var left := _panel(Vector2(40, 110), Vector2(290, 0))
	left.anchor_bottom = 1.0
	left.offset_bottom = -80
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	left.add_child(lv)
	lv.add_child(_kicker("REGIONS"))
	_region_list = VBoxContainer.new()
	_region_list.add_theme_constant_override("separation", 0)
	lv.add_child(_region_list)
	lv.add_child(HSeparator.new())
	lv.add_child(_kicker("MAP LAYER"))
	var auto := _flat_button("Auto (Mara's level)")
	auto.pressed.connect(func(): _set_kind(""))
	lv.add_child(auto)
	_layer_buttons[""] = auto
	_layer_box = lv

	# Right column: legend with filters + waypoint info.
	var right := _panel(Vector2(0, 110), Vector2(270, 0))
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -310
	right.offset_right = -40
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	right.add_child(rv)
	rv.add_child(_kicker("LEGEND"))
	_legend_box = VBoxContainer.new()
	rv.add_child(_legend_box)
	for entry in LEGEND:
		var row := HBoxContainer.new()
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(26, 24)
		var t: String = entry[0]
		icon.draw.connect(func(): MapView.draw_icon(icon, t, Vector2(13, 12), 0.85))
		row.add_child(icon)
		var cb := CheckBox.new()
		cb.text = entry[1]
		cb.button_pressed = true
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 14)
		cb.toggled.connect(func(on: bool): view.hidden_types[t] = not on)
		row.add_child(cb)
		_legend_box.add_child(row)
	rv.add_child(HSeparator.new())
	rv.add_child(_kicker("WAYPOINT"))
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(240, 0)
	_info.add_theme_font_size_override("font_size", 14)
	rv.add_child(_info)

	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = 48
	_hint.offset_top = -64
	_hint.offset_bottom = -30
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.80, 0.77, 0.70, 0.9))
	_root.add_child(_hint)

func _panel(pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = min_size
	var sb := GameTheme.box(Color(0.03, 0.035, 0.033, 0.82), Color(MapView.GOLD, 0.35), 1, 6, 14)
	p.add_theme_stylebox_override("panel", sb)
	_root.add_child(p)
	return p

func _kicker(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", MapView.GOLD)
	return l

func _flat_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(0, 21)
	var tight := StyleBoxEmpty.new()
	tight.content_margin_top = 1
	tight.content_margin_bottom = 1
	tight.content_margin_left = 6
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, tight)
	b.add_theme_color_override("font_hover_color", MapView.GOLD)
	return b

func _draw_frame(c: Control) -> void:
	var r := Rect2(Vector2(20, 20), c.size - Vector2(40, 40))
	c.draw_rect(r, Color(MapView.GOLD, 0.35), false, 1.0)
	# Scale bar (bottom-right): the largest round distance that fits in ~160 px.
	var metres := 10.0
	for m in [10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0]:
		if m * view.zoom <= 170.0:
			metres = m
	var px := metres * view.zoom
	var o := Vector2(c.size.x - 60.0 - px, c.size.y - 48.0)
	c.draw_line(o, o + Vector2(px, 0), MapView.GOLD, 2.0)
	c.draw_line(o, o - Vector2(0, 6), MapView.GOLD, 2.0)
	c.draw_line(o + Vector2(px, 0), o + Vector2(px, -6), MapView.GOLD, 2.0)
	c.draw_string(c.get_theme_default_font(), o + Vector2(0, -10), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.86, 0.76))
	if _pad_used:
		var p := _cursor
		c.draw_arc(p, 14, 0, TAU, 32, Color(MapView.GOLD, 0.9), 1.5)
		c.draw_line(p - Vector2(22, 0), p - Vector2(8, 0), Color(MapView.GOLD, 0.9), 1.5)
		c.draw_line(p + Vector2(8, 0), p + Vector2(22, 0), Color(MapView.GOLD, 0.9), 1.5)
		c.draw_line(p - Vector2(0, 22), p - Vector2(0, 8), Color(MapView.GOLD, 0.9), 1.5)
		c.draw_line(p + Vector2(0, 8), p + Vector2(0, 22), Color(MapView.GOLD, 0.9), 1.5)

# ------------------------------------------------------------------ open / close

func is_open() -> bool:
	return visible

func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_set_hud_visible(false)
	_rebuild_regions()
	if _layer_buttons.size() <= 1:
		_build_layer_buttons()
	view.size = _root.size
	_cursor = _root.size * 0.5
	if WorldMapManager.current_region_id() != "":
		view.center = WorldMapManager.player_map_pos()
	_target_zoom = 2.2
	view.zoom = 1.4
	_set_kind(_layer_kind)
	GameTheme.play_ui("open")
	GameTheme.fade_in(_root, Vector2.ZERO, 0.18)

func close() -> void:
	visible = false
	_dragging = false
	_set_hud_visible(true)
	GameTheme.play_ui("back")
	get_tree().paused = _was_paused
	if GameManager.current_state == GameManager.GameState.GAMEPLAY and not _was_paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Clear any action latched while the map had the input (prevents firing/moving on close).
	for a in ["fire", "aim", "jump", "interact", "melee", "reload"]:
		Input.action_release(a)

func _set_hud_visible(on: bool) -> void:
	var scene := get_tree().current_scene
	var hud = scene.get_node_or_null("HUD") if scene else null
	if hud is CanvasLayer:
		hud.visible = on

func _build_layer_buttons() -> void:
	for k in WorldMapManager.layer_kinds:
		var b := _flat_button(str(k["name"]))
		var kid: String = k["id"]
		b.pressed.connect(func(): _set_kind(kid))
		_layer_box.add_child(b)
		_layer_buttons[kid] = b


func _rebuild_regions() -> void:
	for c in _region_list.get_children():
		c.queue_free()
	var cur := WorldMapManager.current_region_id()
	for reg in WorldMapManager.regions:
		var rid: String = reg["id"]
		var known := WorldMapManager.discovered_regions.has(rid)
		var b := _flat_button(("▸ " if rid == cur else "   ") + (str(reg["name"]) if known else "Uncharted"))
		b.disabled = not known
		if known:
			var pct := int(round(WorldMapManager.revealed_fraction(rid) * 100.0))
			b.tooltip_text = "%d%% surveyed" % pct
			b.pressed.connect(func(): _focus_region(rid))
		_region_list.add_child(b)

func _focus_region(rid: String) -> void:
	var rect := WorldMapManager.region_rect(rid)
	view.center = rect.get_center()
	_target_zoom = clampf(minf(view.size.x / rect.size.x, view.size.y / rect.size.y) * 0.75, MIN_ZOOM, MAX_ZOOM)

func _set_kind(kind: String) -> void:
	_layer_kind = kind
	view.kind_filter = kind
	view.selected_layer.clear()
	if kind != "":
		# Show, per region, the layer of that kind where one exists.
		for reg in WorldMapManager.regions:
			for l in reg["layers"]:
				if str(l.get("kind", reg.get("kind", ""))) == kind:
					view.selected_layer[reg["id"]] = l["id"]
	for k in _layer_buttons:
		(_layer_buttons[k] as Button).add_theme_color_override("font_color", MapView.GOLD if k == kind else Color(0.85, 0.82, 0.74))

func _cycle_kind(dir: int) -> void:
	var ids: Array = [""]
	for k in WorldMapManager.layer_kinds:
		ids.append(k["id"])
	_set_kind(ids[wrapi(ids.find(_layer_kind) + dir, 0, ids.size())])

# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("map") and GameManager.current_state == GameManager.GameState.GAMEPLAY and not get_tree().paused:
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path.begins_with("res://levels/") and get_tree().get_first_node_in_group("player") and WorldMapManager.current_region_id() != "":
				open()
				get_viewport().set_input_as_handled()
		return
	# While open the map owns keyboard/gamepad input (gameplay is paused as well). Mouse events
	# go to the GUI: panels first, then the map background (`_map_mouse`).
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("map") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close()
		return
	if event is InputEventMouse:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_F:
				view.center = WorldMapManager.player_map_pos()
			KEY_X, KEY_DELETE:
				WorldMapManager.clear_waypoint()
			KEY_Q:
				_cycle_kind(-1)
			KEY_E:
				_cycle_kind(1)
			KEY_R:
				WorldMapManager.minimap_rotates = not WorldMapManager.minimap_rotates
				WorldMapManager.save_settings()
			KEY_N:
				WorldMapManager.nav_indicator = not WorldMapManager.nav_indicator
				WorldMapManager.save_settings()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_place(_cursor if _pad_used else view.size * 0.5)
			KEY_EQUAL, KEY_KP_ADD:
				_target_zoom = clampf(_target_zoom * 1.25, MIN_ZOOM, MAX_ZOOM)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_target_zoom = clampf(_target_zoom / 1.25, MIN_ZOOM, MAX_ZOOM)
	elif event is InputEventJoypadButton and event.pressed:
		_pad_used = true
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_place(_cursor)
			JOY_BUTTON_Y:
				WorldMapManager.clear_waypoint()
			JOY_BUTTON_LEFT_SHOULDER:
				_cycle_kind(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_cycle_kind(1)
			JOY_BUTTON_X:
				view.center = WorldMapManager.player_map_pos()
			JOY_BUTTON_LEFT_STICK:
				WorldMapManager.minimap_rotates = not WorldMapManager.minimap_rotates
				WorldMapManager.save_settings()

func _map_mouse(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_pad_used = false
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				_place(mb.position)
			_dragging = mb.pressed
			_drag_moved = 0.0
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_place(mb.position)
	elif event is InputEventMouseMotion:
		if _dragging:
			var mm := event as InputEventMouseMotion
			_drag_moved += mm.relative.length()
			view.center -= mm.relative.rotated(view.view_rotation) / view.zoom

func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := view.screen_to_map(screen)
	view.zoom = clampf(view.zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_target_zoom = view.zoom
	var after := view.screen_to_map(screen)
	view.center += before - after

func _place(screen: Vector2) -> void:
	if WorldMapManager.set_waypoint_map(view.screen_to_map(screen)):
		GameTheme.play_ui("select")

func _process(delta: float) -> void:
	if not visible:
		return
	view.size = _root.size
	# Gamepad: left stick cursor, right stick pan, triggers zoom (device 0 / any).
	var ls := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var lt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	if ls.length() > 0.2:
		_pad_used = true
		_cursor += ls * 650.0 * delta
		var margin := 80.0
		var push := Vector2.ZERO
		if _cursor.x < margin: push.x = _cursor.x - margin
		if _cursor.x > view.size.x - margin: push.x = _cursor.x - (view.size.x - margin)
		if _cursor.y < margin: push.y = _cursor.y - margin
		if _cursor.y > view.size.y - margin: push.y = _cursor.y - (view.size.y - margin)
		view.center += push * delta * 6.0 / view.zoom
		_cursor = _cursor.clamp(Vector2(margin, margin), view.size - Vector2(margin, margin))
	if rs.length() > 0.2:
		_pad_used = true
		view.center += rs * 500.0 * delta / view.zoom
	if rt > 0.2 or lt > 0.2:
		_pad_used = true
		_target_zoom = clampf(_target_zoom * pow(1.8, (rt - lt) * delta * 2.0), MIN_ZOOM, MAX_ZOOM)
	# Keyboard pan (WASD / arrows).
	var kp := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if kp != Vector2.ZERO:
		view.center += kp * 450.0 * delta / view.zoom
	var wr := WorldMapManager.world_rect().grow(150)
	view.center = view.center.clamp(wr.position, wr.end)
	if not is_equal_approx(view.zoom, _target_zoom):
		var pivot := _cursor if _pad_used else view.size * 0.5
		_zoom_at(pivot, pow(_target_zoom / view.zoom, minf(1.0, delta * 10.0)))
		_target_zoom = clampf(_target_zoom, MIN_ZOOM, MAX_ZOOM)
	view.markers = WorldMapManager.get_markers()
	var me := WorldMapManager.player_map_pos()
	view.markers.append({"type": "_player", "map": me, "region": WorldMapManager.current_region_id(), "layer": "", "label": ""})
	view.refresh()
	_update_text()
	_root.get_child(2).queue_redraw()

func _update_text() -> void:
	var rid := WorldMapManager.current_region_id()
	var reg: Dictionary = WorldMapManager.by_id.get(rid, {})
	var layer := WorldMapManager.layer_info(rid, WorldMapManager.player_layer())
	var s := "Mara — " + str(reg.get("name", "?"))
	if reg.get("layers", []).size() > 1:
		s += " · " + str(layer.get("name", ""))
	s += "   |   %d%% surveyed   |   Mini-map: %s   |   Nav indicator: %s" % [int(WorldMapManager.revealed_fraction(rid) * 100.0), "rotating" if WorldMapManager.minimap_rotates else "north-up", "on" if WorldMapManager.nav_indicator else "off"]
	_status.text = s
	var wi := WorldMapManager.waypoint_info()
	if wi.is_empty():
		_info.text = "None set. Right-click (or A) on the map to place one."
	elif wi["same_region"]:
		_info.text = "%d m from Mara%s" % [int(wi["distance"]), ("\n" + str(wi["hint"])) if wi["hint"] != "" else ""]
	else:
		_info.text = str(wi["hint"]) + "\nNot reachable from here on foot — follow the campaign route."
	var pad := Input.get_connected_joypads().size() > 0
	_hint.text = ("[L-stick] Cursor  [R-stick] Pan  [LT/RT] Zoom  [A] Waypoint  [Y] Clear  [X] Centre on Mara  [LB/RB] Layer  [L3] Mini-map rotation  [B] Close" if pad else
		"[Drag] Pan  [Wheel] Zoom  [Right-click] Waypoint  [X] Clear  [F] Centre on Mara  [Q/E] Layer  [R] Mini-map rotation  [N] Nav indicator  [M / Esc] Close")
