extends Control

## "Customize Mara" screen: 3D preview in a SubViewport (orbit + zoom, idle loop),
## category tabs with swatches and sliders, Randomize / Reset / Save / Back.
## Keyboard: arrows/Tab navigate, Enter selects, Q/E orbit, R/F zoom, PgUp/PgDn switch tab, Esc back.
## Gamepad: D-pad/left stick navigate, A select, right stick orbit/zoom, LB/RB switch tab, B back.

const GameTheme := preload("res://ui/GameTheme.gd")
const MARA_SCENE := "res://assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb"
const MENU_SCENE := "res://ui/MainMenu.tscn"

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D
var _model: Node3D
var _tabs: TabContainer
var _status: Label
var _yaw := 0.35
var _pitch := -0.08
var _dist := 2.3
var _target_dist := 2.3
var _dragging := false
var _dirty := false
var _refreshers: Array[Callable] = []

func _ready() -> void:
	theme = load("res://ui/theme/echoes_theme.tres") as Theme
	if theme == null:
		theme = GameTheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_build_preview(root)
	_build_panel(root)
	MaraAppearance.profile_changed.connect(_on_profile_changed)
	GameTheme.wire_sounds(self)
	(func(): _tabs.get_tab_bar().grab_focus()).call_deferred()

# ---------------------------------------------------------------- preview

func _build_preview(parent: Control) -> void:
	var holder := SubViewportContainer.new()
	holder.name = "Preview"
	holder.stretch = true
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_stretch_ratio = 1.25
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(_on_preview_input)
	parent.add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED if _low() else Viewport.MSAA_2X
	_viewport.positional_shadow_atlas_size = 0 if _low() else 2048
	holder.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.6)
	env.ambient_light_energy = 0.55 if _low() else 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-38), deg_to_rad(35), 0)
	key.light_energy = 1.35
	key.light_color = Color(1.0, 0.94, 0.84)
	key.shadow_enabled = not _low()
	key.directional_shadow_max_distance = 6.0
	_viewport.add_child(key)
	if not _low():
		var rim := DirectionalLight3D.new()
		rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(200), 0)
		rim.light_energy = 0.6
		rim.light_color = Color(0.55, 0.8, 0.9)
		_viewport.add_child(rim)

	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.95
	disc.height = 0.04
	disc.radial_segments = 40
	floor_mesh.mesh = disc
	floor_mesh.position.y = -0.02
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.15, 0.13)
	fm.roughness = 0.95
	floor_mesh.material_override = fm
	_viewport.add_child(floor_mesh)

	var stage := Node3D.new()
	stage.name = "Stage"
	stage.add_to_group("mara_preview")
	_viewport.add_child(stage)
	var packed := load(MARA_SCENE) as PackedScene
	if packed:
		_model = packed.instantiate() as Node3D
		_model.scale = Vector3.ONE * 1.70  # GLB is 1 unit tall; game normalises to 1.70 m
		_model.rotation.y = -PI * 0.5      # Mara faces +X: turn her toward the camera (+Z)
		stage.add_child(_model)
		var ap := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.0, 0)
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.current = true
	_pivot.add_child(_camera)
	_update_camera()

	var hint := GameTheme.caption("Drag / Q E / right stick: rotate     Wheel / R F: zoom")
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = 24
	hint.offset_top = -44
	hint.offset_bottom = -16
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child.call_deferred(hint)

func _low() -> bool:
	return GraphicsSettings.quality_level <= 1

func _update_camera() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_camera.position = Vector3(0, 0, _dist)
	# Look a little lower when far, at the face when close.
	_pivot.position.y = lerpf(1.45, 0.95, inverse_lerp(0.9, 3.2, _dist))

func _process(delta: float) -> void:
	var orbit := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var zoom := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(orbit) < 0.2: orbit = 0.0
	if absf(zoom) < 0.2: zoom = 0.0
	if Input.is_physical_key_pressed(KEY_Q): orbit -= 1.0
	if Input.is_physical_key_pressed(KEY_E): orbit += 1.0
	if Input.is_physical_key_pressed(KEY_R): zoom -= 1.0
	if Input.is_physical_key_pressed(KEY_F): zoom += 1.0
	_yaw += orbit * delta * 2.2
	_target_dist = clampf(_target_dist + zoom * delta * 1.8, 0.9, 3.2)
	_dist = lerpf(_dist, _target_dist, 1.0 - exp(-delta * 10.0))
	_update_camera()

func _on_preview_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_dist = clampf(_target_dist - 0.15, 0.9, 3.2)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_dist = clampf(_target_dist + 0.15, 0.9, 3.2)
	elif e is InputEventMouseMotion and _dragging:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.01
		_pitch = clampf(_pitch - mm.relative.y * 0.005, -0.5, 0.3)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_tab(-1)
		elif e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_tab(1)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_PAGEUP:
			_switch_tab(-1)
		elif e.physical_keycode == KEY_PAGEDOWN:
			_switch_tab(1)

func _switch_tab(d: int) -> void:
	_tabs.current_tab = wrapi(_tabs.current_tab + d, 0, _tabs.get_tab_count())
	_tabs.get_tab_bar().grab_focus()
	GameTheme.play_ui("hover")

# ---------------------------------------------------------------- panel

func _build_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.PANEL, Color(0, 0, 0, 0), 0, 0, 36))
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(GameTheme.caption("EXPEDITION OUTFITTER", GameTheme.FS_SMALL, GameTheme.ECHO))
	col.add_child(GameTheme.heading("CUSTOMIZE MARA"))
	col.add_child(GameTheme.rule(220))

	_tabs = TabContainer.new()
	_tabs.name = "Categories"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_build_outfit_tab(_page("Outfit"))
	_build_skin_tab(_page("Skin & Hair"))
	_build_gear_tab(_page("Gear"))
	_build_body_tab(_page("Body"))

	_status = GameTheme.caption("")
	col.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for spec in [["Randomize", _randomize], ["Reset", _reset], ["Save", _save], ["Back", _back]]:
		var b := Button.new()
		b.name = "Btn" + spec[0]
		b.text = spec[0].to_upper()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 50
		b.pressed.connect(spec[1])
		row.add_child(b)
	_set_status()

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_child(page)
	scroll.add_child(margin)
	return page

func _section(page: Control, text: String) -> void:
	page.add_child(GameTheme.caption(text.to_upper(), GameTheme.FS_SMALL, GameTheme.ACCENT))

func _swatches(page: Control, colors: Array, key: String, strength_key: String, strength_on := 1.0) -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	var buttons: Array[Button] = []
	for c in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 44)
		b.toggle_mode = true
		var sb := GameTheme.box(c, Color(0, 0, 0, 0.5), 2, 6, 0)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", GameTheme.box(c.lightened(0.12), GameTheme.TEXT, 2, 6, 0))
		b.add_theme_stylebox_override("pressed", GameTheme.box(c, GameTheme.ACCENT, 4, 6, 0))
		b.add_theme_stylebox_override("hover_pressed", GameTheme.box(c.lightened(0.12), GameTheme.ACCENT, 4, 6, 0))
		b.tooltip_text = "#" + c.to_html(false)
		b.pressed.connect(func():
			MaraAppearance.profile[key] = c
			if float(MaraAppearance.profile[strength_key]) < 0.05:
				MaraAppearance.profile[strength_key] = strength_on
			MaraAppearance.set_value(strength_key, MaraAppearance.profile[strength_key]))
		grid.add_child(b)
		buttons.append(b)
	_refreshers.append(func():
		for i in buttons.size():
			buttons[i].set_pressed_no_signal(float(MaraAppearance.profile[strength_key]) > 0.05 and (MaraAppearance.profile[key] as Color).is_equal_approx(colors[i])))

func _slider(page: Control, label: String, key: String, lo: float, hi: float, fmt: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 170
	row.add_child(l)
	var s := HSlider.new()
	s.name = "Slider_" + key
	s.min_value = lo
	s.max_value = hi
	s.step = 0.005
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size.x = 84
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", GameTheme.ACCENT)
	row.add_child(v)
	page.add_child(row)
	s.value = float(MaraAppearance.profile[key])
	v.text = fmt.call(s.value)
	s.value_changed.connect(func(x):
		v.text = fmt.call(x)
		MaraAppearance.set_value(key, x))
	_refreshers.append(func():
		s.set_value_no_signal(float(MaraAppearance.profile[key]))
		v.text = fmt.call(s.value))

var _pct := func(x): return "%d%%" % int(round(x * 100.0))

func _build_outfit_tab(page: VBoxContainer) -> void:
	_section(page, "Palette presets")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	var preset_buttons := {}
	for p in MaraAppearance.OUTFIT_PRESETS:
		var b := Button.new()
		b.text = p
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip := ColorRect.new()
		chip.color = MaraAppearance.OUTFIT_PRESETS[p][0]
		chip.custom_minimum_size = Vector2(8, 0)
		chip.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		chip.offset_right = 8
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chip)
		b.pressed.connect(func(): MaraAppearance.set_outfit_preset(p))
		grid.add_child(b)
		preset_buttons[p] = b
	_refreshers.append(func():
		for p in preset_buttons:
			preset_buttons[p].set_pressed_no_signal(MaraAppearance.profile.outfit_preset == p))
	_section(page, "Jacket tint")
	var jackets: Array = []
	for p in MaraAppearance.OUTFIT_PRESETS:
		jackets.append(MaraAppearance.OUTFIT_PRESETS[p][0])
	_swatches(page, jackets, "outfit_primary", "outfit_strength", 0.85)
	_section(page, "Trousers and pouches")
	var trousers: Array = []
	for p in MaraAppearance.OUTFIT_PRESETS:
		trousers.append(MaraAppearance.OUTFIT_PRESETS[p][1])
	_swatches(page, trousers, "outfit_secondary", "outfit_strength", 0.85)
	_slider(page, "Tint strength", "outfit_strength", 0.0, 1.0, _pct)

func _build_skin_tab(page: VBoxContainer) -> void:
	_section(page, "Skin tone")
	_swatches(page, MaraAppearance.SKIN_TONES, "skin_tone", "skin_strength", 0.9)
	_slider(page, "Skin blend", "skin_strength", 0.0, 1.0, _pct)
	_section(page, "Hair colour")
	_swatches(page, MaraAppearance.HAIR_COLORS, "hair_color", "hair_strength", 0.9)
	_slider(page, "Hair blend", "hair_strength", 0.0, 1.0, _pct)
	page.add_child(GameTheme.caption("Hair shares Mara's single texture, so its colour is isolated by hue. Very dark leather trims may shift slightly with it."))

func _build_gear_tab(page: VBoxContainer) -> void:
	_section(page, "Accessories")
	var labels := {"hat": "Field hat", "backpack": "Expedition backpack", "satchel": "Hip satchel", "headlamp": "Headlamp"}
	for a in MaraAppearance.ACCESSORIES:
		var cb := CheckButton.new()
		cb.name = "Toggle_" + a
		cb.text = labels[a]
		cb.button_pressed = bool(MaraAppearance.profile[a])
		cb.toggled.connect(func(on): MaraAppearance.set_value(a, on))
		page.add_child(cb)
		_refreshers.append(func(): cb.set_pressed_no_signal(bool(MaraAppearance.profile[a])))
	page.add_child(GameTheme.caption("Gear follows Mara's head and spine bones in every chapter and cutscene."))

func _build_body_tab(page: VBoxContainer) -> void:
	_section(page, "Proportions")
	_slider(page, "Height", "height", MaraAppearance.HEIGHT_MIN, MaraAppearance.HEIGHT_MAX,
		func(x): return "%.2f m" % (1.70 * x))
	_slider(page, "Build", "build", MaraAppearance.BUILD_MIN, MaraAppearance.BUILD_MAX, _pct)
	page.add_child(GameTheme.caption("Limited so Mara still fits her collision capsule, ledges and the camera rig."))

# ---------------------------------------------------------------- actions

func _on_profile_changed() -> void:
	_dirty = true
	for r in _refreshers:
		r.call()
	_set_status()

func _set_status() -> void:
	if _refreshers.size() > 0 and not _dirty:
		for r in _refreshers:
			r.call()
	_status.text = "Unsaved changes" if _dirty else "Profile saved to this device"
	_status.add_theme_color_override("font_color", GameTheme.ACCENT if _dirty else GameTheme.MUTED)

func _randomize() -> void:
	MaraAppearance.randomize_profile()

func _reset() -> void:
	MaraAppearance.reset_profile()

func _save() -> void:
	MaraAppearance.save_profile()
	_dirty = false
	_set_status()
	GameTheme.play_ui("click")

func _back() -> void:
	if _dirty:
		MaraAppearance.load_profile() # discard unsaved edits
	GameTheme.play_ui("back")
	get_tree().change_scene_to_file(MENU_SCENE)
