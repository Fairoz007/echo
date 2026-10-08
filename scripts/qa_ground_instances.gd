extends SceneTree
func _init() -> void:
	call_deferred("_verify")
func _verify() -> void:
	for chapter in [2, 6]:
		var level := Node3D.new()
		root.add_child(level)
		var art = load("res://systems/CampaignEnvironmentArt.gd").new()
		art.chapter_index = chapter
		level.add_child(art)
		var expected_counts := [42, 270, 480]
		for quality in range(3):
			art.set_graphics_quality(quality)
			var batch: MultiMesh = art.ground_instances.multimesh
			assert(batch.instance_count == expected_counts[quality])
			assert(art.get_child_count() == 1, "One batch node; no individual ground models")
			var material := batch.mesh.surface_get_material(0) as StandardMaterial3D
			assert(material.albedo_texture != null and material.normal_texture != null and material.roughness_texture != null)
			var bounds := AABB()
			for i in range(batch.instance_count):
				# Headless dummy RenderingServer does not retain GPU MultiMesh transforms.
				var box: AABB = art.ground_transforms[i] * batch.mesh.get_aabb()
				bounds = bounds.merge(box) if i > 0 else box
			assert(abs(bounds.position.x + 60.75) < 0.001)
			assert(abs(bounds.end.x - 60.75) < 0.001)
			assert(abs(bounds.position.z + 80.75) < 0.001)
			assert(abs(bounds.end.z - 60.75) < 0.001)
			assert(abs(bounds.get_center().y - (-3.85 if chapter == 6 else -0.05)) < 0.0001)
			var triangles: int = batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
			print("GROUND_BATCH_PASS chapter=",chapter," preset=",quality," nodes=1 instances=",batch.instance_count," source_triangles=",triangles," construction_triangles=",triangles*batch.instance_count," surfaces=",batch.mesh.get_surface_count()," texture_preserved=true bounds=",bounds)
		level.queue_free()
		await process_frame
	quit()
