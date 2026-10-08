extends SceneTree

## Simulation Test: Moves player to Relic, interacts, then moves player to Exit trigger
func _init():
	call_deferred("_start_playtest")

func _start_playtest():
	root.get_node("SaveManager").save_directory = "user://qa_smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_smoke"))
	print("--- BEGINNING SCRIPTED TELEPORT/INTERACTION INTEGRATION: PROLOGUE ---")
	change_scene_to_file("res://levels/Prologue.tscn")
	
	# Wait for scene to load
	await create_timer(1.0).timeout
	var player = root.get_node_or_null("Prologue/Player")
	var hud = root.get_node_or_null("Prologue/HUD")
	var relic_interactable = root.get_node_or_null("Prologue/ResonantArtifact/Interactable3D")
	var exit_trigger = root.get_node_or_null("Prologue/ExitTrigger")
	
	print("Player located:", player != null)
	print("HUD located:", hud != null)
	print("Relic interactable located:", relic_interactable != null)
	print("Exit trigger located:", exit_trigger != null)
	
	if not player or not relic_interactable or not exit_trigger:
		printerr("TEST FAILED: Crucial nodes not found in Prologue!")
		quit(1)
		return
		
	# 1. Walk player towards relic (-12 Z)
	print("Step 1: Teleporting Mara to acoustic relic for integration check...")
	player.global_position = Vector3(0, 1.0, -11.5)
	
	# 2. Trigger interaction with relic
	print("Step 2: Pressing interact on Vaelor Acoustic Key...")
	relic_interactable.trigger_interaction(player)
	
	# Check objectives
	await create_timer(0.5).timeout
	var mm = root.get_node("MissionManager")
	var gm = root.get_node("GameManager")
	var is_explored = mm.completed_objectives.has("obj_prologue_explore")
	var has_exit_obj = mm.active_objectives.has("obj_prologue_exit")
	print("Objective 'obj_prologue_explore' completed:", is_explored)
	print("Objective 'obj_prologue_exit' active:", has_exit_obj)
	
	if not is_explored or not has_exit_obj:
		printerr("TEST FAILED: Objectives did not update correctly after interaction!")
		quit(1)
		return
		
	# 3. Walk player to Exit Trigger (-26 Z)
	print("Step 3: Moving Mara to monolithic door threshold...")
	player.global_position = Vector3(0, 1.0, -26.0)
	
	# Wait for transition timeout
	print("Step 4: Awaiting chapter transition into Chapter 1...")
	await create_timer(4.0).timeout
	
	var cur_chapter = gm.current_chapter
	print("Current chapter registered in GameManager:", cur_chapter)
	
	if cur_chapter == 1:
		print("--- PROLOGUE SCRIPTED INTERACTION/TRANSITION INTEGRATION PASSED ---")
		gm.return_to_menu()
		await create_timer(16.0).timeout
		quit(0)
	else:
		printerr("TEST FAILED: Did not transition to Chapter 1! Current chapter:", cur_chapter)
		quit(1)
