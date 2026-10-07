extends SceneTree

func _init() -> void:
	print("--- TESTING MARA MODEL INSTANTIATION IN GODOT ENGINE ---")
	var scene_res = load("res://assets/characters/mara/optimized/CHR_Mara_Optimized.glb")
	if not scene_res:
		printerr("FAILED to load CHR_Mara_Optimized.glb!")
		quit(1)
		return
	
	var inst = scene_res.instantiate()
	if not inst:
		printerr("FAILED to instantiate CHR_Mara_Optimized.glb!")
		quit(1)
		return
		
	print("Successfully instantiated Mara Node:", inst.name, "Class:", inst.get_class())
	root.add_child(inst)
	print("Child count:", inst.get_child_count())
	for c in inst.get_children():
		print("  Child node:", c.name, "Class:", c.get_class())
		if c is MeshInstance3D:
			var aabb = c.get_aabb()
			print("  AABB size:", aabb.size, "position:", aabb.position)
	print("--- MARA GLB INSTANTIATION VERIFIED CLEANLY ---")
	quit(0)
