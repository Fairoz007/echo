extends SceneTree
func _init() -> void:
	call_deferred("_verify")
func _verify() -> void:
	for path in ["res://assets/environment/jungle/jungle_tree.glb", "res://assets/environment/jungle/jungle_fern.glb"]:
		var plant := load(path).instantiate() as Node3D
		root.add_child(plant)
		var wind = load("res://systems/FoliageWind.gd").new()
		plant.add_child(wind)
		wind.configure(plant, 10.0, 0.0)
		assert(wind.bindings.size() > 0, "Imported PBR materials must bind")
		for quality in range(3):
			wind.set_graphics_quality(quality)
			for binding in wind.bindings:
				var selected = binding.mesh.get_surface_override_material(binding.surface)
				assert(selected == (binding.original if quality == 0 else binding.wind))
				assert(binding.wind.get_shader_parameter("albedo_texture") == binding.original.albedo_texture)
				assert(binding.wind.get_shader_parameter("normal_texture") == binding.original.normal_texture)
				assert(binding.wind.get_shader_parameter("orm_texture") == binding.original.roughness_texture)
		print("FOLIAGE_WIND_PASS ", path, " bindings=", wind.bindings.size(), " PBR_maps_preserved=true low_original_material=true")
		plant.queue_free()
	await process_frame
	quit()
