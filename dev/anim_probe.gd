extends SceneTree
## DEV ONLY: floor contact / state / foot-lock trace while running.
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 20:
		await physics_frame
	var p = course.player
	p.global_position = course.lane_start("flat") + Vector3(-34, 0, 0)
	p.facing_yaw = -PI * 0.5
	course.camera_rig.yaw = -PI * 0.5
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
		if i % 6 == 0:
			var lk := []
			for sd in p._feet:
				var sk: Skeleton3D = p._skeleton
				var aw: Vector3 = sk.global_transform * sk.get_bone_global_pose(p._feet[sd].ids[2]).origin
				lk.append("%s:%s ay=%.3f g=%.3f lift=%.3f pel=%.3f" % [sd, p._feet[sd].locked, aw.y, p._ground_below(aw), p._stance_lift, p._pelvis_offset])
			var pb = p._anim_tree.get("parameters/playback")
			print("N f%d node=%s pos=%s sc=%s dom=%.2f spd=%.2f" % [i, pb.get_current_node(), p._anim_tree.get("parameters/locomotion/blend/blend_position"), p._anim_tree.get("parameters/locomotion/blend/run/scale/scale"), p._dominant_scale, p.horizontal_speed])
			print("T f%d floor=%s state=%s anim=%s grace=%.2f vy=%.2f %s" % [i, p.is_on_floor(), Player.State.keys()[p.current_state], p.anim_state, p._air_grace, p.velocity.y, lk])
	quit()
