extends SceneTree

func _init() -> void:
    var res = load('res://assets/characters/mara/source/CHR_Mara_Retarget_Walk.glb')
    var inst = res.instantiate()
    root.add_child(inst)
    var mesh = inst.find_child('*', true, false)
    for c in inst.get_children():
        for gc in c.get_children():
            if gc is MeshInstance3D or gc is Skeleton3D:
                print('Node:', gc.name, 'class:', gc.get_class())
                for ggc in gc.get_children():
                    print('  Subnode:', ggc.name, 'class:', ggc.get_class())
                    if ggc is MeshInstance3D:
                        print('  AABB size:', ggc.get_aabb().size, 'position:', ggc.get_aabb().position)
    quit(0)
