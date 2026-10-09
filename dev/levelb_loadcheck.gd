extends SceneTree
## Headless load check for the Level B chapters: loads each, idles 3 s, reports node counts.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm := root.get_node("GameManager")
	root.get_node("SaveManager").save_directory = "user://qa_levelb_load"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_levelb_load"))
	for c in [1, 5, 6, 8, 12]:
		change_scene_to_file(gm.chapter_scene(c))
		await create_timer(3.0).timeout
		var d := current_scene.get_node_or_null("LevelBDressing") if current_scene else null
		print("LOADED chapter ", c, " scene=", current_scene.name if current_scene else "null", " dressing_children=", d.get_child_count() if d else -1)
	gm.return_to_menu()
	await create_timer(0.5).timeout
	quit(0)
