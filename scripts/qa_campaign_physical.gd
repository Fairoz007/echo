extends SceneTree

## Continuous input route: menu New Game to credits. No teleport or mission edits.
## Known route coordinates guide input; human experience and visual acceptance differ.
var failed := false
var distance_walked := 0.0
var started := 0
var chapter_start := 0
var chapter_end := 12

const ROUTES = {
	0: [["ResonantArtifact/Interactable3D", true], ["ExitTrigger", false]], # relic now at x=2.2, off the centreline
	1: [["CampArea/NadiyaNPC/Interactable3D", true], ["CampArea/EliasNPC/Interactable3D", true], ["CampArea/SurveyTable/Interactable3D", true], ["RidgeArea/SealedPortal/Interactable3D", true], ["RidgeArea/ChapterEndTrigger", false]],
	2: [["HydraulicPuzzle/SluiceLever/Interactable3D", true], ["Sanctuary/InscriptionTablet/Interactable3D", true], ["QA_TabletBypass", false], ["Sanctuary/AbyssTrigger", false]],
	3: [["BridgeStructure/CollapseTrigger", false], ["FissureAbyssTrigger", false]],
	4: [["AbandonedCamp/FieldRadio/Interactable3D", true], ["QA_CampBypass", false], ["ExitTunnel/ExitTrigger", false]],
	5: [["ObservationPerch/DrakeTrigger", false], ["TempleEntrance/ChapterEndTrigger", false]],
	6: [["TempleMechanisms/SluiceWheel/Interactable3D", true], ["QA_RampFootGuide", false], ["TempleSanctum/ExitTrigger", false]],
	7: [["QA_MonumentBypass", false], ["CentralPlaza/HistoryMural/Interactable3D", true], ["OptionalTomb/TombTrigger", false], ["RoyalCauseway/CausewayExitTrigger", false]],
	8: [["SurvivorCamp/InjuredElias/Interactable3D", true], ["Passage/AdrianConfrontationTrigger", false]],
	9: [["CollapsingRoute/TremorTrigger", false], ["VaultThreshold/VaultGateTrigger", false]],
	10: [["QA_NodeSouthBypass", false], ["CentralPlatform/DrakeTrigger", false], ["ResonanceChamber/NodeSouth/Interactable3D", true], ["ResonanceChamber/NodeEast/Interactable3D", true], ["ResonanceChamber/NodeNorth/Interactable3D", true], ["ResonanceChamber/NodeWest/Interactable3D", true], ["CentralPlatform/EscapeTrigger", false]],
	11: [["DaylightRidge/DaylightExitTrigger", false]]
}

func _init() -> void:
	# Runs share the desktop with an open editor; a stray window close must not end the QA.
	auto_accept_quit = false
	call_deferred("_run")

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		print("QA KEY SPY: window close request ignored at t=", Time.get_ticks_msec())

func _stop_moving() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "fire", "aim"]:
		Input.action_release(action)

func _fail(message: String) -> void:
	failed = true
	_stop_moving()
	printerr("PHYSICAL CAMPAIGN BLOCKER: " + message)
	root.get_node("GameManager").return_to_menu()
	await create_timer(12.0).timeout
	quit(1)

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-start-chapter="):
			chapter_start = argument.get_slice("=", 1).to_int()
		if argument.begins_with("--qa-end-chapter="):
			chapter_end = argument.get_slice("=", 1).to_int()
	var spy = preload("res://dev/levelb_key_spy.gd").new()
	spy.name = "QAKeySpy"
	root.add_child.call_deferred(spy)
	root.get_node("SaveManager").save_directory = "user://qa_campaign_physical"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_campaign_physical"))
	change_scene_to_file("res://ui/MainMenu.tscn")
	await process_frame
	await process_frame
	started = Time.get_ticks_msec()
	if chapter_start == 0:
		current_scene.btn_new_game.pressed.emit()
	else:
		var gm = root.get_node("GameManager")
		gm.load_chapter(chapter_start, gm.chapter_scene(chapter_start))
	await create_timer(0.8).timeout
	for chapter in range(chapter_start, chapter_end):
		# Each chapter opens behind a story card and builds procedural geometry on load;
		# wait for GAMEPLAY and the first route node before driving input.
		var gm := root.get_node("GameManager")
		for i in 160:
			if gm.current_chapter == chapter and gm.current_state == gm.GameState.GAMEPLAY and current_scene and ROUTES.has(chapter) and current_scene.get_node_or_null(ROUTES[chapter][0][0]):
				break
			await create_timer(0.25).timeout
		if root.get_node("GameManager").current_chapter != chapter:
			await _fail("Expected chapter %d before route" % chapter)
			return
		print("PHYSICAL ROUTE chapter ", chapter)
		if chapter == 6:
			var waypoint = Node3D.new()
			waypoint.name = "QA_RampFootGuide"
			current_scene.add_child(waypoint)
			waypoint.position = Vector3(0, -3.5, -11)
		# Guides steer around solid props that now sit on straight-line routes.
		var guides := {10: [["QA_NodeSouthBypass", Vector3(2.6, 0, 18)]], 2: [["QA_TabletBypass", Vector3(2.4, 0, -26.5)]], 4: [["QA_CampBypass", Vector3(2.8, 0, -1.5)]], 7: [["QA_MonumentBypass", Vector3(3.8, 0, 0.5)]]}
		for g in guides.get(chapter, []):
			var guide = Node3D.new()
			guide.name = g[0]
			current_scene.add_child(guide)
			guide.position = g[1]
		if chapter == 5:
			for enemy_path in ["Enemies/EnemyMercenary1", "Enemies/EnemyMercenary2"]:
				if not await _fight(enemy_path):
					return
		# If the chapter scene is reloaded mid-route (quick-load / checkpoint restart), _visit
		# returns early; restart the route on the fresh scene instead of skipping steps
		# (e.g. Ch6 would otherwise head for the exit with the basin undrained).
		var attempts := 0
		while true:
			var route_scene = current_scene
			var steps: Array = ROUTES[chapter]
			var reloaded := false
			for si in steps.size():
				if not await _visit(steps[si][0], steps[si][1]):
					return
				# Leaving the scene after the last step is the normal chapter exit.
				if si < steps.size() - 1 and current_scene != route_scene:
					reloaded = true
					break
			if not reloaded:
				break
			await create_timer(1.0).timeout
			if root.get_node("GameManager").current_chapter != chapter:
				break
			attempts += 1
			var p = get_first_node_in_group("player")
			print("PHYSICAL chapter ", chapter, " reloaded mid-route (attempt ", attempts, "); state=", root.get_node("GameManager").current_state, " health=", p.current_health if p else -1.0)
			if attempts > 2:
				await _fail("Chapter %d kept reloading mid-route" % chapter)
				return
			for i in 160:
				if current_scene and current_scene.get_node_or_null(ROUTES[chapter][0][0]) and root.get_node("GameManager").current_state == root.get_node("GameManager").GameState.GAMEPLAY:
					break
				await create_timer(0.25).timeout
			if chapter == 6 and current_scene.get_node_or_null("QA_RampFootGuide") == null:
				var wp = Node3D.new()
				wp.name = "QA_RampFootGuide"
				current_scene.add_child(wp)
				wp.position = Vector3(0, -3.5, -11)
		_stop_moving()
		for frame in range(1800):
			await physics_frame
			if root.get_node("GameManager").current_chapter == chapter + 1:
				break
		if root.get_node("GameManager").current_chapter != chapter + 1:
			await _fail("Chapter %d exit did not progress; active objectives=%s" % [chapter, root.get_node("MissionManager").active_objectives])
			return
		await create_timer(0.3).timeout
	var route_elapsed = (Time.get_ticks_msec() - started) / 1000.0
	if chapter_end == 12:
		await create_timer(27.0).timeout
		current_scene.btn_menu.pressed.emit()
	else:
		root.get_node("GameManager").return_to_menu()
	# The next chapter may still be streaming in; poll and retry instead of a fixed wait.
	for i in 40:
		await create_timer(1.0).timeout
		if current_scene and current_scene.name == "MainMenu":
			break
		if i == 15 and chapter_end != 12:
			root.get_node("GameManager").return_to_menu()
	if current_scene == null or current_scene.name != "MainMenu":
		await _fail("Credits return did not reach Main Menu")
		return
	if chapter_start == 0 and chapter_end == 12:
		print("QA PASS: continuous physical campaign through credits and Main Menu, distance %.1fm, route elapsed %.1fs; not a ten-hour content claim" % [distance_walked, route_elapsed])
	else:
		print("QA PASS: scoped physical chapters %d-%d, distance %.1fm, elapsed %.1fs; not a full campaign claim" % [chapter_start, chapter_end - 1, distance_walked, route_elapsed])
	quit(0)

func _visit(path: String, interact: bool, radius: float = 0.9) -> bool:
	var scene = current_scene
	var target = scene.get_node_or_null(path)
	if not target:
		await _fail("Missing route node " + path)
		return false
	var player = get_first_node_in_group("player")
	var last: Vector3 = player.global_position
	for frame in range(1800):
		if not is_instance_valid(target) or current_scene != scene:
			return true
		if player.current_health <= 0.0:
			await _fail("Mara died while approaching " + path)
			return false
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		# Interactables inside solid props (pedestal, lever, radio, mural) are selected by proximity,
		# so an interaction target is reached once the player has it selected.
		var selected: bool = interact and player.nearby_interactable == target and offset.length() < 2.0
		if offset.length() < (0.25 if interact else radius) or selected:
			_stop_moving()
			await create_timer(0.15).timeout
			if interact:
				if player.nearby_interactable != target:
					await _fail("Interaction selection blocked at " + path + "; player=" + str(player.global_position) + "; target=" + str(target.global_position) + "; nearby=" + str(player.nearby_interactable.get_path() if player.nearby_interactable else "none"))
					return false
				var event = InputEventAction.new()
				event.action = "interact"
				event.pressed = true
				Input.parse_input_event(event)
				await process_frame
				event = InputEventAction.new()
				event.action = "interact"
				event.pressed = false
				Input.parse_input_event(event)
				await create_timer(0.2).timeout
			print("PHYSICAL reached ", path, " at ", player.global_position)
			return true
		var direction: Vector3 = player.camera_pivot.global_basis.inverse() * offset.normalized()
		_stop_moving()
		Input.action_press("move_right" if direction.x > 0.0 else "move_left", absf(direction.x))
		Input.action_press("move_back" if direction.z > 0.0 else "move_forward", absf(direction.z))
		await physics_frame
		if not is_instance_valid(player) or not player.is_inside_tree() or current_scene != scene:
			return true
		distance_walked += player.global_position.distance_to(last)
		last = player.global_position
	await _fail("Cannot physically reach " + path + "; position=" + str(player.global_position))
	return false

func _fight(path: String) -> bool:
	var enemy = current_scene.get_node_or_null(path)
	if not enemy:
		return true
	if not await _visit(path, false, 12.0):
		return false
	var player = get_first_node_in_group("player")
	var pivot = player.camera_pivot
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Mouse look only applies while captured; --headless cannot capture, so aim never moves.
		await _fail("Mouse not captured (headless?); combat aim cannot be driven. Run with a window (e.g. xvfb-run).")
		return false
	for frame in range(600):
		if not is_instance_valid(enemy) or enemy.current_health <= 0.0:
			_stop_moving()
			return true
		if player.current_health <= 0.0:
			await _fail("Mara died in patrol combat " + path)
			return false
		var camera = root.get_camera_3d()
		var direction: Vector3 = (enemy.global_position + Vector3(0, 1.2, 0) - camera.global_position).normalized()
		var desired_yaw = atan2(-direction.x, -direction.z)
		var desired_pitch = asin(direction.y)
		var motion = InputEventMouseMotion.new()
		motion.position = Vector2(DisplayServer.window_get_size()) * 0.5
		motion.global_position = motion.position
		var logical_delta = Vector2(-wrapf(desired_yaw - pivot.yaw, -PI, PI) / pivot.mouse_sensitivity, -(desired_pitch - pivot.pitch) / pivot.mouse_sensitivity)
		motion.relative = logical_delta
		motion.screen_relative = logical_delta
		Input.parse_input_event(motion)
		await process_frame
		if frame % 60 == 0:
			var ray = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 80.0)
			ray.exclude = [player.get_rid()]
			var hit = player.get_world_3d().direct_space_state.intersect_ray(ray)
			print("AIM debug yaw=", pivot.yaw, " desired=", desired_yaw, " pitch=", pivot.pitch, " desired=", desired_pitch, " hit=", hit.get("collider"), " ammo=", player.ammunition)
		# Ch5 cover (sandbags/crates) can block the shot from the 12 m stop: advance toward
		# the enemy while line of sight is blocked instead of emptying the magazine into cover.
		if frame % 10 == 0:
			var los = PhysicsRayQueryParameters3D.create(camera.global_position, enemy.global_position + Vector3(0, 1.2, 0))
			los.exclude = [player.get_rid()]
			var blocker = player.get_world_3d().direct_space_state.intersect_ray(los).get("collider")
			var clear: bool = blocker == null or blocker == enemy or (blocker is Node and enemy.is_ancestor_of(blocker))
			Input.action_release("move_forward")
			if not clear and player.global_position.distance_to(enemy.global_position) > 3.0:
				Input.action_press("move_forward")
		Input.action_press("aim")
		Input.action_press("fire")
		await physics_frame
	await _fail("Patrol enemy could not be defeated using aim/fire input " + path)
	return false


