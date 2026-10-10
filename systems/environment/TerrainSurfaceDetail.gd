extends Node
## Quality-aware surface detail for existing sediment GLBs. Attached only to floor
## assets: keeps source UV atlases and restores the exact original materials on Low.
const SHADER := preload("res://materials/sediment_surface.gdshader")
static var _materials: Dictionary = {}
var _bindings: Array[Dictionary] = []

func _ready() -> void:
	name = "TerrainSurfaceDetail"
	var target := get_parent()
	if target is MultiMeshInstance3D and target.multimesh:
		var mesh: Mesh = target.multimesh.mesh
		var source: Array[Material] = []
		var detailed: Array[Material] = []
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			source.append(material)
			detailed.append(_detailed(material))
		_bindings.append({"mesh": mesh, "source": source, "detailed": detailed})
	else:
		var meshes := target.find_children("*", "MeshInstance3D", true, false)
		if target is MeshInstance3D:
			meshes.append(target)
		for item in meshes:
			var instance := item as MeshInstance3D
			if instance.mesh == null:
				continue
			var source: Array[Material] = []
			var detailed: Array[Material] = []
			for surface in instance.mesh.get_surface_count():
				source.append(instance.get_surface_override_material(surface))
				detailed.append(_detailed(instance.get_active_material(surface)))
			_bindings.append({"instance": weakref(instance), "override": instance.material_override, "source": source, "detailed": detailed})
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	if graphics:
		set_quality_settings(graphics.settings)

func set_quality_settings(settings: Dictionary) -> void:
	var enabled := float(settings.get("terrain_detail", 0.0)) > 0.0
	for binding in _bindings:
		var materials: Array = binding.detailed if enabled else binding.source
		if binding.has("mesh"):
			for surface in materials.size():
				binding.mesh.surface_set_material(surface, materials[surface])
		else:
			var instance: MeshInstance3D = binding.instance.get_ref()
			if not is_instance_valid(instance):
				continue
			instance.material_override = null if enabled else binding.override
			for surface in materials.size():
				instance.set_surface_override_material(surface, materials[surface])

static func _detailed(source: Material) -> Material:
	if not source is BaseMaterial3D:
		return source
	var base := source as BaseMaterial3D
	# This adapter is for opaque sediment, not water, foliage or emissive props.
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.emission_enabled:
		return source
	var key := source.get_instance_id()
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_meta("terrain_source", source) # source remains alive for cache identity
	material.set_shader_parameter("albedo_tex", base.albedo_texture)
	material.set_shader_parameter("has_albedo", base.albedo_texture != null)
	material.set_shader_parameter("albedo_tint", base.albedo_color)
	material.set_shader_parameter("normal_tex", base.normal_texture)
	material.set_shader_parameter("has_normal", base.normal_enabled and base.normal_texture != null)
	material.set_shader_parameter("normal_strength", base.normal_scale)
	material.set_shader_parameter("roughness_tex", base.orm_texture if base is ORMMaterial3D else base.roughness_texture)
	material.set_shader_parameter("roughness_channel", Vector4(0, 1, 0, 0) if base is ORMMaterial3D else _channel(base.roughness_texture_channel))
	material.set_shader_parameter("has_roughness", (base.orm_texture if base is ORMMaterial3D else base.roughness_texture) != null)
	material.set_shader_parameter("roughness_amount", base.roughness)
	material.set_shader_parameter("metallic_tex", base.orm_texture if base is ORMMaterial3D else base.metallic_texture)
	material.set_shader_parameter("metallic_channel", Vector4(0, 0, 1, 0) if base is ORMMaterial3D else _channel(base.metallic_texture_channel))
	material.set_shader_parameter("has_metallic", (base.orm_texture if base is ORMMaterial3D else base.metallic_texture) != null)
	material.set_shader_parameter("metallic_amount", base.metallic)
	material.set_shader_parameter("specular_amount", base.metallic_specular)
	material.set_shader_parameter("ao_tex", base.orm_texture if base is ORMMaterial3D else base.ao_texture)
	material.set_shader_parameter("ao_channel", Vector4(1, 0, 0, 0) if base is ORMMaterial3D else _channel(base.ao_texture_channel))
	material.set_shader_parameter("has_ao", base.ao_enabled and (base.orm_texture if base is ORMMaterial3D else base.ao_texture) != null)
	material.set_shader_parameter("ao_light_affect", base.ao_light_affect)
	material.set_shader_parameter("uv_scale", base.uv1_scale)
	material.set_shader_parameter("uv_offset", base.uv1_offset)
	_materials[key] = material
	return material

static func _channel(channel: int) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN: return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE: return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: return Vector4(0, 0, 0, 1)
		BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE: return Vector4(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, 0)
	return Vector4(1, 0, 0, 0)
