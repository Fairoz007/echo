extends SceneTree

func _init() -> void:
    var res = load('res://assets/characters/mara/source/CHR_Mara_Retarget_Walk.glb')
    var inst = res.instantiate()
    root.add_child(inst)
    var anim_player: AnimationPlayer = inst.find_child('AnimationPlayer', true, false)
    var anim = anim_player.get_animation('walk')
    print('Track count:', anim.get_track_count())
    for t in range(min(10, anim.get_track_count())):
        print('  Track', t, 'path:', anim.track_get_path(t))
    quit(0)
