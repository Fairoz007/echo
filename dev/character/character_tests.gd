extends SceneTree
## DEV ONLY: procedural character layer checks + LOW frame sequences on CharacterTest.tscn.
## godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 \
##   -s res://dev/character/character_tests.gd -- --quality=1 [--no-shots] [--only=arms,hit]
## Output: screenshots/character/<case>_fNN.png, "CHR <name> <value> PASS|FAIL" lines.
const OUT := "res://screenshots/character/"
var course
var p: Player
var cam
var c3: Camera3D
var view_off := Vector3(0, 0.5, 4.5)
var shots := true
var failures := 0
var results := 0
var sk: Skeleton3D
var acc := {} ## lambda accumulators (GDScript lambdas capture locals by value)
var only := PackedStringArray()

func _init() -> void:
	shots = not ("--no-shots" in OS.get_cmdline_user_args())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",", false)
	call_deferred("_run")

func _record(name: String, value, ok: bool, note := "") -> void:
	results += 1
	if not ok:
		failures += 1
	print("CHR %-40s %-34s %s %s" % [name, str(value), "PASS" if ok else "FAIL", note])

func _run() -> void:
	var gs = root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_quality"):
		gs.apply_quality(1, false)
	var gm = root.get_node_or_null("GameManager")
	if gm and "current_state" in gm:
		gm.current_state = gm.GameState.GAMEPLAY
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	course = (load("res://dev/character/CharacterTest.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 20:
		await physics_frame
	p = course.player
	cam = course.camera_rig
	c3 = Camera3D.new()
	c3.fov = 45.0
	root.add_child(c3)
	c3.make_current()
	print("=== CHARACTER TESTS ===")
	sk = p.get_skeleton()
	_record("get_skeleton() bones", sk.get_bone_count() if sk else -1, sk != null and sk.get_bone_count() == 41)
	_record("get_visual_root()", p.get_visual_root().name if p.get_visual_root() else "null", p.get_visual_root() != null and p.get_visual_root().is_ancestor_of(sk))
	_record("in group player", p.is_in_group("player"), p.is_in_group("player"))
	for test in [["idle", _idle], ["turn", _turn], ["terrain", _slope_stairs_rocks],
		["landing", _landing], ["hit", _hit], ["interact", _interact],
		["climb", _climb_mantle], ["arms", _run_arms], ["swim", _swim]]:
		if only.is_empty() or test[0] in only:
			var run_case: Callable = test[1]
			await run_case.call()
	print("=== %d results, %d failures ===" % [results, failures])
	_release()
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers
func _release() -> void:
	for a in ["move_forward", "move_back", "move_right", "move_left", "sprint", "walk", "jump", "crouch"]:
		Input.action_release(a)

func _reset(lane: String, off: Vector3, yaw := -PI * 0.5) -> void:
	_release()
	p.global_position = course.lane_start(lane) + off
	p.velocity = Vector3.ZERO
	p.facing_yaw = yaw
	p.current_state = Player.State.IDLE
	cam.yaw = -PI * 0.5
	cam.snap_to_target()
	for i in 30:
		await _tick()

func _tick() -> void:
	await physics_frame
	var t: Vector3 = p.global_position + Vector3(0, 0.9, 0)
	c3.global_position = t + view_off
	c3.look_at(t, Vector3.UP)

func _shot(name: String) -> void:
	if not shots:
		return
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))

func _bone_w(n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin

func _knee_deg(side: String) -> float:
	var a := _bone_w(side + "Thigh")
	var b := _bone_w(side + "Calf")
	var c := _bone_w(side + "Foot")
	return rad_to_deg((a - b).angle_to(c - b))

func _finite() -> bool:
	for i in sk.get_bone_count():
		var o := sk.get_bone_global_pose(i).origin
		if not o.is_finite():
			return false
	return true

## Runs n ticks, capturing a frame every `every` ticks into <name>_fNN; calls probe each tick.
func _watch(name: String, n: int, every: int, probe: Callable) -> void:
	var k := 0
	for i in n:
		await _tick()
		probe.call()
		if every > 0 and i % every == 0 and k < 12:
			await _shot("%s_f%02d" % [name, k])
			k += 1

# ------------------------------------------------------------------ cases
func _idle() -> void:
	await _reset("flat", Vector3(-30, 0, 0))
	view_off = Vector3(0, 0.3, 3.2)
	var knees := []
	var head_y := []
	await _watch("idle", 300, 25, func():
		knees.append(minf(_knee_deg("L_"), _knee_deg("R_")))
		head_y.append(_bone_w("Head").y))
	var kmin: float = knees.min()
	var kavg := 0.0
	for k in knees:
		kavg += k
	kavg /= knees.size()
	_record("idle knee angle avg/min (deg)", "%.1f / %.1f" % [kavg, kmin], kavg > 165.0, "180 = straight; clip alone ~148")
	var amp: float = head_y.max() - head_y.min()
	_record("idle breathing head travel (m)", "%.4f" % amp, amp > 0.002 and amp < 0.04)
	_record("idle feet on ground (gap m)", "%.3f / %.3f" % [p.last_feet_ground_gap.x, p.last_feet_ground_gap.y], absf(p.last_feet_ground_gap.x) < 0.03 and absf(p.last_feet_ground_gap.y) < 0.03)
	view_off = Vector3(0, 0.5, 4.5)

func _turn() -> void:
	await _reset("flat", Vector3(-30, 0, 0))
	view_off = Vector3(3.0, 0.8, 3.0)
	var lf0 := _bone_w("L_Foot")
	var rf0 := _bone_w("R_Foot")
	acc = {"w": 0.0, "moved": 0.0}
	Input.action_press("move_back") # 180 from standstill
	await _watch("turn_180", 36, 3, func():
		acc.w = maxf(acc.w, p._turn_w)
		if p.horizontal_speed < 0.5: # walk cycle driven while still on the spot
			acc.moved = maxf(acc.moved, float(p._gait_smooth.get("locomotion", 0.0))))
	_release()
	var max_w: float = acc.w
	var moved: float = acc.moved
	_record("turn-in-place weight (max)", "%.2f" % max_w, max_w > 0.5)
	_record("turn-in-place gait blend at <0.5 m/s", "%.2f" % moved, moved > 0.2, "walk cycle steps the feet (foot lock re-plants)")
	await _reset("flat", Vector3(-30, 0, 0))
	Input.action_press("move_left") # 90 from standstill
	await _watch("turn_90", 30, 3, func(): pass)
	_release()
	view_off = Vector3(0, 0.5, 4.5)

func _stand_gap(label: String, lane: String, off: Vector3, name: String) -> void:
	await _reset(lane, off)
	view_off = Vector3(0, 0.3, 3.0)
	acc = {"worst": 0.0}
	await _watch(name, 60, 20, func():
		acc.worst = maxf(acc.worst, maxf(absf(p.last_feet_ground_gap.x), absf(p.last_feet_ground_gap.y))))
	var worst: float = acc.worst
	_record("%s stand: worst foot gap (m)" % label, "%.3f (L %.3f R %.3f) pelvis %.3f" % [worst, p.last_feet_ground_gap.x, p.last_feet_ground_gap.y, p._pelvis_offset], worst < 0.04)
	view_off = Vector3(0, 0.5, 4.5)

func _walk_gap(label: String, lane: String, off: Vector3, name: String, ticks: int) -> void:
	await _reset(lane, off)
	Input.action_press("move_forward")
	Input.action_press("walk")
	acc = {"sink": 0.0}
	await _watch(name, ticks, maxi(ticks / 12, 1), func():
		if p.is_on_floor() and p.current_state in [Player.State.WALK, Player.State.RUN, Player.State.IDLE]:
			acc.sink = minf(acc.sink, minf(p.last_feet_ground_gap.x, p.last_feet_ground_gap.y)))
	_release()
	var sink: float = acc.sink
	_record("%s walk: deepest foot penetration (m)" % label, "%.3f" % sink, sink > -0.03)

func _slope_stairs_rocks() -> void:
	# Standing across the slope (side-on) puts one foot uphill of the other.
	await _stand_gap("slope 15 side-on", "slope_15", Vector3(6.0, 0.6, 0), "stand_slope15")
	await _stand_gap("slope 30", "slope_30", Vector3(6.0, 1.2, 0), "stand_slope30")
	await _stand_gap("stair edge", "stairs", Vector3(4.95, 0.75, 0), "stand_stairs")
	await _walk_gap("stairs", "stairs", Vector3(1.5, 0, 0), "walk_stairs", 150)
	await _walk_gap("slope 15", "slope_15", Vector3(1.5, 0, 0), "walk_slope15", 150)
	await _walk_gap("small rock", "rock_small", Vector3(1.5, 0, 0), "walk_rock", 150)
	_record("skeleton finite after terrain", _finite(), _finite())

func _landing() -> void:
	# Walk off the 1.6 m ledge (soft) and off the 4.5 m climb-wall top (hard).
	for c in [["land_soft", "ledge", Vector3(6.5, 1.65, 0), 0.02], ["land_hard", "climb_wall", Vector3(5.5, 4.55, 0), 0.07]]:
		await _reset(c[1], c[2], PI * 0.5) # face -X, walk off the front edge
		view_off = Vector3(0, 0.2, 4.0)
		Input.action_press("move_forward")
		var landed := false
		var max_sq := 0.0
		var sink := 0.0
		var k := 0
		for i in 160:
			await _tick()
			if p.is_on_floor() and p.global_position.y < 0.3:
				if not landed:
					landed = true
					_release()
				max_sq = maxf(max_sq, p.last_land_squash)
				sink = minf(sink, minf(p.last_feet_ground_gap.x, p.last_feet_ground_gap.y))
			if landed and k < 12 and i % 2 == 0:
				await _shot("%s_f%02d" % [c[0], k])
				k += 1
		_release()
		_record("%s squash depth (m)" % c[0], "%.3f impact %.1f m/s" % [max_sq, p.last_landing_speed], max_sq > c[3])
		_record("%s feet stay on ground (m)" % c[0], "%.3f" % sink, sink > -0.03)
	view_off = Vector3(0, 0.5, 4.5)

func _hit() -> void:
	await _reset("flat", Vector3(-30, 0, 0))
	view_off = Vector3(0, 0.4, 3.2)
	var h0 := _bone_w("Head")
	acc = {"w": 0.0, "d": 0.0}
	p.take_damage(15.0, Vector3(-1, 0, 0)) # blow travelling -X: she faces +X, hit in the chest
	await _watch("hit_front", 30, 2, func():
		acc.w = maxf(acc.w, p.last_hit_weight)
		acc.d = maxf(acc.d, _bone_w("Head").distance_to(h0)))
	var max_w: float = acc.w
	var max_d: float = acc.d
	_record("hit reaction weight / head travel", "%.2f / %.3f m" % [max_w, max_d], max_w > 0.3 and max_d > 0.04 and max_d < 0.35)
	_record("hit recovers", "w=%.2f" % p.last_hit_weight, p.last_hit_weight < 0.01)
	p.take_damage(15.0, Vector3(0, 0, 1))
	await _watch("hit_side", 30, 2, func(): pass)
	p.current_health = p.max_health
	view_off = Vector3(0, 0.5, 4.5)

func _interact() -> void:
	# Lever at (1.2, 1.05, flat+3); stand 0.55 m from it, facing it (+Z).
	await _reset("flat", Vector3(1.2, 0, 3.0 - 0.6), PI)
	view_off = Vector3(3.5, 0.4, 0.0)
	var lever: Node3D = course.lever
	var best := INF
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _tick()
	var ev2 := InputEventAction.new()
	ev2.action = "interact"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	var triggered := p._interact_t < 0.5
	if not triggered: # no interact action mapped in this run: drive the reach directly
		p.play_interact_reach(lever.global_position)
	acc = {"best": INF}
	await _watch("interact", 45, 4, func():
		acc.best = minf(acc.best, _bone_w("R_Hand").distance_to(lever.global_position)))
	best = acc.best
	_record("interact reach: hand to lever min (m)", "%.3f via_input=%s" % [best, triggered], best < 0.15)
	view_off = Vector3(0, 0.5, 4.5)

func _climb_mantle() -> void:
	await _reset("climb_wall", Vector3(3.2, 0, 0))
	view_off = Vector3(-1.0, 0.6, 4.0)
	Input.action_press("move_forward")
	await _tick()
	Input.action_press("jump")
	for i in 3:
		await _tick()
	Input.action_release("jump")
	var gaps := []
	var k := 0
	for i in 600:
		await _tick()
		if p.current_state == Player.State.CLIMB and p._climb_hand_w > 0.95:
			var g := p.last_hand_contact_gap
			if g.x >= 0.0 and g.y >= 0.0:
				gaps.append(maxf(g.x, g.y))
			if i % 20 == 0 and k < 12:
				await _shot("climb_f%02d" % k)
				k += 1
		if p.current_state == Player.State.MANTLE and k < 14:
			await _shot("climb_top_f%02d" % k)
			k += 1
		if p.global_position.y > 4.4 and p.is_on_floor():
			break
	_release()
	var avg := 0.0
	for g in gaps:
		avg += g
	avg = avg / maxf(gaps.size(), 1)
	_record("climb hands on wall: avg gap (m)", "%.3f (%d samples)" % [avg, gaps.size()], gaps.size() > 20 and avg < 0.05, "hand bone to wall contact target")
	# Mantle onto the 1.0 m box: hands plant on the lip.
	await _reset("mantle_box", Vector3(3.0, 0, 0))
	view_off = Vector3(0, 0.4, 3.5)
	Input.action_press("move_forward")
	for i in 15:
		await _tick()
	Input.action_press("jump")
	var mg := INF
	k = 0
	for i in 60:
		await _tick()
		if p._mantle_hand_w > 0.8:
			var g := p.last_hand_contact_gap
			if g.x >= 0.0:
				mg = minf(mg, maxf(g.x, g.y))
		if p.current_state == Player.State.MANTLE or (k > 0 and k < 10):
			await _shot("mantle_f%02d" % k)
			k += 1
	_release()
	_record("mantle hands on ledge: best gap (m)", "%.3f" % mg, mg < 0.08)

func _run_arms() -> void:
	for mode in [["run", ["move_forward"]], ["sprint", ["move_forward", "sprint"]]]:
		await _reset("flat", Vector3(-34, 0, 0))
		for a in mode[1]:
			Input.action_press(a)
		for i in 60:
			await _tick()
		acc = {"ahead": 0.0}
		await _watch(mode[0] + "_arms", 90, 4, func():
			var sp := sk.get_bone_global_pose(sk.find_bone("Spine02")).origin
			var s := sk.global_basis.get_scale().x
			for side in ["L_", "R_"]:
				var h := sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin
				acc.ahead = maxf(acc.ahead, (h.x - sp.x) * s))
		_release()
		var ahead: float = acc.ahead
		_record("%s hand max ahead of chest (m)" % mode[0], "%.3f" % ahead, ahead < 0.30, "leading-arm reach")

func _swim() -> void:
	await _reset("pool", Vector3(2.6, 2.55, 0))
	Input.action_press("move_forward")
	Input.action_press("walk")
	acc = {"swam": false}
	await _watch("swim_entry", 150, 12, func():
		if p.current_state == Player.State.SWIM:
			acc.swam = true)
	_release()
	var swam: bool = acc.swam
	_record("water entry -> swim, foot IK off", "swim=%s pelvis=%.3f" % [swam, p._pelvis_offset], swam and absf(p._pelvis_offset) < 0.05)
