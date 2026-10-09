extends SceneTree
## DEV ONLY: full-frame run/sprint posture captures (side + third-person) and framing check.
## LOW GRAPHICS ONLY:
## godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 960x540 --path . -s res://dev/run_posture_capture.gd
## Output: screenshots/movement/run_posture/<variant>_<view>_<gait>_fNN.png

const OUT := "res://screenshots/movement/run_posture/"
var course
var p: Player
var cam: CameraController

func _init() -> void:
	call_deferred("_run")

func _load_course(run_from_walk: bool) -> void:
	if course:
		course.queue_free()
		await process_frame
		await process_frame
	if run_from_walk:
		Engine.set_meta("dev_run_from_walk", true)
	elif Engine.has_meta("dev_run_from_walk"):
		Engine.remove_meta("dev_run_from_walk")
	course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 10:
		await physics_frame
	p = course.player
	cam = course.camera_rig

func _run() -> void:
	var gs = root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_quality"):
		gs.apply_quality(0, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("RENDERER ", RenderingServer.get_current_rendering_method())
	for variant in [["posture", false, true], ["raw", false, false], ["fromwalk", true, true]]:
		await _load_course(variant[1])
		p.run_posture_enabled = variant[2]
		for gait in ["run", "sprint"]:
			for view in ["side", "third"]:
				await _capture(variant[0], view, gait)
	quit()

func _capture(variant: String, view: String, gait: String) -> void:
	for a in ["move_forward", "move_right", "sprint"]:
		Input.action_release(a)
	p.global_position = course.lane_start("flat") + Vector3(-34, 0, 0)
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	var move := "move_forward"
	if view == "side":
		cam.yaw = 0.0
		cam.pitch = deg_to_rad(-5.0)
		cam.max_arm_length = 4.2
		cam.camera.h_offset = 0.0
		move = "move_right"
	else:
		# Exactly the in-game defaults: behind Mara, 3.5 m arm, -12 deg, 0.35 shoulder offset.
		cam.yaw = -PI * 0.5
		cam.pitch = deg_to_rad(-12.0)
		cam.max_arm_length = 3.5
		cam.camera.h_offset = 0.35
	cam.snap_to_target()
	for i in 10:
		await physics_frame
	Input.action_press(move)
	if gait == "sprint":
		Input.action_press("sprint")
	for i in 70:
		await physics_frame
	var all_in := true
	for k in 6:
		for i in 5:
			await physics_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "%s_%s_%s_f%02d.png" % [variant, view, gait, k]))
		var framed := _framed()
		all_in = all_in and framed
	print("CAPTURE %s %s %s speed=%.2f state=%s fully_framed=%s" % [variant, view, gait, p.horizontal_speed, Player.State.keys()[p.current_state], all_in])
	for a in ["move_forward", "move_right", "sprint"]:
		Input.action_release(a)

## Head and both feet project inside the viewport with a small margin.
func _framed() -> bool:
	var camera := root.get_viewport().get_camera_3d()
	var size := root.get_viewport().get_visible_rect().size
	var sk: Skeleton3D = p.visual_mesh.find_child("Skeleton3D", true, false)
	for bone in ["Head", "L_ToeBase", "R_ToeBase"]:
		var w: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
		if bone == "Head":
			w += Vector3.UP * 0.12
		if camera.is_position_behind(w):
			return false
		var s := camera.unproject_position(w)
		if s.x < 4 or s.y < 4 or s.x > size.x - 4 or s.y > size.y - 4:
			print("  out of frame: ", bone, " at ", s)
			return false
	return true
