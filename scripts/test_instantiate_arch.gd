extends SceneTree

func _init() -> void:
    for path in ['res://assets/models/arch_wall_vaelor.glb', 'res://assets/models/arch_floor_stone.glb', 'res://assets/models/arch_glass_barrier.glb', 'res://assets/characters/mara/optimized/CHR_Mara_Animated.glb']:
        var res = load(path)
        if res:
            var inst = res.instantiate()
            print('Successfully loaded and instantiated:', path, 'Node:', inst.name)
        else:
            printerr('Failed to load:', path)
    quit(0)
