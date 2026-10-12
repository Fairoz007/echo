extends Control
## HUD mini-map: circular, top-right. Rotating (camera-up) or north-up per WorldMapManager setting.
## Region cartography + fog via MapView inside a SubViewport, masked to a circle; compass ring,
## heading readout, player arrow, objective/waypoint pointers clamped to the rim, layer + waypoint info.
## Also draws the optional in-world navigation indicator for the waypoint/objective.
class_name MiniMap

const DIAMETER := 216.0
const RANGE_M := 55.0 ## metres from centre to rim
const MASK_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	float a = 1.0 - smoothstep(0.485, 0.5, d);
	COLOR = vec4(c.rgb, c.a * a);
}
"""
const DIRS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var view: MapView
var _container: SubViewportContainer
var _vp: SubViewport
var _ring: Control
var _info: Label
var _nav: Control
var _center := Vector2.ZERO
var _rot := 0.0
var _initialised := false
var _marker_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DIAMETER, DIAMETER + 40)
	size = custom_minimum_size
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.position = Vector2.ZERO
	_container.size = Vector2(DIAMETER, DIAMETER)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MASK_SHADER
	mat.shader = sh
	_container.material = mat
	add_child(_container)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.size = Vector2i(DIAMETER, DIAMETER)
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.038, 0.78)
	bg.size = Vector2(DIAMETER, DIAMETER)
	_vp.add_child(bg)
	view = MapView.new()
	view.size = Vector2(DIAMETER, DIAMETER)
	view.icon_scale = 0.85
	view.show_undiscovered_outline = false
	_vp.add_child(view)
	_ring = Control.new()
	_ring.size = Vector2(DIAMETER, DIAMETER)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_info = Label.new()
	_info.position = Vector2(0, DIAMETER + 6)
	_info.size = Vector2(DIAMETER, 30)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 4)
	add_child(_info)

## Full-screen overlay for the in-world waypoint/objective indicator (added to the HUD root).
func attach_nav_overlay(parent: Node) -> void:
	_nav = Control.new()
	_nav.name = "NavIndicator"
	_nav.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav.draw.connect(_draw_nav)
	parent.add_child(_nav)

func _process(delta: float) -> void:
	var rid := WorldMapManager.current_region_id()
	var active := rid != "" and WorldMapManager.player() != null and WorldMapManager.level_node(rid) != null
	visible = active
	if _nav:
		_nav.visible = active and WorldMapManager.nav_indicator
		_nav.queue_redraw()
	if not active:
		_initialised = false
		return
	var target := WorldMapManager.player_map_pos()
	var target_rot := WorldMapManager.camera_heading() if WorldMapManager.minimap_rotates else 0.0
	if not _initialised or _center.distance_to(target) > 40.0:
		_center = target
		_rot = target_rot
		_initialised = true
	var k := 1.0 - exp(-14.0 * delta)
	_center = _center.lerp(target, k)
	_rot = lerp_angle(_rot, target_rot, 1.0 - exp(-10.0 * delta))
	view.center = _center
	view.view_rotation = _rot
	view.zoom = (DIAMETER * 0.5) / RANGE_M
	_marker_t -= delta
	if _marker_t <= 0.0:
		_marker_t = 0.15
		view.markers = WorldMapManager.get_markers()
		_update_info()
	view.refresh()
	_ring.queue_redraw()

func _update_info() -> void:
	var deg := int(round(rad_to_deg(wrapf(WorldMapManager.camera_heading(), 0.0, TAU)))) % 360
	var dir: String = DIRS[int(round(deg / 45.0)) % 8]
	var txt := "%s  %03d°" % [dir, deg]
	var wi := WorldMapManager.waypoint_info()
	if not wi.is_empty():
		if wi["same_region"]:
			txt += "   ◆ %d m" % int(wi["distance"])
			if wi["hint"] != "":
				txt += "\n" + str(wi["hint"])
		else:
			txt += "\n" + str(wi["hint"])
	var rid := WorldMapManager.current_region_id()
	var reg: Dictionary = WorldMapManager.by_id.get(rid, {})
	if reg.get("layers", []).size() > 1:
		var l := WorldMapManager.layer_info(rid, WorldMapManager.player_layer())
		txt += "\n" + str(l.get("name", ""))
	_info.text = txt

func _draw_ring() -> void:
	var c := Vector2(DIAMETER, DIAMETER) * 0.5
	var r := DIAMETER * 0.5
	_ring.draw_arc(c, r - 1.0, 0, TAU, 96, Color(0, 0, 0, 0.6), 4.0, true)
	_ring.draw_arc(c, r - 3.0, 0, TAU, 96, Color(MapView.GOLD, 0.85), 1.6, true)
	_ring.draw_arc(c, r - 9.0, 0, TAU, 96, Color(MapView.GOLD, 0.18), 1.0, true)
	var font := get_theme_default_font()
	for i in 4:
		var ang := i * PI * 0.5 - _rot
		var dirv := Vector2(sin(ang), -cos(ang))
		var p := c + dirv * (r - 13.0)
		var letter: String = ["N", "E", "S", "W"][i]
		var fs := 15 if i == 0 else 12
		var col := Color(0.98, 0.84, 0.50) if i == 0 else Color(0.85, 0.82, 0.74, 0.8)
		var sz := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_ring.draw_string_outline(font, p + Vector2(-sz.x * 0.5, sz.y * 0.33), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		_ring.draw_string(font, p + Vector2(-sz.x * 0.5, sz.y * 0.33), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	for i in 24:
		var ang2 := i * TAU / 24.0 - _rot
		var dv := Vector2(sin(ang2), -cos(ang2))
		if i % 6 != 0:
			_ring.draw_line(c + dv * (r - 5.0), c + dv * (r - 9.0), Color(MapView.GOLD, 0.5), 1.0)
	# Player arrow at the centre, pointing where Mara faces relative to the map's up.
	MapView.draw_icon(_ring, "player", c, 1.0, WorldMapManager.player_heading() - _rot)
	# Objective + waypoint markers beyond range: pinned to the rim as pointers.
	for m in view.markers:
		if not m["type"] in ["objective", "waypoint"] or m["region"] != WorldMapManager.current_region_id():
			continue
		var sp := view.map_to_screen(m["map"])
		var off := sp - c
		if off.length() > r - 16.0:
			var e := c + off.normalized() * (r - 16.0)
			MapView.draw_icon(_ring, m["type"], e, 0.75)

## In-world indicator: waypoint (and the nearest objective) projected on screen, edge-clamped.
func _draw_nav() -> void:
	var cam := get_viewport().get_camera_3d()
	var lvl := WorldMapManager.level_node(WorldMapManager.current_region_id())
	if cam == null or lvl == null:
		return
	var items: Array = []
	var wi := WorldMapManager.waypoint_info()
	if not wi.is_empty() and wi["same_region"]:
		items.append({"type": "waypoint", "world": lvl.to_global(wi["local"] + Vector3(0, 1.2, 0)), "d": wi["distance"], "hint": wi["hint"]})
	var best: Dictionary = {}
	var here := WorldMapManager.player_local()
	for m in view.markers:
		if m["type"] == "objective":
			var d: float = (m["local"] as Vector3).distance_to(here)
			if best.is_empty() or d < best["d"]:
				best = {"type": "objective", "world": lvl.to_global(m["local"] + Vector3(0, 1.4, 0)), "d": d, "hint": ""}
	if not best.is_empty() and best["d"] > 6.0:
		items.append(best)
	var vs := _nav.size
	var font := get_theme_default_font()
	for it in items:
		var wpos: Vector3 = it["world"]
		var behind := cam.is_position_behind(wpos)
		var sp := cam.unproject_position(wpos)
		if behind:
			sp = vs - sp
		var margin := 48.0
		var clamped := Vector2(clampf(sp.x, margin, vs.x - margin), clampf(sp.y, margin + 60, vs.y - margin - 80))
		if behind:
			clamped.y = vs.y - margin - 80
		MapView.draw_icon(_nav, it["type"], clamped, 1.0, 0.0, 0.9)
		var txt := "%d m" % int(it["d"])
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		_nav.draw_string_outline(font, clamped + Vector2(-sz.x * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.85))
		_nav.draw_string(font, clamped + Vector2(-sz.x * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.92, 0.84))
