extends SceneTree

func _init() -> void:
    var pro = load('res://levels/Prologue.tscn').instantiate()
    root.add_child(pro)
    var cam = pro.find_child('Camera3D', true, false)
    print('Camera3D global_transform:', cam.global_transform)
    print('Camera3D rotation_degrees:', cam.global_rotation_degrees)
    quit(0)
