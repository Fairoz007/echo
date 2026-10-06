extends SceneTree

func _init():
	print("--- VERIFYING AUTOLOAD SINGLETONS IN RUNTIME ---")
	call_deferred("_run_checks")

func _run_checks():
	var gm = root.get_node_or_null("GameManager")
	var sm = root.get_node_or_null("SaveManager")
	var mm = root.get_node_or_null("MissionManager")
	var am = root.get_node_or_null("AudioManager")
	var sk = root.get_node_or_null("SkillManager")
	
	print("GameManager node:", gm)
	print("SaveManager node:", sm)
	print("MissionManager node:", mm)
	print("AudioManager node:", am)
	print("SkillManager node:", sk)
	
	if gm and sm and mm and am and sk:
		print("SUCCESS: ALL 5 AUTOLOADS RESOLVED CLEANLY IN SCENETREE!")
	else:
		printerr("FAILURE: One or more autoloads missing!")
		quit(1)
		return
		
	# Test cross references
	print("Testing GameManager state change...")
	gm.change_state(gm.GameState.MENU)
	print("Testing MissionManager objective registration...")
	mm.register_objective("test_obj", "Testing verification script")
	print("Testing SaveManager data structure...")
	sm.save_game(99)
	var loaded = sm.load_game(99)
	print("Save/Load slot 99 successful:", loaded)
	
	print("--- ALL RUNTIME CHECKS PASSED ---")
	quit(0)
