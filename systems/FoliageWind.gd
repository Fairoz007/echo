extends Node3D
## Converts imported Tripo PBR foliage to the tiered wind shader (shaders/foliage_wind.gdshader).
## Wind values come from WindSystem (global). Quality is a shader uniform (wind_detail, pushed by
## WindSystem from GraphicsSettings "foliage_wind_detail"): ULTRA LOW keeps primary sway only.
## profile: "tree"  (rooted trunk, swaying branches, fluttering leaves, no player push),
##          "shrub"/"bush" (soft, outer leaves move most, bends away from the player),
##          "fern"  (very soft fronds, bends away from the player),
##          "vine"  (pinned at the top, free end swings, brushes aside),
##          "rock"  (no conversion, zero motion).
## Only MeshInstance3D surface materials are swapped; collision shapes are never touched.

const PROFILES := {
	#           wind_scale trunk branch flutter root_lock interact
	"tree":  [0.12, 0.15, 1.0, 0.35, 0.08, 0.0],
	"shrub": [0.06, 1.0,  0.6, 0.5,  0.05, 0.45],
	"bush":  [0.06, 1.0,  0.6, 0.5,  0.05, 0.45],
	"fern":  [0.07, 1.0,  0.8, 0.6,  0.04, 0.55],
	"vine":  [0.08, 0.9,  0.5, 0.6,  0.04, 0.4],
}

var bindings: Array[Dictionary] = []
var plant_height := 10.0
var root_height := 0.0
var profile_name := ""
## Opt-in: also convert untextured StandardMaterial3D surfaces (procedural test plants).
var accept_untextured := false
## Multiplies wind_scale (Level B uses a stronger amplitude).
var amplitude := 1.0
static var _flat_normal: Texture2D
static var _white: Texture2D

static func _fallbacks() -> void:
	if _white:
		return
	var w := Image.create(4, 4, false, Image.FORMAT_RGB8)
	w.fill(Color(1, 1, 1))
	_white = ImageTexture.create_from_image(w)
	var n := Image.create(4, 4, false, Image.FORMAT_RGB8)
	n.fill(Color(0.5, 0.5, 1.0))
	_flat_normal = ImageTexture.create_from_image(n)

func configure(plant: Node3D, height: float, base_y: float, profile := "") -> void:
	plant_height = height
	root_height = base_y
	if profile == "":
		profile = "tree" if height > 2.0 else "fern"
	profile_name = profile
	if profile == "rock":
		return
	_fallbacks()
	var aabb := _plant_aabb(plant)
	var radius := 3.0
	var axis := plant.global_position if plant.is_inside_tree() else Vector3.ZERO
	if aabb.size != Vector3.ZERO:
		radius = maxf(0.3, maxf(aabb.size.x, aabb.size.z) * 0.5)
		axis = Vector3(aabb.get_center().x, base_y, aabb.get_center().z)
	for mesh in plant.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for index in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(index) as StandardMaterial3D
			if not _accepts(original):
				continue
			var animated := make_material(original, profile, height, base_y, radius, axis)
			WindSystem.register_material(animated)
			bindings.append({"mesh": mesh, "surface": index, "original": original, "wind": animated})
	set_graphics_quality(0)

func _accepts(original: StandardMaterial3D) -> bool:
	if original == null:
		return false
	if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false  # the wind shader is opaque; alpha cards would render as silhouettes
	if accept_untextured:
		return true
	return original.albedo_texture != null and original.normal_texture != null and original.roughness_texture != null

func make_material(original: StandardMaterial3D, profile: String, height: float, base_y: float, radius: float, axis: Vector3) -> ShaderMaterial:
	var p: Array = PROFILES.get(profile, PROFILES.fern)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/foliage_wind.gdshader")
	m.set_shader_parameter("albedo_texture", original.albedo_texture if original.albedo_texture else _white)
	m.set_shader_parameter("normal_texture", original.normal_texture if original.normal_texture else _flat_normal)
	m.set_shader_parameter("orm_texture", original.roughness_texture if original.roughness_texture else _white)
	m.set_shader_parameter("albedo_tint", original.albedo_color)
	m.set_shader_parameter("roughness_factor", original.roughness)
	m.set_shader_parameter("metallic_factor", original.metallic if original.roughness_texture else 0.0)
	m.set_shader_parameter("normal_scale", original.normal_scale if original.normal_texture else 0.0)
	m.set_shader_parameter("plant_height", height)
	m.set_shader_parameter("plant_radius", radius)
	m.set_shader_parameter("root_height", base_y)
	m.set_shader_parameter("plant_origin", axis)
	m.set_shader_parameter("wind_scale", p[0] * amplitude)
	m.set_shader_parameter("trunk_bend", p[1])
	m.set_shader_parameter("branch_sway", p[2])
	m.set_shader_parameter("leaf_flutter", p[3])
	m.set_shader_parameter("root_lock", p[4])
	m.set_shader_parameter("interact_strength", p[5])
	m.set_shader_parameter("pin_top", profile == "vine")
	return m

func _plant_aabb(plant: Node3D) -> AABB:
	var out := AABB()
	for vi in plant.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = vi.global_transform * vi.get_aabb()
		out = a if out.size == Vector3.ZERO else out.merge(a)
	return out

## Every quality level animates; the amount of detail is the wind_detail uniform
## (WindSystem reads GraphicsSettings "foliage_wind_detail"). The legacy tier is ignored.
func set_graphics_quality(_preset: int) -> void:
	for binding in bindings:
		binding.mesh.set_surface_override_material(binding.surface, binding.wind)
