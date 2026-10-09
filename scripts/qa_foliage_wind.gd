extends SceneTree
## Foliage wind QA (headless OK):
##   godot --headless --path D:/new-dev -s res://scripts/qa_foliage_wind.gd -- --quality=1
func _init() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var ok := true
	for path in ["res://assets/environment/jungle/jungle_tree.glb", "res://assets/environment/jungle/jungle_fern.glb"]:
		var plant := load(path).instantiate() as Node3D
		root.add_child(plant)
		var wind = load("res://systems/FoliageWind.gd").new()
		plant.add_child(wind)
		wind.configure(plant, 10.0, 0.0)
		assert(wind.bindings.size() > 0, "Imported PBR materials must bind")
		ok = ok and wind.bindings.size() > 0
		for quality in range(3):
			wind.set_graphics_quality(quality)
			for binding in wind.bindings:
				# Every quality level animates (detail is the wind_detail uniform).
				var selected = binding.mesh.get_surface_override_material(binding.surface)
				ok = ok and selected == binding.wind
				ok = ok and binding.wind.get_shader_parameter("albedo_texture") == binding.original.albedo_texture
				ok = ok and binding.wind.get_shader_parameter("normal_texture") == binding.original.normal_texture
				ok = ok and binding.wind.get_shader_parameter("orm_texture") == binding.original.roughness_texture
		print("FOLIAGE_WIND bindings ", path, " n=", wind.bindings.size(), " PBR_maps_preserved=", ok)
		plant.queue_free()
	# Quality keys default safely when GraphicsSettings lacks them.
	WindSystem.apply_quality_settings(0, {})
	ok = ok and WindSystem.detail == 0 and is_equal_approx(WindSystem.foliage_density, 1.0)
	WindSystem.apply_quality_settings(1, {})
	ok = ok and WindSystem.detail == 1
	WindSystem.apply_quality_settings(1, {"foliage_wind_detail": 2, "foliage_density": 0.5})
	ok = ok and WindSystem.detail == 2 and is_equal_approx(WindSystem.foliage_density, 0.5)
	WindSystem.apply_quality_settings(2, {"vegetation_interaction": 0})
	ok = ok and not WindSystem.interaction_enabled
	WindSystem.read_graphics()
	var leaves := preload("res://systems/nature/FallingLeaves.gd").new()
	root.add_child(leaves)
	await process_frame # WindDriver enters the tree deferred and subscribes to quality_changed.
	var gs = root.get_node("GraphicsSettings")
	for quality in [0, 1, 2, 3, 4]:
		gs.apply_quality(quality, false)
		leaves._update(0.0)
		ok = ok and leaves.particles.emitting == (quality >= 2)
		ok = ok and WindSystem.interaction_enabled == (quality > 0)
	leaves.queue_free()
	gs.apply_quality(1, false)
	# Presets blend smoothly and emit wind_changed.
	var signals := [0]
	WindSystem.driver().wind_changed.connect(func(_s, _d, _t, _st): signals[0] += 1)
	WindSystem.set_preset(WindSystem.Preset.CALM, 0.0)
	await process_frame
	WindSystem.set_preset(WindSystem.Preset.STORM, 3.0)
	var prev := WindSystem.strength
	var max_step := 0.0
	var prev_blend: float = WindSystem._blend_t
	var continuous := true
	for i in 400:
		await process_frame
		var elapsed: float = WindSystem._blend_t - prev_blend
		var step := absf(WindSystem.strength - prev)
		max_step = maxf(max_step, step)
		# Smoothstep's maximum slope is 1.5; allow frame stalls without hiding jumps.
		continuous = continuous and step <= 1.5 * 2.15 * elapsed + 0.02
		prev_blend = WindSystem._blend_t
		prev = WindSystem.strength
	ok = ok and is_equal_approx(WindSystem.strength, WindSystem.PRESETS[WindSystem.Preset.STORM][0])
	ok = ok and is_equal_approx(WindSystem.storm_intensity, 1.0) and continuous and signals[0] > 0
	print("FOLIAGE_WIND presets storm=%.2f max_step=%.3f signals=%d" % [WindSystem.strength, max_step, signals[0]])
	print("FOLIAGE_WIND_PASS" if ok else "FOLIAGE_WIND_FAIL")
	quit(0 if ok else 1)
