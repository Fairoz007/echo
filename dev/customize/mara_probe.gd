extends SceneTree
func _init() -> void:
	var m: Node = (load("res://assets/characters/mara/optimized/CHR_Mara_Game_LOD0.glb") as PackedScene).instantiate()
	root.add_child(m)
	_dump(m, "")
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	for i in sk.get_bone_count():
		print("BONE ", i, " ", sk.get_bone_name(i), " ", sk.get_bone_global_rest(i).origin, " basisX ", sk.get_bone_global_rest(i).basis.x.normalized(), " Y ", sk.get_bone_global_rest(i).basis.y.normalized())
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap: print("ANIMS ", ap.get_animation_list())
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", mi.name, " aabb ", mi.get_aabb(), " mat ", mi.mesh.surface_get_material(0))
	quit()
func _dump(n: Node, ind: String) -> void:
	print(ind, n.name, " <", n.get_class(), "> ", (n as Node3D).transform if n is Node3D else "")
	for c in n.get_children(): _dump(c, ind + "  ")
