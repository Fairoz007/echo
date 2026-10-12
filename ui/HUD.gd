extends CanvasLayer

## In-game HUD for ECHOES BENEATH.
## Compact vitals bottom-left (fade out when full and idle), objective toast top-right,
## context prompt with a key glyph, subtitles on a backing plate, contextual ammo/air readouts.
## Node paths, public vars and methods are used by Player/AudioManager/QA scripts — keep them.
const GameTheme := preload("res://ui/GameTheme.gd")
const HEALTH_COLOR := Color(0.84, 0.40, 0.32)
const STAMINA_COLOR := Color(0.62, 0.74, 0.46)
const OXYGEN_COLOR := Color(0.38, 0.86, 0.90)
const IDLE_FADE_DELAY := 3.0

@onready var health_bar: ProgressBar = $MarginContainer/VBoxVitals/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxVitals/StaminaBar
@onready var prompt_label: Label = $CenterContainer/PromptLabel
@onready var objective_label: Label = $TopRightMargin/ObjectiveLabel
@onready var subtitle_label: Label = $BottomMargin/SubtitleLabel
var subtitle_revision: int = 0
var objective_revision: int = 0
var ammo_label: Label
var oxygen_label: Label
var reticle: Label
var oxygen_bar: ProgressBar
var controls_label: Label
var _vitals: Control
var _key_glyph: Label
var _objective_kicker: Label
var _ammo_box: Control
var _vitals_active_until := 0.0
var _ammo_active_until := 0.0
var _player: Node
var minimap: Control

func _ready() -> void:
	var root_theme := GameTheme.get_theme()
	for c in get_children():
		if c is Control:
			c.theme = root_theme
	_vitals = $MarginContainer
	_style_bar(health_bar, HEALTH_COLOR)
	_style_bar(stamina_bar, STAMINA_COLOR)
	oxygen_bar = ProgressBar.new()
	oxygen_bar.name = "OxygenBar"
	oxygen_bar.custom_minimum_size = Vector2(200, 5)
	oxygen_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	oxygen_bar.show_percentage = false
	oxygen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_bar.visible = false
	_style_bar(oxygen_bar, OXYGEN_COLOR)
	$MarginContainer/VBoxVitals.add_child(oxygen_bar)
	$MarginContainer/VBoxVitals.move_child(oxygen_bar, 0)

	# Contextual readouts, top-left (anchored; no fixed screen positions).
	var top_left := VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.theme = root_theme
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_left.offset_left = 40
	top_left.offset_top = 36
	top_left.add_theme_constant_override("separation", 8)
	add_child(top_left)
	_ammo_box = top_left
	ammo_label = Label.new()
	ammo_label.add_theme_font_size_override("font_size", 18)
	ammo_label.add_theme_stylebox_override("normal", _plate(GameTheme.ACCENT))
	ammo_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_left.add_child(ammo_label)
	oxygen_label = Label.new()
	oxygen_label.add_theme_font_size_override("font_size", 18)
	oxygen_label.add_theme_color_override("font_color", OXYGEN_COLOR)
	oxygen_label.add_theme_stylebox_override("normal", _plate(OXYGEN_COLOR))
	oxygen_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_left.add_child(oxygen_label)
	controls_label = Label.new()
	controls_label.text = "WASD Move  •  Shift Sprint  •  Space Jump  •  C Crouch/Dive  •  F Light  •  E Interact  •  J Journal  •  Esc Pause"
	controls_label.add_theme_font_size_override("font_size", 15)
	controls_label.add_theme_color_override("font_color", Color(GameTheme.TEXT, 0.8))
	controls_label.add_theme_stylebox_override("normal", GameTheme.box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 6, 8))
	controls_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_left.add_child(controls_label)
	# Controls hint is onboarding only: fade out after a while (full list lives in Pause > Controls).
	var hint_tw := create_tween()
	hint_tw.tween_interval(14.0)
	hint_tw.tween_property(controls_label, "modulate:a", 0.0, 1.5)
	hint_tw.tween_callback(func(): controls_label.visible = false)

	reticle = Label.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.text = "+"
	reticle.add_theme_font_size_override("font_size", 24)
	reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	reticle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	reticle.add_theme_constant_override("outline_size", 4)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(reticle)
	_position_reticle()
	get_viewport().size_changed.connect(_position_reticle)

	# Interaction prompt: [E] key glyph + action text on a plate.
	prompt_label.add_theme_stylebox_override("normal", _prompt_plate())
	prompt_label.add_theme_color_override("font_color", GameTheme.TEXT)
	_key_glyph = Label.new()
	_key_glyph.text = "E"
	_key_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_glyph.add_theme_font_size_override("font_size", 17)
	_key_glyph.add_theme_color_override("font_color", Color(0.08, 0.09, 0.08))
	_key_glyph.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var glyph_box := GameTheme.box(GameTheme.ACCENT, Color(1, 0.92, 0.75), 1, 5, 0)
	glyph_box.content_margin_left = 9
	glyph_box.content_margin_right = 9
	_key_glyph.add_theme_stylebox_override("normal", glyph_box)
	_key_glyph.anchor_top = 0.5
	_key_glyph.anchor_bottom = 0.5
	_key_glyph.offset_left = -44
	_key_glyph.offset_right = -10
	_key_glyph.offset_top = -14
	_key_glyph.offset_bottom = 14
	_key_glyph.custom_minimum_size = Vector2(30, 28)
	prompt_label.add_child(_key_glyph)

	# Objective toast.
	var obj_plate := GameTheme.box(Color(0.03, 0.04, 0.035, 0.62), Color(0, 0, 0, 0), 0, 6, 0)
	obj_plate.border_width_left = 3
	obj_plate.border_color = GameTheme.ACCENT
	obj_plate.content_margin_left = 16
	obj_plate.content_margin_right = 16
	obj_plate.content_margin_top = 30
	obj_plate.content_margin_bottom = 12
	objective_label.add_theme_stylebox_override("normal", obj_plate)
	objective_label.add_theme_color_override("font_color", GameTheme.TEXT)
	_objective_kicker = Label.new()
	_objective_kicker.text = "OBJECTIVE"
	_objective_kicker.position = Vector2(16, 8)
	_objective_kicker.add_theme_font_size_override("font_size", 13)
	_objective_kicker.add_theme_color_override("font_color", GameTheme.ACCENT)
	objective_label.add_child(_objective_kicker)

	# Subtitles on a backing plate.
	subtitle_label.add_theme_stylebox_override("normal", GameTheme.box(Color(0.02, 0.025, 0.022, 0.72), Color(0, 0, 0, 0), 0, 8, 0))
	(subtitle_label.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left = 22
	(subtitle_label.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_right = 22
	(subtitle_label.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_top = 10
	(subtitle_label.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_bottom = 10

	# Mini-map top-right; the objective toast sits to its left so neither covers the other.
	minimap = preload("res://ui/map/MiniMap.gd").new()
	minimap.name = "MiniMap"
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -40.0 - MiniMap.DIAMETER
	minimap.offset_right = -40.0
	minimap.offset_top = 30.0
	minimap.offset_bottom = 30.0 + MiniMap.DIAMETER + 70.0
	minimap.theme = root_theme
	add_child(minimap)
	minimap.attach_nav_overlay(self)
	move_child(minimap.get_parent().get_node("NavIndicator"), 0)
	$TopRightMargin.add_theme_constant_override("margin_right", 40 + int(MiniMap.DIAMETER) + 22)
	$TopRightMargin.offset_left -= MiniMap.DIAMETER + 22.0

	prompt_label.visible = false
	subtitle_label.visible = false
	_set_objective_text(objective_label.text.trim_prefix("OBJECTIVE: "), false)
	_wake_vitals()
	if MissionManager:
		MissionManager.objective_updated.connect(_on_objective_updated)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		bind_player(player)

func _style_bar(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_stylebox_override("fill", GameTheme.box(color, Color(0, 0, 0, 0), 0, 3, 0))
	bar.add_theme_stylebox_override("background", GameTheme.box(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.1), 1, 3, 0))

func _plate(accent: Color) -> StyleBoxFlat:
	var s := GameTheme.box(Color(0.03, 0.04, 0.035, 0.6), Color(0, 0, 0, 0), 0, 6, 0)
	s.border_width_left = 3
	s.border_color = accent
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _prompt_plate() -> StyleBoxFlat:
	var s := GameTheme.box(Color(0.03, 0.04, 0.035, 0.75), Color(GameTheme.ACCENT, 0.4), 1, 8, 0)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s

## Autowrapping labels inside shrink containers need an explicit width: fit to text, capped.
func _fit_label(label: Label, max_width: float) -> void:
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var sb := label.get_theme_stylebox("normal")
	var pad := sb.get_minimum_size().x if sb else 0.0
	var w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad + 4.0
	label.custom_minimum_size.x = minf(w, max_width)

func _position_reticle() -> void:
	if is_instance_valid(reticle):
		reticle.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(8, 16)

func _ammo_text(loaded, reserve) -> String:
	return "SIDEARM   %d / %d      R Reload   Q Melee" % [loaded, reserve]

func bind_player(player: Node) -> void:
	_player = player
	if player.has_signal("ammunition_changed"):
		player.ammunition_changed.connect(func(loaded, reserve):
			ammo_label.text = _ammo_text(loaded, reserve)
			_ammo_active_until = _now() + 4.0)
		ammo_label.text = _ammo_text(player.ammunition, player.reserve_ammunition)
	else:
		ammo_label.visible = false
	if player.has_signal("oxygen_changed"):
		player.oxygen_changed.connect(func(value, maximum):
			oxygen_label.text = "AIR  %ds      Space Ascend  •  C Dive" % int(value)
			oxygen_label.visible = value < maximum
			oxygen_bar.max_value = maximum
			oxygen_bar.value = value
			oxygen_bar.visible = value < maximum
			_wake_vitals())
	oxygen_label.visible = false
	if player.has_signal("health_changed"):
		player.health_changed.connect(update_health)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(update_stamina)
	if player.has_signal("interactable_detected"):
		player.interactable_detected.connect(show_prompt)
	if player.has_signal("interactable_lost"):
		player.interactable_lost.connect(hide_prompt)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _wake_vitals() -> void:
	_vitals_active_until = _now() + IDLE_FADE_DELAY

func update_health(val: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = val
	_wake_vitals()

func update_stamina(val: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = val
	if val < max_val:
		_wake_vitals()

func show_prompt(text: String) -> void:
	var key := "E"
	var body := text.strip_edges()
	if body.begins_with("[") and body.find("]") > 0 and body.find("]") <= 8:
		key = body.substr(1, body.find("]") - 1)
		body = body.substr(body.find("]") + 1).strip_edges()
	_key_glyph.text = key
	prompt_label.text = body
	if not prompt_label.visible:
		prompt_label.visible = true
		prompt_label.modulate.a = 0.0
		create_tween().tween_property(prompt_label, "modulate:a", 1.0, 0.15)

func hide_prompt() -> void:
	prompt_label.visible = false

func show_subtitle(speaker: String, line: String, duration: float = 3.5) -> void:
	if not is_inside_tree():
		return
	subtitle_revision += 1
	var revision = subtitle_revision
	subtitle_label.text = "%s:  %s" % [speaker, line] if not speaker.is_empty() else line
	_fit_label(subtitle_label, maxf(320.0, $BottomMargin.size.x))
	if not subtitle_label.visible:
		subtitle_label.modulate.a = 0.0
		create_tween().tween_property(subtitle_label, "modulate:a", 1.0, 0.18)
	subtitle_label.visible = true
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if revision == subtitle_revision:
			subtitle_label.visible = false)

func _set_objective_text(desc: String, completed: bool) -> void:
	objective_label.text = desc
	objective_label.visible = not desc.is_empty()
	_objective_kicker.text = "OBJECTIVE COMPLETE" if completed else "OBJECTIVE"
	_objective_kicker.add_theme_color_override("font_color", GameTheme.ECHO if completed else GameTheme.ACCENT)
	_fit_label(objective_label, 420.0)

func _on_objective_updated(id: String, desc: String, is_comp: bool) -> void:
	objective_revision += 1
	var revision = objective_revision
	_set_objective_text(desc, is_comp)
	# Toast: slide in, hold bright, then settle to a quieter resting opacity.
	objective_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(objective_label, "modulate:a", 1.0, 0.35)
	tw.tween_interval(6.0)
	tw.tween_property(objective_label, "modulate:a", 0.7, 1.0)
	if is_comp:
		var timer = get_tree().create_timer(4.0)
		timer.timeout.connect(func():
			if revision == objective_revision:
				_set_objective_text("", false))

func _process(delta: float) -> void:
	var player = _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("player")
	var aiming := false
	if is_instance_valid(player):
		aiming = bool(player.get("is_aiming"))
		reticle.visible = aiming
	reticle.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(8, 16)
	var now := _now()
	var hurt := health_bar.value < health_bar.max_value * 0.999
	var vitals_target := 1.0 if (hurt or now < _vitals_active_until or oxygen_bar.visible) else 0.0
	_vitals.modulate.a = move_toward(_vitals.modulate.a, vitals_target, delta * (4.0 if vitals_target > 0.5 else 1.2))
	if ammo_label.text != "":
		var ammo_target := 1.0 if (aiming or now < _ammo_active_until) else 0.35
		ammo_label.modulate.a = move_toward(ammo_label.modulate.a, ammo_target, delta * 3.0)
