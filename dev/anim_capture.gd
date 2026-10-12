extends SceneTree
## DEV ONLY: animation-polish captures + metrics (sprint arms, run knee, swim tempo, uneven pelvis).
## LOW GRAPHICS ONLY:
## godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s res://dev/anim_capture.gd -- --quality=1
## Output: screenshots/movement/anim_polish/<case>_fNN.png
const OUT := "res://screenshots/movement/anim_polish/"
var course
var p
var cam
var sk: Skeleton3D
var tag := ""
var shot_cam: Camera3D

## Fixed camera relative to Mara: view = front | side | back, d = distance.
func _aim(view: String, d := 3.2, h := 1.0, rise := 0.25) -> void:
	var f: Vector3 = p.get_facing_forward()
	f.y = 0
	f = f.normalized()
	var right := f.cross(Vector3.UP)
	var off: Vector3 = f * d if view == "front" else (-right * d if view == "side" else -f * d)
	var target: Vector3 = p.global_position + Vector3.UP * h
	shot_cam.global_position = target + off + Vector3.UP * rise
	shot_cam.look_at(target, Vector3.UP)
	shot_cam.make_current()
var c3: Camera3D
var view_off := Vector3.ZERO

func _track() -> void:
	var t: Vector3 = p.global_position + Vector3(0, 0.9, 0)
	c3.global_position = t + view_off
	c3.look_at(t, Vector3.UP)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	tag = "after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
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
	c3.fov = 40.0
	root.add_child(c3)
	c3.make_current()
	shot_cam = Camera3D.new()
	shot_cam.fov = 45
	root.add_child(shot_cam)
	if "--no-ext" in OS.get_cmdline_user_args():
		p.run_stance_extension = 0.0
	sk = p.visual_mesh.find_child("Skeleton3D", true, false)
	if "--only-swim" in OS.get_cmdline_user_args():
		await _swim()
		quit()
		return
	if "--only-walk" in OS.get_cmdline_user_args():
		await _idle()
		await _gait("walk", "side")
		await _gait("walk", "front")
		quit()
		return
	if "--only-run" in OS.get_cmdline_user_args():
		await _gait("run", "side")
		quit()
		return
	await _gait("sprint", "front")
	await _gait("sprint", "side")
	await _gait("run", "side")
	await _uneven()
	await _swim()
	quit()

func _release() -> void:
	for a in ["move_forward", "move_right", "move_left", "sprint", "walk", "dive", "jump"]:
		Input.action_release(a)

func _g(n: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(n)).origin

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [tag, name]))

func _gait(gait: String, view: String) -> void:
	_release()
	p.global_position = course.lane_start("flat") + Vector3(-34, 0, 0)
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	await _frames(5)
	Input.action_press("move_forward")
	if gait == "sprint":
		Input.action_press("sprint")
	elif gait == "walk":
		Input.action_press("walk")
	await _frames(40)
	# Camera: front = looking back at her face, side = from her left.
	view_off = Vector3(4.0, 0.2, 0) if view == "front" else Vector3(0, 0.2, 4.0)
	var cross := 0.0
	var min_knee := 180.0
	var knee_sum := 0.0
	var knee_n := 0
	var lift_max := 0.0
	var min_info := ""
	for i in 120:
		await physics_frame
		_track()
		var hip := _g("Hip")
		lift_max = maxf(lift_max, p._stance_lift)
		for side in ["L_", "R_"]:
			var out := signf(_g(side + "Upperarm").z - hip.z)
			var hand := _g(side + "Hand")
			# lateral distance past the body midline (positive = crossed over), metres in skel units
			cross = maxf(cross, -(hand.z - hip.z) * out)
			var a := _g(side + "Thigh")
			var b := _g(side + "Calf")
			var c := _g(side + "Foot")
			var knee := rad_to_deg((a - b).angle_to(c - b))
			var foot: Dictionary = p._feet.get(side, {})
			if foot.get("locked", false) and foot.get("w", 0.0) > 0.9:
				if knee < min_knee:
					min_info = "span/leg=%.2f horiz=%.2f lift=%.3f" % [(a - c).length() / p._leg_length, Vector2(a.x - c.x, a.z - c.z).length() / p._leg_length, p._stance_lift]
				min_knee = minf(min_knee, knee)
				knee_sum += knee
				knee_n += 1
		if i % 5 == 0 and i < 60:
			await _shot("%s_%s_f%02d" % [gait, view, i / 5])
	var s := sk.global_basis.get_scale().x
	print("METRIC %s %s speed=%.2f max_hand_cross_midline=%.3fm min_stance_knee=%.1fdeg mean_stance_knee=%.1fdeg lift_max=%.3f" % [gait, view, p.horizontal_speed, cross * s, min_knee, knee_sum / maxf(knee_n, 1), lift_max]
		+ " at_min: " + min_info)
	_release()
	await _frames(30)

func _idle() -> void:
	_release()
	p.global_position = course.lane_start("flat") + Vector3(-34, 0, 0)
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	await _frames(60)
	view_off = Vector3(2.4, 0.4, 2.4)
	for i in 10:
		await _frames(30)
		_track()
		await _shot("idle_q_f%02d" % i)

func _uneven() -> void:
	_release()
	# Straddle the 0.15 m step edge (step spans x 4..7): lateral axis along X.
	p.global_position = course.lane_start("step_015") + Vector3(4.0, 0.2, 0)
	p.velocity = Vector3.ZERO
	p.facing_yaw = 0.0
	p.current_state = Player.State.IDLE
	view_off = Vector3(0, 0.0, 2.6)
	await _frames(120)
	_track()
	var gap: Vector2 = p.last_feet_ground_gap
	print("METRIC uneven y=%.3f pelvis_offset=%.3f feet_gap L=%.3f R=%.3f" % [p.global_position.y, p._pelvis_offset, gap.x, gap.y])
	await _shot("uneven_idle_front")
	view_off = Vector3(2.6, 0.0, 0)
	_track()
	await _shot("uneven_idle_side")

func _swim() -> void:
	_release()
	p.global_position = course.lane_start("pool") + Vector3(7.5, 2.0, 0)
	p.velocity = Vector3.ZERO
	p.facing_yaw = PI * 0.5
	cam.yaw = PI * 0.5
	await _frames(150)
	Input.action_press("move_forward")
	await _frames(30)
	var swim_clip: String = p.get_clip_mapping().get("swim", "")
	var length: float = p.anim_player.get_animation(swim_clip).length if p.anim_player.has_animation(swim_clip) else 0.0
	var sc: float = p._anim_tree.get("parameters/swim/blend/swim_idle/scale/scale")
	# Stroke period: mean-crossings of the left hand's fore/aft offset from the hip.
	var xs := []
	for i in 20:
		_aim("side", 3.2, 1.1, 1.2)
		await _shot("swim_side_f%02d" % i)
		for k in 5:
			await physics_frame
			xs.append(_g("L_Hand").x - _g("Hip").x)
	var mean := 0.0
	for x in xs:
		mean += x
	mean /= xs.size()
	var crossings := 0
	for i in range(1, xs.size()):
		if (xs[i - 1] - mean) * (xs[i] - mean) < 0.0:
			crossings += 1
	var secs := xs.size() / float(Engine.physics_ticks_per_second)
	print("POS ", p.global_position, " vel ", p.velocity, " start ", course.lane_start("pool"))
	print("METRIC swim clip=%s len=%.2fs speed=%.2f state=%s scale=%.2f hand_cycles_per_s=%.2f (over %.1fs)" % [swim_clip, length, Vector2(p.velocity.x, p.velocity.z).length(), Player.State.keys()[p.current_state], sc, crossings * 0.5 / secs, secs])
	_release()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
