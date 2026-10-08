extends SceneTree
## DEV ONLY: Meridian gear variants, cover/reload/ragdoll and Mara ragdoll in low graphics.
## godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 960x540 --path . -s res://dev/enemy_ragdoll_check.gd

const OUT := "res://screenshots/movement/enemy_ragdoll/"

func _init() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))

func _hip_y(skel: Skeleton3D) -> float:
	return (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Hip")).origin).y

func _run() -> void:
	var gs = root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_quality"):
		gs.apply_quality(0, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var course = load("res://dev/MovementTestCourse.tscn").instantiate()
	root.add_child(course)
	var p: Player = course.player
	var cam: CameraController = course.camera_rig
	var enemies := []
	var variants := ["rifleman", "heavy", "radio"]
	for i in 3:
		var e: EnemyBase = load("res://scenes/EnemyMercenary.tscn").instantiate()
		e.name = "Merc_%s" % variants[i]
		e.get_node("VisualMesh").gear_variant = variants[i]
		e.position = Vector3(-24 + i * 1.6, 0.05, -14)
		e.rotation.y = 0.0 # faces -Z; camera looks from +Z side
		course.add_child(e)
		enemies.append(e)
	for i in 20:
		await physics_frame
	p.global_position = Vector3(-22.4, 0.02, -8.0)
	cam.yaw = 0.0
	cam.pitch = deg_to_rad(-8.0)
	cam.max_arm_length = 3.0
	cam.snap_to_target()
	for e in enemies:
		var gv: Node3D = e.get_node("VisualMesh")
		var gear := []
		for g in gv.find_children("Gear_*", "BoneAttachment3D", true, false):
			gear.append(g.name)
		print("ENEMY ", e.name, " variant=", gv.get_meta("gear_variant", "?"), " gear=", gear, " anim=", gv.idle_player.current_animation if gv.idle_player else "none")
	for i in 30:
		await physics_frame
	await _shot("01_variants_idle")
	# Cover fire + combat shoot + reload
	enemies[0].current_state = EnemyBase.AIState.TAKE_COVER
	enemies[1].current_state = EnemyBase.AIState.COMBAT
	enemies[1].target_player = null
	enemies[2].get_node("VisualMesh").play_reload()
	for i in 20:
		await physics_frame
	for e in enemies:
		var gv: Node3D = e.get_node("VisualMesh")
		print("STATE ", e.name, " ai=", EnemyBase.AIState.keys()[e.current_state], " anim=", gv.idle_player.current_animation, " pos=%.2f" % gv.idle_player.current_animation_position, " reloading=", gv.is_reloading())
	await _shot("02_cover_combat_reload")
	enemies[1].current_state = EnemyBase.AIState.PATROL
	# Ragdoll death
	var victim: EnemyBase = enemies[2]
	var vskel: Skeleton3D = victim.get_node("VisualMesh").skeleton
	var before := _hip_y(vskel)
	victim.take_damage(999.0)
	for k in 6:
		for i in 10:
			await physics_frame
		await _shot("03_enemy_ragdoll_%02d" % k)
	var after := _hip_y(vskel)
	print("ENEMY RAGDOLL hip y before=%.2f after=%.2f finite=%s sim=%s" % [before, after, is_finite(after), victim.get_node("VisualMesh").ragdoll != null])
	# Mara ragdoll
	var mskel: Skeleton3D = p.visual_mesh.find_child("Skeleton3D", true, false)
	var mb := _hip_y(mskel)
	p.take_damage(999.0)
	for k in 6:
		for i in 10:
			await physics_frame
		await _shot("04_mara_ragdoll_%02d" % k)
	var ma := _hip_y(mskel)
	print("MARA RAGDOLL hip y before=%.2f after=%.2f finite=%s sim=%s" % [mb, ma, is_finite(ma), p.ragdoll != null])
	quit()
