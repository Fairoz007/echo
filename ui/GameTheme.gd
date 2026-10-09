extends RefCounted

## Echoes Beneath shared UI look: deep charcoal / moss stone panels, warm parchment text,
## brass accents, and a cyan "echo" highlight reserved for keyboard/gamepad focus.
## The theme is built in code (single source of truth) and also saved to
## res://ui/theme/echoes_theme.tres by dev/ui_build_theme.gd for the project-wide setting.

const BG := Color(0.035, 0.042, 0.04, 0.97)
const PANEL := Color(0.067, 0.082, 0.074, 0.96)
const PANEL_LIGHT := Color(0.105, 0.125, 0.11, 0.96)
const MOSS := Color(0.30, 0.40, 0.30)
const ACCENT := Color(0.86, 0.70, 0.44)      # brass
const ECHO := Color(0.38, 0.86, 0.90)        # cyan focus highlight
const DANGER := Color(0.86, 0.36, 0.30)
const TEXT := Color(0.94, 0.91, 0.84)        # parchment
const MUTED := Color(0.62, 0.64, 0.60)

const FS_SMALL := 15
const FS_BODY := 18
const FS_BUTTON := 20
const FS_H2 := 26
const FS_H1 := 34

static var _theme: Theme
static var _sfx_player: AudioStreamPlayer
static var _sfx: Dictionary = {}

static func box(color: Color, border := Color(0, 0, 0, 0), width := 0, radius := 6, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

static func _focus_ring(radius := 6) -> StyleBoxFlat:
	var s := box(Color(0, 0, 0, 0), ECHO, 2, radius + 2, 0)
	s.set_expand_margin_all(3)
	s.draw_center = false
	return s

static func _button_box(bg: Color, border: Color, accent_left := false) -> StyleBoxFlat:
	var s := box(bg, border, 1, 6, 0)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if accent_left:
		s.border_width_left = 4
	return s

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = FS_BODY
	var panel := box(PANEL, Color(ACCENT, 0.28), 1, 10, 24)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("embedded_border", "Window", box(PANEL, Color(ACCENT, 0.35), 1, 10, 0))
	t.set_stylebox("embedded_unfocused_border", "Window", box(PANEL, Color(ACCENT, 0.25), 1, 10, 0))
	t.set_stylebox("panel", "Window", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10, 0))
	t.set_color("title_color", "Window", ACCENT)
	for type in ["Label", "Button", "CheckButton", "CheckBox", "OptionButton", "RichTextLabel", "PopupMenu"]:
		t.set_color("font_color", type, TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", FS_BODY)
	t.set_font_size("bold_font_size", "RichTextLabel", FS_BODY + 2)
	t.set_constant("line_separation", "RichTextLabel", 4)
	# Buttons: quiet stone at rest, brass on hover, cyan ring for focus.
	t.set_font_size("font_size", "Button", FS_BUTTON)
	t.set_stylebox("normal", "Button", _button_box(Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.07)))
	t.set_stylebox("hover", "Button", _button_box(Color(ACCENT, 0.16), Color(ACCENT, 0.75), true))
	t.set_stylebox("pressed", "Button", _button_box(Color(ACCENT, 0.32), ACCENT, true))
	t.set_stylebox("hover_pressed", "Button", _button_box(Color(ACCENT, 0.32), ACCENT, true))
	t.set_stylebox("disabled", "Button", _button_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.03)))
	t.set_stylebox("focus", "Button", _focus_ring())
	t.set_color("font_hover_color", "Button", Color(1, 0.97, 0.9))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color(1, 0.97, 0.9))
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.45))
	for type in ["CheckButton", "CheckBox"]:
		t.set_font_size("font_size", type, FS_BODY)
		t.set_stylebox("normal", type, box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.06), 1, 6, 12))
		t.set_stylebox("hover", type, box(Color(ACCENT, 0.12), Color(ACCENT, 0.5), 1, 6, 12))
		t.set_stylebox("pressed", type, box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.06), 1, 6, 12))
		t.set_stylebox("hover_pressed", type, box(Color(ACCENT, 0.12), Color(ACCENT, 0.5), 1, 6, 12))
		t.set_stylebox("focus", type, _focus_ring())
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, TEXT)
	t.set_font_size("font_size", "OptionButton", FS_BODY)
	t.set_stylebox("normal", "OptionButton", box(PANEL_LIGHT, Color(1, 1, 1, 0.1), 1, 6, 12))
	t.set_stylebox("hover", "OptionButton", box(Color(ACCENT, 0.14), Color(ACCENT, 0.65), 1, 6, 12))
	t.set_stylebox("pressed", "OptionButton", box(Color(ACCENT, 0.24), ACCENT, 1, 6, 12))
	t.set_stylebox("focus", "OptionButton", _focus_ring())
	t.set_color("font_hover_color", "OptionButton", Color.WHITE)
	t.set_color("font_focus_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(PANEL_LIGHT, Color(ACCENT, 0.4), 1, 6, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(ACCENT, 0.22), Color(0, 0, 0, 0), 0, 4, 6))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", FS_BODY)
	# Sliders and bars
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 3, 3))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 0, 3, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color(1, 0.85, 0.6), Color(0, 0, 0, 0), 0, 3, 3))
	t.set_stylebox("focus", "HSlider", _focus_ring(3))
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.08), 1, 4, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 0, 4, 0))
	# Tabs
	var tab_panel := box(PANEL, Color(ACCENT, 0.22), 1, 10, 22)
	tab_panel.corner_radius_top_left = 0
	t.set_stylebox("panel", "TabContainer", tab_panel)
	for type in ["TabContainer", "TabBar"]:
		var sel := box(PANEL, Color(ACCENT, 0.9), 0, 8, 0)
		sel.border_width_top = 3
		sel.corner_radius_bottom_left = 0
		sel.corner_radius_bottom_right = 0
		sel.content_margin_left = 22
		sel.content_margin_right = 22
		sel.content_margin_top = 10
		sel.content_margin_bottom = 10
		var unsel := sel.duplicate()
		unsel.bg_color = Color(1, 1, 1, 0.03)
		unsel.border_width_top = 0
		var hov := sel.duplicate()
		hov.bg_color = Color(ACCENT, 0.12)
		hov.border_color = Color(ACCENT, 0.5)
		t.set_stylebox("tab_selected", type, sel)
		t.set_stylebox("tab_unselected", type, unsel)
		t.set_stylebox("tab_hovered", type, hov)
		t.set_stylebox("tab_focus", type, _focus_ring(8))
		t.set_color("font_selected_color", type, ACCENT)
		t.set_color("font_unselected_color", type, MUTED)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_font_size("font_size", type, FS_BUTTON)
	t.set_constant("side_margin", "TabContainer", 0)
	# Scrollbars
	t.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber", "VScrollBar", box(Color(ACCENT, 0.45), Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("separator", "HSeparator", box(Color(ACCENT, 0.25), Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 14)
	_theme = t
	return t

static func heading(text: String, size := FS_H1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	return l

static func caption(text: String, size := FS_SMALL, color := MUTED) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Thin brass rule with fading ends, used under headings.
static func rule(width := 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(width, 2)
	r.color = Color(ACCENT, 0.45)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Short fade + slide-in for a screen/panel. Works while the tree is paused.
static func fade_in(c: CanvasItem, slide := Vector2(0, 14), duration := 0.22) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration)
	if c is Control and slide != Vector2.ZERO and not (c.get_parent() is Container):
		var target: Vector2 = c.position
		c.position = target + slide
		tw.tween_property(c, "position", target, duration)

# ---------------------------------------------------------------- UI sounds
# AudioManager has no UI hook, so short procedural ticks are synthesized here and played on
# the "UI" bus (created by AudioManager) through one shared, pause-proof player.

static func _tone(freq: float, dur: float, vol: float, sweep := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var env := minf(1.0, t / 0.003) * exp(-t * 5.0 / dur)
		phase += TAU * (freq + sweep * t / dur) / rate
		var s := sin(phase) * 0.7 + sin(phase * 2.01) * 0.2
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

static func play_ui(kind: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_sfx_player):
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "EchoesUISfx"
		_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_sfx_player.bus = "UI" if AudioServer.get_bus_index("UI") >= 0 else "Master"
		_sfx_player.max_polyphony = 4
		tree.root.add_child.call_deferred(_sfx_player)
		_sfx = {"hover": _tone(1250.0, 0.045, 0.22), "click": _tone(620.0, 0.09, 0.42, -180.0), "back": _tone(480.0, 0.1, 0.35, -160.0), "open": _tone(520.0, 0.16, 0.3, 260.0)}
		return
	if not _sfx_player.is_inside_tree() or not _sfx.has(kind):
		return
	_sfx_player.stream = _sfx[kind]
	_sfx_player.volume_db = -14.0 if kind == "hover" else -8.0
	_sfx_player.play()

## Connects hover/focus/press sounds for every BaseButton under `root` (once per button).
static func wire_sounds(root: Node) -> void:
	play_ui("")  # make sure the player exists
	for b in root.find_children("*", "BaseButton", true, false):
		if b.has_meta("echoes_sfx"):
			continue
		b.set_meta("echoes_sfx", true)
		b.mouse_entered.connect(func(): if not b.disabled: play_ui("hover"))
		b.focus_entered.connect(func(): play_ui("hover"))
		b.pressed.connect(func(): play_ui("click"))
	for tc in root.find_children("*", "TabContainer", true, false):
		if not tc.has_meta("echoes_sfx"):
			tc.set_meta("echoes_sfx", true)
			tc.tab_changed.connect(func(_i): play_ui("hover"))

## Animated mist + strata background shader shared by the menu and story cards.
const MIST_SHADER := """
shader_type canvas_item;
uniform vec3 tint = vec3(0.55, 0.45, 0.32);
uniform vec3 echo = vec3(0.25, 0.7, 0.75);
uniform float pan = 0.0;
uniform float echo_strength = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int k = 0; k < 5; k++){ v += a*n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment(){
	vec2 uv = UV * vec2(1.78, 1.0) + vec2(pan + TIME * 0.004, 0.0);
	float strata = smoothstep(0.45, 0.5, fract(uv.y * 7.0 + fbm(uv * 2.0) * 1.6)) * 0.12;
	float mist = fbm(uv * 1.6 + vec2(TIME * 0.015, 0.0));
	float glow = smoothstep(0.9, 0.0, distance(UV, vec2(0.72, 0.45))) * 0.35;
	vec3 c = tint * (mist * 0.45 + strata + glow);
	float d = distance(UV * vec2(1.78, 1.0), vec2(0.72 * 1.78, 0.45));
	float ring = (1.0 - smoothstep(0.0, 0.025, abs(fract(d * 2.2 - TIME * 0.08) - 0.5))) * smoothstep(1.2, 0.1, d);
	c += echo * ring * echo_strength * (0.4 + mist * 0.6);
	float vignette = smoothstep(1.1, 0.35, distance(UV, vec2(0.5)));
	COLOR = vec4(c * vignette, 1.0);
}
"""

static func mist_material(echo_strength := 0.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = MIST_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("echo_strength", echo_strength)
	return mat
