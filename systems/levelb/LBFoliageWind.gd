extends "res://systems/FoliageWind.gd"
## Level B foliage wind: the same systems tiered wind shader (shaders/foliage_wind.gdshader,
## driven by WindSystem) as FoliageWind, but
##  - stays active on the Low preset (vertex sway is cheap; Low otherwise freezes plants),
##  - accepts Tripo materials without a normal/ORM map (phase-2 jungle set),
##  - uses a stronger amplitude so motion reads at gameplay distance.

const BOOST := {"tree": 2.2, "fern": 2.6}
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
	if profile == "rock":
		return
	_fallbacks()
	var aabb := _plant_aabb(plant)
	var radius := maxf(0.3, maxf(aabb.size.x, aabb.size.z) * 0.5) if aabb.size != Vector3.ZERO else 3.0
	var boost: float = BOOST.get(profile, 2.0)
	for mesh in plant.find_children("*", "MeshInstance3D", true, false):
		for index in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(index) as StandardMaterial3D
			if original == null or original.albedo_texture == null:
				continue
			var animated := ShaderMaterial.new()
			animated.shader = preload("res://shaders/foliage_wind.gdshader")
			animated.set_shader_parameter("albedo_texture", original.albedo_texture)
			animated.set_shader_parameter("normal_texture", original.normal_texture if original.normal_texture else _flat_normal)
			animated.set_shader_parameter("orm_texture", original.roughness_texture if original.roughness_texture else _white)
			animated.set_shader_parameter("albedo_tint", original.albedo_color)
			animated.set_shader_parameter("roughness_factor", original.roughness)
			animated.set_shader_parameter("metallic_factor", original.metallic if original.roughness_texture else 0.0)
			animated.set_shader_parameter("normal_scale", original.normal_scale if original.normal_texture else 0.0)
			animated.set_shader_parameter("plant_height", height)
			animated.set_shader_parameter("plant_radius", radius)
			animated.set_shader_parameter("root_height", base_y)
			if profile == "tree":
				animated.set_shader_parameter("wind_scale", 0.12 * boost)
				animated.set_shader_parameter("trunk_bend", 0.15)
				animated.set_shader_parameter("branch_sway", 1.0)
				animated.set_shader_parameter("leaf_flutter", 0.35)
			else:
				animated.set_shader_parameter("wind_scale", 0.06 * boost)
				animated.set_shader_parameter("trunk_bend", 1.0)
				animated.set_shader_parameter("branch_sway", 0.6)
				animated.set_shader_parameter("leaf_flutter", 0.5)
			WindSystem.register_material(animated)
			bindings.append({"mesh": mesh, "surface": index, "original": original, "wind": animated})
	set_graphics_quality(1)

func set_graphics_quality(_preset: int) -> void:
	for binding in bindings:
		binding.mesh.set_surface_override_material(binding.surface, binding.wind)
