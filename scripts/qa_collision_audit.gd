extends SceneTree

## Collision audit: loads every campaign level, lists every visible MeshInstance3D / CSG
## above a size threshold, reports whether physics covers it, and validates coverage by
## sweeping a player-sized capsule through the obstacle (horizontal for upright objects,
## vertical drop for floors). Also flags large untextured near-white surfaces (blockout).
## Output: res://qa_reports/collision_audit.json + console table.
## Usage: godot --headless -s res://scripts/qa_collision_audit.gd [-- --levels=0,1,2]

const MIN_SIZE := 0.45
const ES := preload("res://systems/environment/EnvironmentCollision.gd")
var rows: Array = []
var white: Array = []
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm := root.get_node("GameManager")
	root.get_node("SaveManager").save_directory = "user://qa_collision_audit"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_collision_audit"))
	var chapters := range(12)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			chapters = Array(a.trim_prefix("--levels=").split(",")).map(func(x): return int(x))
	for chapter in chapters:
		var path: String = gm.chapter_scene(chapter)
		if path == "" or not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		var level := packed.instantiate()
		if not level is Node3D:
			level.free()
			continue
		root.add_child(level)
		await create_timer(0.6).timeout
		for i in 4:
			await physics_frame
		_audit_level(level, path.get_file())
		root.get_node("AudioManager").stop_dialogue()
		level.queue_free()
		await process_frame
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa_reports"))
	var f := FileAccess.open("res://qa_reports/collision_audit.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows, "white_surfaces": white}, "  "))
	f.close()
	print("COLLISION AUDIT rows=%d failures=%d white=%d" % [rows.size(), failures, white.size()])
	quit(1 if failures > 0 else 0)

func _player_rids(level: Node) -> Array[RID]:
	var out: Array[RID] = []
	for n in level.find_children("*", "CollisionObject3D", true, false):
		if n is CharacterBody3D or n is RigidBody3D and n.is_in_group("enemy"):
			out.append(n.get_rid())
		if n is Area3D:
			out.append(n.get_rid())
	return out

func _audit_level(level: Node3D, scene: String) -> void:
	var space := level.get_world_3d().direct_space_state
	var exclude := _player_rids(level)
	var nodes: Array = level.find_children("*", "MeshInstance3D", true, false)
	nodes.append_array(level.find_children("*", "CSGShape3D", true, false))
	for node in nodes:
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		if node is CSGShape3D and node.get_parent() is CSGShape3D:
			continue
		var exempt := ES.is_covered_or_exempt(node, level)
		if exempt == "exempt":
			continue
		var aabb: AABB = (gi.global_transform * gi.get_aabb())
		var size := aabb.size
		if size[size.max_axis_index()] < MIN_SIZE:
			continue
		var kind: String = "csg" if node is CSGShape3D else ES.classify(node, level)
		var required := kind != "none"
		if node is CSGShape3D:
			required = true
		var exists := "none"
		var ctype := ""
		if node is CSGShape3D and node.use_collision:
			exists = "authored"; ctype = "csg"
		elif exempt == "covered":
			exists = "authored"; ctype = _authored_type(node, level)
		for c in node.get_children():
			if c is StaticBody3D and c.is_in_group(ES.GENERATED_GROUP):
				exists = "auto"; ctype = _shape_name(c.get_child(0).shape)
		var validated := "n/a"
		var problem := ""
		if required:
			var walkable := ["bridge", "floor", "ground", "platform", "ledge", "terrain"].any(func(w): return ES._label(node, level).contains(w))
			if (size.y < 0.6 and size.x > 2.0 and size.z > 2.0) or (walkable and kind != "csg" and size.y < 2.5):
				validated = "pass" if _drop_blocked(space, aabb, exclude) else "FAIL"
			elif size.y > 0.5:
				validated = "pass" if _sweep_blocked(space, aabb, exclude) else "FAIL"
			else:
				validated = "low (step-over)"
			if exists == "none":
				problem = "visible obstacle without collision"
			elif validated == "FAIL":
				problem = "capsule passes through"
		if required and (exists == "none" or validated == "FAIL") and not _is_overhead(aabb):
			failures += 1
		elif _is_overhead(aabb) and problem != "":
			problem += " (overhead, unreachable)"
		var row := {"scene": scene, "asset": _asset_name(node, level), "path": str(level.get_path_to(node)),
			"size": "%.1fx%.1fx%.1f" % [size.x, size.y, size.z], "class": kind,
			"required": required, "exists": exists, "type": ctype, "validated": validated, "problem": problem}
		rows.append(row)
		_check_white(node, scene, level, size)
		if problem != "":
			print("%-16s %-40s %-8s %-8s %-10s %s" % [scene, row.asset, kind, exists, validated, problem])

func _is_overhead(aabb: AABB) -> bool:
	return aabb.position.y > 2.2

func _sweep_blocked(space: PhysicsDirectSpaceState3D, aabb: AABB, exclude: Array[RID]) -> bool:
	# Sweep capsule along X and Z through the centre at knee/torso height; blocked if either stops.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.74
	var center := aabb.get_center()
	var y := maxf(aabb.position.y + 0.9, 0.95)
	if y > aabb.end.y + 0.5:
		y = aabb.end.y
	var blocked_any := false
	for axis in [Vector3.RIGHT, Vector3.BACK]:
		var half := (aabb.size.x if axis == Vector3.RIGHT else aabb.size.z) * 0.5 + 1.0
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = capsule
		params.exclude = exclude
		params.collision_mask = 3
		params.transform = Transform3D(Basis(), Vector3(center.x, y, center.z) - axis * half)
		params.motion = axis * half * 2.0
		var r := space.cast_motion(params)
		if r.size() == 2 and r[0] < 0.999:
			blocked_any = true
	return blocked_any

func _drop_blocked(space: PhysicsDirectSpaceState3D, aabb: AABB, exclude: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(aabb.get_center() + Vector3.UP * 2.0, aabb.get_center() + Vector3.DOWN * 2.0)
	q.exclude = exclude
	q.collision_mask = 3
	return not space.intersect_ray(q).is_empty()

func _authored_type(node: Node, level: Node) -> String:
	var n := node.get_parent()
	while n and n != level:
		if n is CollisionObject3D:
			for c in n.get_children():
				if c is CollisionShape3D:
					return n.get_class() + "/" + _shape_name(c.shape)
		n = n.get_parent()
	return "child body"

func _shape_name(s: Shape3D) -> String:
	if s == null:
		return "null"
	return s.get_class().trim_suffix("Shape3D")

func _asset_name(node: Node, level: Node) -> String:
	var n := node
	while n and n != level:
		if n.scene_file_path != "":
			return n.scene_file_path.get_file()
		n = n.get_parent()
	return String(node.name) + " (" + node.get_class() + ")"

func _check_white(node: Node, scene: String, level: Node, size: Vector3) -> void:
	var mat: Material = null
	if node.material_override:
		mat = node.material_override
	elif node is CSGShape3D:
		mat = node.material if "material" in node else null
	elif node is MeshInstance3D:
		mat = node.material_override if node.material_override else node.get_active_material(0)
	var area := maxf(size.x * size.z, maxf(size.x * size.y, size.y * size.z))
	if area < 4.0:
		return
	var verdict := ""
	if mat == null:
		verdict = "no material (default white)"
	elif mat is StandardMaterial3D and mat.albedo_texture == null and mat.albedo_color.get_luminance() > 0.6:
		verdict = "flat bright untextured (%.2f)" % mat.albedo_color.get_luminance()
	elif mat is StandardMaterial3D and mat.albedo_texture == null and mat.normal_texture == null and not mat.uv1_triplanar:
		verdict = "flat untextured colour"
	if verdict != "":
		white.append({"scene": scene, "node": str(level.get_path_to(node)), "size": "%.0fx%.0fx%.0f" % [size.x, size.y, size.z], "verdict": verdict})
		print("WHITE/BLOCKOUT %s %s %s" % [scene, level.get_path_to(node), verdict])
