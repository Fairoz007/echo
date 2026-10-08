extends SceneTree

func _init() -> void:
    var res = load('res://assets/characters/mara/source/CHR_Mara_Retarget_Walk.glb')
    var inst = res.instantiate()
    root.add_child(inst)
    var anim_player: AnimationPlayer = inst.find_child('AnimationPlayer', true, false)
    anim_player.play('walk')
    print('Is playing:', anim_player.is_playing(), 'Current animation:', anim_player.current_animation)
    quit(0)
