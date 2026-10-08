extends SceneTree

## Scene boot with teardown for scenes that own asynchronous audio/dialogue.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveManager").save_directory = "user://qa_scene_boot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_scene_boot"))
	var arguments = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		quit(1)
		return
	var gm = root.get_node("GameManager")
	var matched := false
	for chapter in range(13):
		if gm.chapter_scene(chapter) == arguments[0]:
			gm.load_chapter(chapter, arguments[0])
			matched = true
			break
	if not matched and change_scene_to_file(arguments[0]) != OK:
		quit(1)
		return
	await create_timer(2.0).timeout
	root.get_node("AudioManager").stop_dialogue()
	change_scene_to_file("res://ui/MainMenu.tscn")
	await create_timer(16.0).timeout
	print("QA PASS: scene boot and asynchronous teardown")
	quit(0)
