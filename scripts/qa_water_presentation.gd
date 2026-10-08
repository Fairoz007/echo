extends SceneTree

func _init() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var chapter := load("res://levels/Chapter6.tscn") as PackedScene
	assert(chapter != null, "Chapter6 resource must load")
	var basin := Node3D.new()
	root.add_child(basin)
	var water := load("res://systems/WaterPresentation.gd").new() as Node3D
	water.position.y = 0.4
	basin.add_child(water)
	await process_frame
	var visual := water.get_node("AnimatedWaterSurface") as MeshInstance3D
	assert(visual.mesh is PlaneMesh)
	for quality in range(3):
		water.set_graphics_quality(quality)
		assert(visual.mesh.subdivide_width == [8, 24, 64][quality])
		assert(visual.mesh.subdivide_depth == [8, 24, 64][quality])
	assert(is_equal_approx(visual.global_position.y, 0.8))
	water.position.y = -3.2
	assert(is_equal_approx(visual.global_position.y, -2.8))
	assert(water.find_children("*", "CollisionObject3D", true, false).is_empty())
	var arrays := visual.mesh.surface_get_arrays(0)
	print("WATER_PRESENTATION_PASS initial_surface=0.8 drained_surface=-2.8 visual_only=true triangles=", arrays[Mesh.ARRAY_INDEX].size() / 3)
	basin.queue_free()
	await process_frame
	quit()
