extends SceneTree

func _init() -> void:
    var res = load('res://assets/characters/mara/optimized/CHR_Mara_Production.glb')
    var inst = res.instantiate()
    root.add_child(inst)
    var anim_player: AnimationPlayer = inst.find_child('AnimationPlayer', true, false)
    print('Available animations in CHR_Mara_Production:', anim_player.get_animation_list())
    anim_player.play('idle')
    print('Played idle. Is playing:', anim_player.is_playing())
    anim_player.play('walk')
    print('Played walk. Is playing:', anim_player.is_playing())
    quit(0)
