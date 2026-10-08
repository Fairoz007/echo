extends SceneTree
## DEV ONLY automated movement measurements on dev/MovementTestCourse.tscn.
## godot --headless --path . -s res://dev/movement_tests.gd        (measurements)
## godot --path . -s res://dev/movement_tests.gd -- --shots          (also screenshots)

var course
var p: Player
var cam: CameraController
var results := []
var failures := 0
var shots := false
const SHOT_DIR := "res://screenshots/movement/"
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "walk", "dive"]

func _init() -> void:
	shots = "--shots" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _release_all() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)

func _reset(lane: String, offset := Vector3.ZERO) -> void:
	_release_all()
	p.global_position = course.lane_start(lane) + offset
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	p.current_state = Player.State.IDLE
	p._set_crouch(false)
	cam.yaw = -PI * 0.5
	cam.snap_to_target()
	await _frames(20)

func _record(name: String, value, ok: bool, note := "") -> void:
	results.append([name, str(value), "PASS" if ok else "FAIL", note])
	if not ok:
		failures += 1
	print("%-34s %-28s %s %s" % [name, str(value), "PASS" if ok else "FAIL", note])

func _shot(name: String) -> void:
	if not shots:
		return
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	img.save_png(ProjectSettings.globalize_path(SHOT_DIR + name + ".png"))

func _run_for(action_list: Array, seconds: float) -> Dictionary:
	for a in action_list:
		Input.action_press(a)
	var max_y := -INF
	var max_angle := 0.0
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		max_y = maxf(max_y, p.global_position.y)
		var hv := Vector3(p.velocity.x, 0, p.velocity.z)
		if hv.length() > 0.5:
			max_angle = maxf(max_angle, rad_to_deg(p.get_facing_forward().angle_to(hv)))
	for a in action_list:
		Input.action_release(a)
	return {"max_y": max_y, "max_angle": max_angle}

func _run() -> void:
	var gm = root.get_node_or_null("GameManager")
	if gm and "current_state" in gm:
		gm.current_state = gm.GameState.GAMEPLAY
	paused = false
	course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	await _frames(10)
	p = course.player
	cam = course.camera_rig
	print("=== MARA MOVEMENT TESTS ===")
	print("clip mapping: ", p.get_clip_mapping())
	print("clip cycle speeds (m/s @1x): ", p.get_clip_speeds())
	var skel_h := _visual_height()
	_record("visual height (m)", "%.3f" % skel_h, absf(skel_h - 1.7) < 0.05)
	_record("capsule r/h (m)", "%.2f / %.2f" % [p._capsule.radius, p._capsule.height], absf(p._capsule.height - 1.72) < 0.01)
	await _test_speeds()
	await _test_jump()
	await _test_steps()
	await _test_slopes()
	await _test_obstacles()
	await _test_mantle_climb()
	await _test_crouch()
	await _test_swim()
	await _test_camera()
	print("=== %d results, %d failures ===" % [results.size(), failures])
	_release_all()
	quit(1 if failures > 0 else 0)

func _visual_height() -> float:
	var lo := INF
	var hi := -INF
	for m in p.visual_mesh.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (p.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		lo = minf(lo, b.position.y)
		hi = maxf(hi, b.end.y)
	return hi - lo

func _test_speeds() -> void:
	for mode in [["walk", ["move_forward", "walk"], p.walk_speed], ["run", ["move_forward"], p.run_speed], ["sprint", ["move_forward", "sprint"], p.sprint_speed]]:
		await _reset("flat", Vector3(-30, 0, 0))
		for a in mode[1]:
			Input.action_press(a)
		var t := 0.0
		var t95 := -1.0
		while t < 2.5:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if t95 < 0.0 and p.horizontal_speed >= mode[2] * 0.95:
				t95 = t
		var speed := p.horizontal_speed
		var scale := p.get_animation_playback_scale()
		var slide := await _foot_slide(150)
		_record("%s planted-foot slide (m/s)" % mode[0], "%.3f" % slide, slide < 0.35, "stance-foot world speed, worst foot")
		if mode[0] == "run":
			await _shot("01_run_flat")
		var start := p.global_position
		_release_all()
		t = 0.0
		while p.horizontal_speed > 0.02 and t < 3.0:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		var stop_dist := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
		_record("%s speed (m/s)" % mode[0], "%.2f" % speed, absf(speed - mode[2]) < 0.05)
		_record("%s 0->95%% time (s)" % mode[0], "%.2f" % t95, t95 > 0.0 and t95 < 0.6)
		_record("%s stop time/dist" % mode[0], "%.2fs / %.2fm" % [t, stop_dist], t < 0.5)
		_record("%s anim playback scale" % mode[0], "%.2f" % scale, true, "walk clip 1.105 m/s @1x")
	# Reversal: never run backwards
	await _reset("flat", Vector3(-30, 0, 0))
	var r1: Dictionary = await _run_for(["move_forward"], 1.5)
	var r2: Dictionary = await _run_for(["move_back"], 1.5)
	_record("180 turn max facing/vel angle", "%.1f deg" % maxf(r1.max_angle, r2.max_angle), maxf(r1.max_angle, r2.max_angle) < 90.0)

## Stance slide: for each foot, mean horizontal world speed over the 20% of frames in
## which that foot is lowest (its stance). 0 = perfectly planted.
func _foot_slide(frames_n: int) -> float:
	var sk: Skeleton3D = p.visual_mesh.find_child("Skeleton3D", true, false)
	if not sk:
		return -1.0
	var worst := 0.0
	var samples := {"L_Foot": [], "R_Foot": []}
	var prev := {}
	for i in frames_n:
		await physics_frame
		for b in samples:
			var w: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
			if prev.has(b):
				var d: Vector3 = w - prev[b]
				samples[b].append([w.y, Vector2(d.x, d.z).length() * Engine.physics_ticks_per_second])
			prev[b] = w
	for b in samples:
		var arr: Array = samples[b]
		arr.sort_custom(func(a, c): return a[0] < c[0])
		var k := maxi(1, arr.size() / 5)
		var total := 0.0
		for i in k:
			total += arr[i][1]
		worst = maxf(worst, total / k)
	return worst

func _test_jump() -> void:
	await _reset("flat", Vector3(-30, 0, 0))
	var y0 := p.global_position.y
	Input.action_press("jump")
	var t := 0.0
	var apex := y0
	var left := false
	while t < 3.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		apex = maxf(apex, p.global_position.y)
		if not p.is_on_floor():
			left = true
		elif left:
			break
	Input.action_release("jump")
	_record("jump apex held (m)", "%.3f" % (apex - y0), apex - y0 > 0.95 and apex - y0 < 1.25)
	_record("jump airtime held (s)", "%.2f" % t, t < 1.0)
	await _frames(20)
	# Tap jump
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	apex = y0
	for i in 90:
		await physics_frame
		apex = maxf(apex, p.global_position.y)
	_record("jump apex tapped (m)", "%.3f" % (apex - y0), apex - y0 < 0.75)
	# Coyote: run off the stair top (y 1.44, edge x 9.4) and jump 0.08 s late.
	await _reset("stairs", Vector3(7.5, 1.44, 0))
	Input.action_press("move_forward")
	var off_time := -1.0
	t = 0.0
	var jumped := false
	var peak := -INF
	while t < 2.5:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if off_time < 0.0 and not p.is_on_floor() and p.global_position.x > 9.0:
			off_time = t
		if off_time > 0.0 and not jumped and t - off_time >= 0.08:
			Input.action_press("jump")
			jumped = true
		if jumped:
			peak = maxf(peak, p.global_position.y)
	_release_all()
	_record("coyote jump 0.08s after edge", "peak y %.2f" % peak, peak > 1.44 + 0.5)
	# Jump buffer: press 0.1 s before landing from a fall.
	await _reset("flat", Vector3(-30, 3.0, 0))
	var pressed := false
	var rejump := false
	for i in 200:
		await physics_frame
		if not pressed and p.velocity.y < 0 and p.global_position.y < 0.02 + absf(p.velocity.y) * 0.1:
			Input.action_press("jump")
			pressed = true
		if pressed and p.velocity.y > 2.0:
			rejump = true
			break
	_release_all()
	_record("jump buffer (pressed 0.1s early)", rejump, rejump)
	# Hard landing from 4 m
	await _reset("flat", Vector3(-30, 4.0, 0))
	await _frames(90)
	_record("landing impact from 4 m (m/s)", "%.2f hard=%s" % [p.last_landing_speed, p.last_landing_speed >= p.hard_landing_speed], p.last_landing_speed >= p.hard_landing_speed)

func _test_steps() -> void:
	for pair in [["step_015", 0.15, true], ["step_030", 0.30, true], ["step_050", 0.50, false]]:
		await _reset(pair[0])
		var sr: Dictionary = await _run_for(["move_forward", "walk"] if pair[0] == "step_015" else ["move_forward"], 4.0 if pair[0] == "step_015" else 1.6)
		var on_top: bool = absf(sr.max_y - pair[1]) < 0.06
		_record("%s climbed (walk into it)" % pair[0], "max y=%.2f x=%.2f" % [sr.max_y, p.global_position.x], on_top == pair[2], "expect %s" % ("up" if pair[2] else "blocked"))
		if pair[0] == "step_030":
			await _shot("02_step_030")
	await _reset("stairs")
	await _run_for(["move_forward"], 3.0)
	_record("stairs 8x0.18 ascended", "y=%.2f" % p.global_position.y, absf(p.global_position.y - 1.44) < 0.06)
	await _reset("stairs", Vector3(9.0, 1.44, 0))
	p.facing_yaw = PI * 0.5
	cam.yaw = PI * 0.5
	await _frames(5)
	await _run_for(["move_forward"], 3.0)
	_record("stairs descended (no launch)", "y=%.2f" % p.global_position.y, p.global_position.y < 0.05)

func _test_slopes() -> void:
	for deg in [15, 30, 45, 60]:
		await _reset("slope_%d" % deg)
		var r: Dictionary = await _run_for(["move_forward"], 4.0)
		var climbed: float = r.max_y
		var expect_up: bool = deg < 44
		var ok: bool = (climbed > 1.5) if expect_up else (climbed < 0.6)
		_record("slope %d deg max height" % deg, "%.2f m (end y %.2f)" % [climbed, p.global_position.y], ok, "expect %s" % ("walkable" if expect_up else "blocked"))
		if deg == 45:
			await _shot("03_slope_45_blocked")

func _test_obstacles() -> void:
	await _reset("wall")
	await _run_for(["move_forward"], 2.0)
	_record("4 m wall blocks", "x=%.2f" % p.global_position.x, p.global_position.x < 4.0)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(5)
	Input.action_release("jump")
	await _frames(70)
	_release_all()
	_record("4 m wall: jump does not mantle", "y=%.2f x=%.2f" % [p.global_position.y, p.global_position.x], p.global_position.y < 0.1 and p.global_position.x < 4.0)
	await _reset("rock_small")
	await _run_for(["move_forward"], 2.0)
	_record("small rock 0.25 stepped over", "x=%.2f" % p.global_position.x, p.global_position.x > 5.5)
	await _reset("rock_large")
	await _run_for(["move_forward"], 2.0)
	_record("large rock 0.9 blocks walking", "x=%.2f y=%.2f" % [p.global_position.x, p.global_position.y], p.global_position.x < 4.0 and p.global_position.y < 0.1)
	await _shot("04_large_rock_blocked")

func _jump_mantle(lane: String, expected_top: float, label: String) -> void:
	await _reset(lane, Vector3(3.0, 0, 0))
	Input.action_press("move_forward")
	await _frames(15)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	var saw_mantle := false
	for i in 90:
		await physics_frame
		if p.current_state == Player.State.MANTLE:
			saw_mantle = true
		elif saw_mantle:
			_release_all()
	_release_all()
	await _frames(10)
	_record("%s mantle" % label, "y=%.2f mantle=%s" % [p.global_position.y, saw_mantle], saw_mantle and absf(p.global_position.y - expected_top) < 0.08)

func _test_mantle_climb() -> void:
	await _jump_mantle("rock_large", 0.9, "large rock 0.9")
	await _jump_mantle("mantle_box", 1.0, "box 1.0")
	await _jump_mantle("ledge", 1.6, "ledge 1.6")
	await _shot("05_after_ledge_mantle")
	# Climbable wall
	await _reset("climb_wall", Vector3(3.2, 0, 0))
	Input.action_press("move_forward")
	await _frames(5)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	var climbing := false
	var max_y := 0.0
	for i in 600:
		await physics_frame
		if p.current_state == Player.State.CLIMB:
			climbing = true
			if i == 120:
				await _shot("06_climbing")
		max_y = maxf(max_y, p.global_position.y)
		if climbing and p.current_state != Player.State.CLIMB and p.current_state != Player.State.MANTLE and p.is_on_floor():
			break
	_release_all()
	await _frames(10)
	_record("climbable wall 4.5 climbed + topped", "climb=%s y=%.2f" % [climbing, p.global_position.y], climbing and absf(p.global_position.y - 4.5) < 0.1)
	# Non-climbable 4 m wall must not be climbable
	await _reset("wall", Vector3(3.2, 0, 0))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	var climbed_plain := false
	for i in 60:
		await physics_frame
		if p.current_state == Player.State.CLIMB:
			climbed_plain = true
	_release_all()
	_record("plain wall not climbable", climbed_plain, not climbed_plain)

func _test_crouch() -> void:
	await _reset("crawl")
	Input.action_press("crouch")
	Input.action_press("move_forward")
	await _frames(250)
	var h_under: float = p._capsule.height
	var x_under := p.global_position.x
	Input.action_release("crouch")
	Input.action_release("move_forward")
	await _frames(20)
	var still := p.is_crouching
	await _shot("07_crawl_space")
	_record("crouch capsule height", "%.2f m" % h_under, absf(h_under - p.crouch_capsule_height) < 0.01)
	_record("ceiling keeps crouch under 1.3 m roof", "x=%.2f crouching=%s" % [x_under, still], x_under > 4.2 and x_under < 7.8 and still)
	Input.action_press("move_forward")
	Input.action_press("crouch")
	await _frames(200)
	Input.action_release("crouch")
	await _frames(40)
	_release_all()
	_record("stands after leaving crawl", "x=%.2f crouching=%s" % [p.global_position.x, p.is_crouching], not p.is_crouching)

func _test_swim() -> void:
	var pz: float = course.LANE.pool
	await _reset("pool", Vector3(8, 4.0, 0))
	await _frames(180)
	var float_y := p.global_position.y
	var expected: float = course.WATER_SURFACE - Player.SWIM_FLOAT_DEPTH
	_record("swim state entered", Player.State.keys()[p.current_state], p.current_state == Player.State.SWIM)
	_record("floating feet y (expect %.2f)" % expected, "%.2f" % float_y, absf(float_y - expected) < 0.1)
	await _shot("08_swimming_surface")
	Input.action_press("dive")
	await _frames(70)
	var dived := p.global_position.y
	var was_under := p.underwater
	Input.action_release("dive")
	_record("dive descends / underwater", "y=%.2f underwater=%s" % [dived, was_under], dived < float_y - 0.6 and was_under)
	await _shot("09_underwater")
	await _frames(240)
	_record("buoyancy resurfaces", "y=%.2f" % p.global_position.y, absf(p.global_position.y - expected) < 0.15)
	# Swim west to the rim (top 2.5 m, 0.2 m above surface) and climb out.
	p.facing_yaw = PI * 0.5
	cam.yaw = PI * 0.5
	Input.action_press("move_forward")
	var out := false
	for i in 400:
		await physics_frame
		if i % 20 == 0:
			Input.action_press("jump")
		elif i % 20 == 2:
			Input.action_release("jump")
		if p.current_state != Player.State.SWIM and p.global_position.y > 2.4:
			out = true
			break
	_release_all()
	await _frames(20)
	_record("climb out over pool rim", "y=%.2f state=%s" % [p.global_position.y, Player.State.keys()[p.current_state]], out)
	# Walk out up the beach ramp
	await _reset("pool", Vector3(6, 1.6, 2.0))
	await _frames(60)
	cam.yaw = -PI * 0.5
	Input.action_press("move_forward")
	var walked_out := false
	for i in 500:
		await physics_frame
		if p.current_state != Player.State.SWIM and p.water_depth < 0.9 and p.is_on_floor() and p.global_position.x > 9.5:
			walked_out = true
			break
	_release_all()
	_record("wade out up 20 deg beach", "x=%.2f depth=%.2f state=%s" % [p.global_position.x, p.water_depth, Player.State.keys()[p.current_state]], walked_out)

func _test_camera() -> void:
	var cz: float = course.LANE.cave
	await _reset("cave")
	Input.action_press("move_forward")
	await _frames(200)
	_release_all()
	var c := cam.camera.global_position
	await _frames(30)
	c = cam.camera.global_position
	var space := p.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = cam.camera.near * 1.5
	probe.shape = s
	probe.transform = Transform3D(Basis.IDENTITY, c)
	probe.collision_mask = 2
	var inside := not space.intersect_shape(probe, 1).is_empty()
	var interior: bool = absf(c.z - cz) < 0.8 and c.y < 2.2 and c.y > 0.0
	_record("cave camera not in rock", "cam=%s arm=%.2f" % [c, cam.spring_arm.get_hit_length()], not inside and (interior or c.x < 4.0))
	await _shot("10_narrow_cave_camera")
	# Camera pitched down into ground
	cam.pitch = deg_to_rad(55.0)
	await _frames(30)
	c = cam.camera.global_position
	_record("camera pitched low stays above ground", "y=%.2f" % c.y, c.y > 0.05)
	cam.pitch = deg_to_rad(-12.0)
	# Player not seen as obstruction
	await _reset("flat", Vector3(-30, 0, 0))
	await _frames(30)
	_record("arm not blocked by Mara herself", "%.2f / %.2f" % [cam.spring_arm.get_hit_length(), cam.max_arm_length], cam.spring_arm.get_hit_length() > cam.max_arm_length - 0.1)
	await _shot("11_default_framing")
