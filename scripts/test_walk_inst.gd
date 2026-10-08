extends SceneTree

func _init() -> void:
    var res = load('res://assets/characters/mara/source/CHR_Mara_Retarget_Walk.glb')
    var inst = res.instantiate()
    print('Instantiated node:', inst.name, 'Class:', inst.get_class())
    for c in inst.get_children():
        print('  Child:', c.name, 'Class:', c.get_class())
        for gc in c.get_children():
            print('    Grandchild:', gc.name, 'Class:', gc.get_class())
    var anim_player = inst.find_child('AnimationPlayer', true, false)
    if anim_player:
        print('AnimationPlayer found! Anims:', anim_player.get_animation_list())
    else:
        print('No AnimationPlayer found in GLB instance')
    quit(0)
