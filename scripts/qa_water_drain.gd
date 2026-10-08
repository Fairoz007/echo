extends SceneTree
func _initialize() -> void:
 call_deferred("_run")
func _stop() -> void:
 for action in ["move_forward", "move_back", "move_left", "move_right"]:
  Input.action_release(action)
func _fail(message: String) -> void:
 _stop()
 printerr("QA FAILED: " + message)
 root.get_node("GameManager").return_to_menu()
 await create_timer(15.0).timeout
 quit(1)
func _run() -> void:
 var gm = root.get_node("GameManager")
 root.get_node("SaveManager").save_directory = "user://qa_water_drain"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_water_drain"))
 gm.load_chapter(6, "res://levels/Chapter6.tscn")
 await create_timer(1.2).timeout
 var player = get_first_node_in_group("player")
 var wheel = current_scene.get_node("TempleMechanisms/SluiceWheel/Interactable3D")
 var reached = false
 for frame in range(1800):
  var offset: Vector3 = wheel.global_position - player.global_position
  offset.y = 0.0
  if offset.length() < 0.25:
   reached = true
   break
  var direction = player.camera_pivot.global_basis.inverse() * offset.normalized()
  _stop()
  Input.action_press("move_right" if direction.x > 0.0 else "move_left", absf(direction.x))
  Input.action_press("move_back" if direction.z > 0.0 else "move_forward", absf(direction.z))
  await physics_frame
 _stop()
 await create_timer(0.15).timeout
 if not reached or player.nearby_interactable != wheel:
  await _fail("Could not physically approach sluice interaction")
  return
 print("QA DRAIN BEGIN")
 var event = InputEventAction.new()
 event.action = "interact"
 event.pressed = true
 Input.parse_input_event(event)
 await process_frame
 event = InputEventAction.new()
 event.action = "interact"
 event.pressed = false
 Input.parse_input_event(event)
 var was_swimming: bool = player.current_state == player.State.SWIM
 var transitions = 0
 var start = Time.get_ticks_msec()
 while Time.get_ticks_msec() - start < 4700:
  await physics_frame
  var swimming: bool = player.current_state == player.State.SWIM
  if swimming != was_swimming:
   transitions += 1
  was_swimming = swimming
 print("QA DRAIN END transitions=", transitions)
 if not current_scene.is_reservoir_drained or not is_equal_approx(current_scene.water_plane.position.y, -3.2) or transitions > 4 or player.current_health <= 0.0:
  await _fail("Drainage did not finish safely or repeatedly changed swimming state")
  return
 print("QA PASS: physical sluice input, actual4s drainage tween, limited water-state transitions and living player")
 gm.return_to_menu()
 await create_timer(15.0).timeout
 quit(0)
