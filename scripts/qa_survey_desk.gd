extends SceneTree
func _init() -> void:
	call_deferred("_verify")
func _verify() -> void:
	var scene := load("res://levels/Chapter1.tscn") as PackedScene
	assert(scene != null)
	var model := load("res://assets/props/camp/survey_fielddesk.glb").instantiate() as Node3D
	root.add_child(model)
	var state := scene.get_state()
	var found := false
	for index in range(state.get_node_count()):
		if state.get_node_name(index) == &"SurveyDeskModel":
			found = true
			for property in range(state.get_node_property_count(index)):
				var name := state.get_node_property_name(index, property)
				if name == &"rotation" or name == &"scale":
					model.set(name, state.get_node_property_value(index, property))
	assert(found)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bounds := mesh.global_transform * mesh.get_aabb()
	assert(bounds.size.distance_to(Vector3(2.4, 0.9, 1.4)) < 0.003)
	assert(bounds.get_center().length() < 0.001)
	var material := mesh.get_active_material(0) as StandardMaterial3D
	assert(material.albedo_texture != null and material.normal_texture != null and material.roughness_texture != null)
	print("SURVEY_DESK_PASS calibrated_dimensions=", bounds.size, " centered=true PBR_maps_present=true")
	model.queue_free()
	await process_frame
	quit()
