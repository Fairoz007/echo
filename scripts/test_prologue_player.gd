
extends SceneTree
func _init():
    var scn = load('res://levels/Prologue.tscn')
    var inst = scn.instantiate()
    root.add_child(inst)
    var p = inst.find_child('Player', true, false)
    print('Player found:', p != null)
    print('anim_player:', p.anim_player)
    if p.anim_player:
        print('is_playing:', p.anim_player.is_playing(), 'curr anim:', p.anim_player.current_animation)
    quit(0)
