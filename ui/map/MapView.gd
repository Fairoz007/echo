extends Control
## Shared map renderer for the mini-map and the world map.
## View = centre (map metres) + zoom (px / metre) + rotation (radians, map rotated by -rotation).
## Region cartography (baked textures) is drawn by Sprite2D children with a fog-of-war shader;
## routes under them; markers on top in screen space so icons never scale or rotate with the map.
class_name MapView

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D fog_tex : filter_linear;
uniform vec2 fog_uv_scale = vec2(1.0);
uniform float unexplored = 0.0;
uniform float dim = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float f = smoothstep(0.2, 0.8, texture(fog_tex, UV * fog_uv_scale).r);
	COLOR = vec4(c.rgb * dim, c.a * mix(unexplored, 1.0, f));
}
"""
const GOLD := Color(0.86, 0.68, 0.36)
const GOLD_DIM := Color(0.62, 0.50, 0.30, 0.8)
const INK := Color(0.05, 0.055, 0.05, 0.92)
const ICON_COLORS := {
	"objective": Color(0.98, 0.80, 0.38), "waypoint": Color(0.45, 0.85, 0.95), "tomb": Color(0.86, 0.62, 0.95),
	"exit": Color(0.92, 0.92, 0.85), "landmark": Color(0.86, 0.80, 0.66), "enemy": Color(0.95, 0.30, 0.25),
	"collectible": Color(0.55, 0.95, 0.65), "connection": Color(0.80, 0.80, 0.80), "cave": Color(0.75, 0.68, 0.55),
}

var center := Vector2.ZERO
var zoom := 2.0
var view_rotation := 0.0
var selected_layer := {} ## region_id -> layer id override
var kind_filter := "" ## "" = all layer kinds at full strength
var hidden_types := {} ## marker type -> true to hide
var icon_scale := 1.0
var show_labels := false
var show_undiscovered_outline := true
var markers: Array = []

var _world := Node2D.new()
var _routes := Node2D.new()
var _sprites := {} ## region_id -> Sprite2D
var _shader := Shader.new()
var _overlay := Control.new()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader.code = FOG_SHADER
	add_child(_world)
	_world.add_child(_routes)
	_routes.draw.connect(_draw_routes)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

func _build_sprites() -> void:
	for reg in WorldMapManager.regions:
		if _sprites.has(reg["id"]):
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.position = reg["offset"]
		s.scale = Vector2.ONE * float(reg["res"])
		var m := ShaderMaterial.new()
		m.shader = _shader
		var fs: Vector2i = reg["fog_size"]
		m.set_shader_parameter("fog_uv_scale", reg["size_m"] / (Vector2(fs) * WorldMapManager.FOG_CELL))
		s.material = m
		_world.add_child(s)
		_sprites[reg["id"]] = s

func refresh() -> void:
	if _sprites.size() != WorldMapManager.regions.size():
		_build_sprites()
	var cur := WorldMapManager.current_region_id()
	for reg in WorldMapManager.regions:
		var rid: String = reg["id"]
		var s: Sprite2D = _sprites[rid]
		var discovered := WorldMapManager.discovered_regions.has(rid)
		s.visible = discovered
		if not discovered:
			continue
		var layer: String = selected_layer.get(rid, "")
		if layer == "":
			layer = WorldMapManager.player_layer() if rid == cur else (reg["layers"][0]["id"] if not reg["layers"].is_empty() else "")
		var tex := WorldMapManager.region_texture(rid, layer)
		s.texture = tex
		var m := s.material as ShaderMaterial
		m.set_shader_parameter("fog_tex", WorldMapManager.fog_texture(rid))
		var in_kind := kind_filter == "" or _layer_kind(rid, layer) == kind_filter
		m.set_shader_parameter("dim", 1.0 if in_kind else 0.35)
	_world.transform = _view_xform()
	_routes.queue_redraw()
	_overlay.queue_redraw()

func _layer_kind(rid: String, layer: String) -> String:
	var l := WorldMapManager.layer_info(rid, layer)
	return str(l.get("kind", WorldMapManager.by_id[rid].get("kind", "surface")))

func _view_xform() -> Transform2D:
	return Transform2D(0.0, size * 0.5) * Transform2D(-view_rotation, Vector2.ZERO) * Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2.ZERO) * Transform2D(0.0, -center)

func map_to_screen(map: Vector2) -> Vector2:
	return _view_xform() * map

func screen_to_map(screen: Vector2) -> Vector2:
	return _view_xform().affine_inverse() * screen

func _draw_routes() -> void:
	var w := 2.2 / zoom
	for r in WorldMapManager.routes:
		var known: bool = WorldMapManager.discovered_regions.has(r["from"]) and WorldMapManager.discovered_regions.has(r["to"])
		if not known:
			continue
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		if r["passage"]:
			_routes.draw_line(a, b, GOLD_DIM, w * 1.6, true)
		else:
			_routes.draw_dashed_line(a, b, Color(GOLD_DIM, 0.5), w, 10.0 / zoom * 2.0)
	if show_undiscovered_outline:
		for reg in WorldMapManager.regions:
			var rect := Rect2(reg["offset"], reg["size_m"])
			if not WorldMapManager.discovered_regions.has(reg["id"]):
				_routes.draw_rect(rect, Color(0.6, 0.55, 0.45, 0.10), false, w)

func _draw_overlay() -> void:
	var font := get_theme_default_font()
	var cur := WorldMapManager.current_region_id()
	if show_labels:
		for reg in WorldMapManager.regions:
			var discovered := WorldMapManager.discovered_regions.has(reg["id"])
			var p := map_to_screen(Vector2(reg["offset"]) + Vector2(reg["size_m"].x * 0.5, -6.0))
			if p.y < 100.0 and size.y > 400.0:
				continue # keep region names out of the atlas header
			var label: String = str(reg["name"]).to_upper() if discovered else "UNCHARTED"
			var fs := 15
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_overlay.draw_string_outline(font, p - Vector2(tw * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
			_overlay.draw_string(font, p - Vector2(tw * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD if discovered else Color(0.6, 0.6, 0.6, 0.5))
	var label_spots: Array = []
	for m in markers:
		var t: String = m["type"]
		if t == "_player":
			draw_icon(_overlay, "player", map_to_screen(m["map"]), 1.25, WorldMapManager.player_heading() - view_rotation)
			continue
		if hidden_types.get(t, false):
			continue
		var layer: String = selected_layer.get(m["region"], "")
		if layer == "" and m["region"] == cur:
			layer = WorldMapManager.player_layer()
		var other_layer: bool = layer != "" and m["layer"] != "" and m["layer"] != layer
		var p := map_to_screen(m["map"])
		if not Rect2(Vector2.ZERO, size).grow(16).has_point(p):
			continue
		draw_icon(_overlay, t, p, icon_scale, 0.0, 0.45 if other_layer else 1.0)
		var free := true
		for q in label_spots:
			if absf(q.y - p.y) < 16.0 and absf(q.x - p.x) < 180.0:
				free = false
		if show_labels and free and t in ["tomb", "landmark", "exit", "objective"]:
			label_spots.append(p)
			_overlay.draw_string_outline(font, p + Vector2(12, 5), str(m["label"]), HORIZONTAL_ALIGNMENT_LEFT, 260, 13, 3, Color(0, 0, 0, 0.85))
			_overlay.draw_string(font, p + Vector2(12, 5), str(m["label"]), HORIZONTAL_ALIGNMENT_LEFT, 260, 13, Color(0.92, 0.88, 0.78))

## Vector icon set (no external art): clean shapes in the HUD palette.
static func draw_icon(ci: CanvasItem, type: String, p: Vector2, s: float, rot := 0.0, alpha := 1.0) -> void:
	var c: Color = ICON_COLORS.get(type, Color.WHITE)
	c.a *= alpha
	var ink := Color(INK, INK.a * alpha)
	match type:
		"player":
			var pts := PackedVector2Array([Vector2(0, -11), Vector2(7.5, 8), Vector2(0, 4), Vector2(-7.5, 8)])
			var xf := Transform2D(rot, p) * Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
			var out := xf * PackedVector2Array([Vector2(0, -14), Vector2(10, 10.5), Vector2(0, 6), Vector2(-10, 10.5)])
			ci.draw_colored_polygon(out, ink)
			ci.draw_colored_polygon(xf * pts, Color(0.98, 0.95, 0.88, alpha))
		"objective":
			var d := PackedVector2Array([p + Vector2(0, -9) * s, p + Vector2(9, 0) * s, p + Vector2(0, 9) * s, p + Vector2(-9, 0) * s])
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12) * s, p + Vector2(12, 0) * s, p + Vector2(0, 12) * s, p + Vector2(-12, 0) * s]), ink)
			ci.draw_colored_polygon(d, c)
			ci.draw_circle(p, 2.5 * s, ink)
		"waypoint":
			ci.draw_circle(p + Vector2(0, -8) * s, 8.5 * s, ink)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -5) * s, p + Vector2(6, -5) * s, p]), c)
			ci.draw_circle(p + Vector2(0, -8) * s, 6.5 * s, c)
			ci.draw_circle(p + Vector2(0, -8) * s, 2.5 * s, ink)
		"tomb":
			ci.draw_rect(Rect2(p - Vector2(8, 8) * s, Vector2(16, 16) * s), ink)
			ci.draw_rect(Rect2(p - Vector2(6, 6) * s, Vector2(12, 12) * s), c, false, 2.0 * s)
			ci.draw_rect(Rect2(p + Vector2(-2.5, -1) * s, Vector2(5, 7) * s), c)
		"exit":
			ci.draw_circle(p, 9 * s, ink)
			ci.draw_arc(p, 7 * s, PI, TAU, 12, c, 2.0 * s)
			ci.draw_line(p + Vector2(-7, 0) * s, p + Vector2(-7, 6) * s, c, 2.0 * s)
			ci.draw_line(p + Vector2(7, 0) * s, p + Vector2(7, 6) * s, c, 2.0 * s)
		"cave":
			ci.draw_circle(p, 8 * s, ink)
			ci.draw_arc(p + Vector2(0, 3) * s, 6 * s, PI, TAU, 10, c, 2.5 * s)
		"landmark":
			ci.draw_circle(p, 6 * s, ink)
			ci.draw_circle(p, 3.5 * s, c)
		"enemy":
			ci.draw_circle(p, 6 * s, ink)
			ci.draw_circle(p, 4 * s, c)
		"collectible":
			var d2 := PackedVector2Array([p + Vector2(0, -6) * s, p + Vector2(4, 0) * s, p + Vector2(0, 6) * s, p + Vector2(-4, 0) * s])
			ci.draw_colored_polygon(d2, c)
		"connection":
			ci.draw_rect(Rect2(p - Vector2(7, 7) * s, Vector2(14, 14) * s), ink)
			ci.draw_line(p + Vector2(-3, -5) * s, p + Vector2(-3, 5) * s, c, 1.6 * s)
			ci.draw_line(p + Vector2(3, -5) * s, p + Vector2(3, 5) * s, c, 1.6 * s)
			for k in 3:
				ci.draw_line(p + Vector2(-3, -3 + k * 3) * s, p + Vector2(3, -3 + k * 3) * s, c, 1.2 * s)
		_:
			ci.draw_circle(p, 4 * s, c)
