extends RefCounted

## Shared look for menus/panels: dark stone panels, warm brass accent (matches the story cards).
const BG := Color(0.035, 0.04, 0.045, 0.96)
const PANEL := Color(0.07, 0.075, 0.08, 0.97)
const ACCENT := Color(0.85, 0.7, 0.45)
const TEXT := Color(0.93, 0.91, 0.87)
const MUTED := Color(0.66, 0.67, 0.66)

static var _theme: Theme

static func _box(color: Color, border := Color(0, 0, 0, 0), width := 0, radius := 3, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(ACCENT, 0.35), 1, 4, 24))
	t.set_stylebox("panel", "Panel", _box(PANEL, Color(ACCENT, 0.35), 1, 4, 24))
	t.set_stylebox("embedded_border", "Window", _box(PANEL, Color(ACCENT, 0.5), 1, 4, 0))
	t.set_stylebox("embedded_unfocused_border", "Window", _box(PANEL, Color(ACCENT, 0.3), 1, 4, 0))
	t.set_color("title_color", "Window", ACCENT)
	for type in ["Label", "Button", "CheckButton", "OptionButton", "RichTextLabel"]:
		t.set_color("font_color", type, TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("hover", "Button", _box(Color(ACCENT, 0.18), Color(ACCENT, 0.6), 1))
	t.set_stylebox("pressed", "Button", _box(Color(ACCENT, 0.3), ACCENT, 1))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 1))
	t.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.02)))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	for type in ["OptionButton"]:
		t.set_stylebox("normal", type, _box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 1))
		t.set_stylebox("hover", type, _box(Color(ACCENT, 0.15), Color(ACCENT, 0.6), 1))
		t.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), ACCENT, 1))
	t.set_stylebox("slider", "HSlider", _box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT, Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT, Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("panel", "TabContainer", _box(PANEL, Color(ACCENT, 0.35), 1, 4, 20))
	t.set_stylebox("tab_selected", "TabContainer", _box(Color(ACCENT, 0.25), ACCENT, 1, 3, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 3, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(ACCENT, 0.12), Color(0, 0, 0, 0), 0, 3, 10))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_font_size("font_size", "TabContainer", 20)
	_theme = t
	return t

static func heading(text: String, size := 30) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	return l
