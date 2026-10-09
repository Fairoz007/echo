extends SceneTree
## DEV ONLY: LOW-quality frame sequences for movement review + state metrics.
## godot ... -s res://dev/seq_capture.gd -- --quality=1
## Output: screenshots/movement/seq_review/<case>_fNN.png ; prints "SEQ <case> ..." lines.
const OUT := "res://screenshots/movement/seq_review/"
var course
var p
var cam
var c3: Camera3D
var view_off := Vector3(0, 0.5, 4.5)
var states := {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gs = root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_quality"):
		gs.apply_quality(1, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 20:
		await physics_frame
	p = course.player
	cam = course.camera_rig
	c3 = Camera3D.new()
	c3.fov = 45.0
	root.add_child(c3)
	c3.make_current()
	if "--only-swim" in OS.get_cmdline_user_args():
		await _seq("swim_entry", "pool", Vector3(2.6, 2.55, 0), ["move_forward", "walk"], 2, 6)
		quit()
		return
	await _seq("walk", "flat", Vector3(-34, 0, 0), ["move_forward", "walk"], 40, 6)
	await _seq("run", "flat", Vector3(-34, 0, 0), ["move_forward"], 40, 4)
	await _seq("sprint", "flat", Vector3(-34, 0, 0), ["move_forward", "sprint"], 40, 3)
	await _turn_in_place()
	await _turn_180()
	await _stop()
	await _seq("slope", "slope_15", Vector3(-3, 0, 0), ["move_forward"], 10, 5)
	await _seq("steps", "stairs", Vector3(-3, 0, 0), ["move_forward"], 10, 5)
	await _jump()
	await _seq("swim_entry", "pool", Vector3(2.6, 2.55, 0), ["move_forward", "walk"], 2, 6)
	quit()

func _release() -> void:
	for a in ["move_forward", "move_back", "move_right", "move_left", "sprint", "walk", "jump"]:
		Input.action_release(a)

func _reset(lane: String, off: Vector3) -> void:
	_release()
	p.global_position = course.lane_start(lane) + off
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	p.current_state = Player.State.IDLE
	cam.yaw = -PI * 0.5
	cam.snap_to_target()
	states = {}
	for i in 20:
		await physics_frame

func _tick() -> void:
	await physics_frame
	var k: String = Player.State.keys()[p.current_state]
	states[k] = states.get(k, 0) + 1
	var t: Vector3 = p.global_position + Vector3(0, 0.9, 0)
	c3.global_position = t + view_off
	c3.look_at(t, Vector3.UP)

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))

func _capture(name: String, every: int, n := 12) -> void:
	for i in n:
		for k in every:
			await _tick()
		await _shot("%s_f%02d" % [name, i])

func _report(name: String) -> void:
	print("SEQ %s states=%s speed=%.2f anim=%s scale=%.2f" % [name, states, p.horizontal_speed, p.anim_state, p.get_animation_playback_scale()])

func _seq(name: String, lane: String, off: Vector3, keys: Array, warm: int, every: int) -> void:
	await _reset(lane, off)
	for k in keys:
		Input.action_press(k)
	for i in warm:
		await _tick()
	await _capture(name, every)
	_report(name)

func _turn_in_place() -> void:
	await _reset("flat", Vector3(-34, 0, 0))
	view_off = Vector3(3.0, 0.8, 3.0)
	Input.action_press("move_left") # 90 deg from standstill
	await _capture("turn_in_place", 2)
	_report("turn_in_place")
	view_off = Vector3(0, 0.5, 4.5)

func _turn_180() -> void:
	await _reset("flat", Vector3(-34, 0, 0))
	Input.action_press("move_forward")
	for i in 50:
		await _tick()
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _capture("turn_180", 3)
	_report("turn_180")

func _stop() -> void:
	await _reset("flat", Vector3(-34, 0, 0))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 60:
		await _tick()
	_release()
	await _capture("stop", 3)
	_report("stop")

func _jump() -> void:
	await _reset("flat", Vector3(-34, 0, 0))
	Input.action_press("move_forward")
	for i in 40:
		await _tick()
	Input.action_press("jump")
	await _capture("jump", 4)
	_report("jump")
