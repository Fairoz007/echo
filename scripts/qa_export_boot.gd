extends SceneTree
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 var gm = root.get_node("GameManager")
 var sm = root.get_node("SaveManager")
 sm.save_directory = "user://qa_export"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_export"))
 change_scene_to_file("res://ui/MainMenu.tscn")
 await create_timer(0.4).timeout
 current_scene.btn_new_game.pressed.emit()
 await create_timer(1.0).timeout
 if gm.current_chapter != 0 or not get_first_node_in_group("player") or not FileAccess.file_exists(sm.save_path(0)) or not FileAccess.file_exists(sm.save_path(1)):
  push_error("Export New Game or automatic checkpoint failed")
  quit(1)
  return
 gm.return_to_menu()
 await create_timer(0.3).timeout
 if not gm.continue_saved_game(0):
  push_error("Export Continue failed")
  quit(1)
  return
 await create_timer(1.0).timeout
 if not get_first_node_in_group("player"):
  push_error("Export restored player missing")
  quit(1)
  return
 print("QA PASS: packaged New Game, automatic checkpoint, Main Menu and Continue")
 gm.return_to_menu()
 await create_timer(12.0).timeout
 quit(0)

