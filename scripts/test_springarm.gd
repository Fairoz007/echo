extends SceneTree

func _init() -> void:
    var pro = load('res://levels/Prologue.tscn').instantiate()
    root.add_child(pro)
    var sa = pro.find_child('SpringArm3D', true, false)
    var cam = pro.find_child('Camera3D', true, false)
    print('SpringArm3D position:', sa.position, 'rotation:', sa.rotation)
    print('Camera3D position:', cam.position, 'rotation:', cam.rotation)
    print('Camera3D global_position:', cam.global_position)
    quit(0)
