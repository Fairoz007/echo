extends SceneTree
## Regenerates res://ui/theme/echoes_theme.tres from ui/GameTheme.gd (the code source of truth).
func _init() -> void:
	var err := ResourceSaver.save(preload("res://ui/GameTheme.gd").get_theme(), "res://ui/theme/echoes_theme.tres")
	print("[UITHEME] save ", err)
	quit(err)
