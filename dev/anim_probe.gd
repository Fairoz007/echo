extends SceneTree
## DEV ONLY: post-stop idle pose diagnostics (hip height, knee angle, layer offsets).
func _init() -> void:
	call_deferred("_run")
func _knee(sk: Skeleton3D) -> float:
	var a := sk.get_bone_global_pose(sk.find_bone("L_Thigh")).origin
	var b := sk.get_bone_global_pose(sk.find_bone("L_Calf")).origin
	var c := sk.get_bone_global_pose(sk.find_bone("L_Foot")).origin
	return rad_to_deg((a - b).angle_to(c - b))
func _run() -> void:
	var course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 20:
		await physics_frame
	var p = course.player
	var sk: Skeleton3D = p._skeleton
	p.global_position = course.lane_start("flat") + Vector3(-34, 0, 0)
	course.camera_rig.yaw = -PI * 0.5
	for i in 60:
		await physics_frame
	print("IDLE fresh hip=%.3f knee=%.0f crouch=%.2f node=%s" % [sk.get_bone_global_pose(sk.find_bone("Hip")).origin.y, _knee(sk), p._crouch_blend, p._anim_tree.get("parameters/playback").get_current_node()])
	Input.action_press("move_forward"); Input.action_press("sprint")
	for i in 60:
		await physics_frame
	Input.action_release("move_forward"); Input.action_release("sprint")
	for i in 120:
		await physics_frame
		if i % 20 == 0:
			print("STOP f%d hip=%.3f knee=%.0f crouch=%.2f lift=%.3f pel=%.3f pw=%.2f node=%s pos=%s land=%.2f state=%s" % [i, sk.get_bone_global_pose(sk.find_bone("Hip")).origin.y, _knee(sk), p._crouch_blend, p._stance_lift, p._pelvis_offset, p._posture_w, p._anim_tree.get("parameters/playback").get_current_node(), p._anim_tree.get("parameters/locomotion/blend/blend_position"), p._land_timer, Player.State.keys()[p.current_state]])
	quit()
