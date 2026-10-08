extends Node3D
## Converts imported Tripo PBR foliage to the tiered wind shader. Low restores
## original materials. Wind values come from WindSystem (global).
## profile: "tree" (stiff trunk, swaying branches, fluttering leaves),
##          "shrub"/"fern" (soft), "rock" (no conversion, zero motion).
var bindings: Array[Dictionary] = []
var plant_height := 10.0
var root_height := 0.0

func configure(plant: Node3D, height: float, base_y: float, profile := "") -> void:
	plant_height = height
	root_height = base_y
	if profile == "":
		profile = "tree" if height > 2.0 else "fern"
	if profile == "rock":
		return
	var radius := 3.0
	var aabb := _plant_aabb(plant)
	if aabb.size != Vector3.ZERO:
		radius = maxf(0.3, maxf(aabb.size.x, aabb.size.z) * 0.5)
	for mesh in plant.find_children("*", "MeshInstance3D", true, false):
		for index in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(index) as StandardMaterial3D
			if original == null or original.albedo_texture == null or original.normal_texture == null or original.roughness_texture == null:
				continue
			var animated := ShaderMaterial.new()
			animated.shader = preload("res://shaders/foliage_wind.gdshader")
			animated.set_shader_parameter("albedo_texture", original.albedo_texture)
			animated.set_shader_parameter("normal_texture", original.normal_texture)
			animated.set_shader_parameter("orm_texture", original.roughness_texture)
			animated.set_shader_parameter("albedo_tint", original.albedo_color)
			animated.set_shader_parameter("roughness_factor", original.roughness)
			animated.set_shader_parameter("metallic_factor", original.metallic)
			animated.set_shader_parameter("normal_scale", original.normal_scale)
			animated.set_shader_parameter("plant_height", height)
			animated.set_shader_parameter("plant_radius", radius)
			animated.set_shader_parameter("root_height", base_y)
			if profile == "tree":
				animated.set_shader_parameter("wind_scale", 0.12)
				animated.set_shader_parameter("trunk_bend", 0.15)
				animated.set_shader_parameter("branch_sway", 1.0)
				animated.set_shader_parameter("leaf_flutter", 0.35)
			else:
				animated.set_shader_parameter("wind_scale", 0.06)
				animated.set_shader_parameter("trunk_bend", 1.0)
				animated.set_shader_parameter("branch_sway", 0.6)
				animated.set_shader_parameter("leaf_flutter", 0.5)
			WindSystem.register_material(animated)
			bindings.append({"mesh": mesh, "surface": index, "original": original, "wind": animated})
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings") if is_inside_tree() else null
	set_graphics_quality(int(graphics.preset) if graphics else 0)

func _plant_aabb(plant: Node3D) -> AABB:
	var out := AABB()
	for vi in plant.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = vi.global_transform * vi.get_aabb()
		out = a if out.size == Vector3.ZERO else out.merge(a)
	return out

func set_graphics_quality(preset: int) -> void:
	for binding in bindings:
		binding.mesh.set_surface_override_material(binding.surface, binding.original if preset == 0 else binding.wind)
