
extends SceneTree
func _init():
    var glb = load('res://assets/characters/mara/optimized/CHR_Mara_Production.glb')
    var inst = glb.instantiate()
    var anim = inst.find_child('AnimationPlayer', true, false)
    var anim_names = anim.get_animation_list()
    for name in anim_names:
        var a = anim.get_animation(name)
        print('Anim:', name, 'length:', a.length, 'tracks:', a.get_track_count())
        for i in range(min(5, a.get_track_count())):
            print('  track', i, 'path:', a.track_get_path(i))
    quit(0)
