extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu = load("res://ui/MainMenu.gd").new()
	for chapter in range(13):
		var scene: String = menu.chapter_scene(chapter)
		if scene.is_empty() or not ResourceLoader.exists(scene):
			printerr("QA FAILED: Continue destination for chapter ", chapter)
			quit(1)
			return
	if menu.chapter_scene(5) != "res://levels/Chapter5.tscn" or not menu.chapter_scene(99).is_empty():
		printerr("QA FAILED: Continue mapping")
		quit(1)
		return
	menu.free()
	var skills = root.get_node("SkillManager")
	skills.add_xp(100)
	if not skills.unlock_skill("hunter_silent_step"):
		quit(1)
		return
	skills.add_xp(1)
	if skills.available_skill_points != 0:
		printerr("QA FAILED: spent point regranted below next threshold")
		quit(1)
		return
	skills.add_xp(99)
	if skills.available_skill_points != 1:
		printerr("QA FAILED: next threshold did not grant one point")
		quit(1)
		return
	print("QA PASS: all 13 Continue chapter destinations and spent skill point accounting")
	quit(0)
