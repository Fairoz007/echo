extends SceneTree
## Headless P0 test: the Prologue main path must be clear along its centreline.
## A player capsule (r 0.4, h 1.74) is placed every 0.25 m from start to exit, resting
## on the ground found by a down-ray; any overlapping body (other than the ground the
## capsule stands on) or a ground step > 0.4 m fails. Prints the blocking node paths.
## Usage: godot --headless --path . -s res://scripts/qa_prologue_centreline.gd
const START := Vector3(0, 0, 1.0)
const END := Vector3(0, 0, -26.5)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://levels/Prologue.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await create_timer(2.0).timeout
	for i in 4:
		await physics_frame
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for n in scene.find_children("*", "CollisionObject3D", true, false):
		if n is CharacterBody3D or n is Area3D:
			exclude.append(n.get_rid())
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.74
	var blockers := {}
	var last_y := INF
	var fails := 0
	var steps := int(START.distance_to(END) / 0.25)
	var lanes := [0.0, -0.7, 0.7]
	for lane_i in lanes.size() * (steps + 1):
		var lane: float = lanes[lane_i / (steps + 1)]
		var i: int = lane_i % (steps + 1)
		if i == 0:
			last_y = INF
		var p := START.lerp(END, float(i) / steps) + Vector3(lane, 0, 0)
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 3.0)
		ray.exclude = exclude
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			print("NO GROUND at ", p)
			fails += 1
			continue
		var gy: float = hit.position.y
		if last_y != INF and absf(gy - last_y) > 0.4:
			print("STEP %.2f m at z=%.2f (%s)" % [gy - last_y, p.z, scene.get_path_to(hit.collider)])
			fails += 1
		last_y = gy
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.exclude = exclude
		q.collision_mask = 3
		# Capsule bottom 0.12 m above ground (step tolerance), like a walking player.
		q.transform = Transform3D(Basis(), Vector3(p.x, gy + 0.87 + 0.12, p.z))
		for r in space.intersect_shape(q, 16):
			var path := str(scene.get_path_to(r.collider))
			if not blockers.has(path):
				blockers[path] = p.z
				print("BLOCKED at x=%.1f z=%.2f by %s" % [p.x, p.z, path])
				fails += 1
	print("CENTRELINE %s blockers=%d fails=%d" % ["PASS" if fails == 0 else "FAIL", blockers.size(), fails])
	scene.queue_free()
	await process_frame
	quit(0 if fails == 0 else 1)
