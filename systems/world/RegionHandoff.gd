extends RefCounted
## Seamless region-to-region handoff (unified-world prototype).
##
## The next region is threaded-loaded in the background while the player is still in the
## current one. At the threshold the current region root is translated so the player's
## position lines up with the next region's entry point (player, camera and lights move
## together, so nothing visibly jumps), the persistent Player/CameraController/HUD nodes are
## moved into the new region in place of its own copies, and the old region is freed.
## The new region stays at its authored origin, so saves and checkpoints remain valid.

const PERSISTENT := ["Player", "CameraController", "HUD"]

const MANIFEST := "res://content/region_manifests.json"

## Starts background loading of the region scene and every asset its _ready loads
## synchronously (content/region_manifests.json, built by scripts/build_region_manifests.py).
static func prepare(scene_path: String) -> void:
	var paths: Array = [scene_path]
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	if manifest is Dictionary:
		paths.append_array(manifest.get(scene_path, []))
	for path in paths:
		if ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path, "", true)

## `entry` is the floor point (new-region coords) where the player should stand.
static func hand_off(from: Node3D, chapter: int, scene_path: String, entry: Vector3) -> Node3D:
	var tree := from.get_tree()
	var t0 := Time.get_ticks_usec()
	prepare(scene_path)
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	var player := from.get_node("Player") as Node3D
	# 1. Shift the whole old region so the player stands on the entry point.
	var p := player.global_position
	var delta := Vector3(entry.x - p.x if absf(p.x - entry.x) > 3.0 else 0.0, entry.y - p.y, entry.z - p.z)
	# top_level nodes (the follow camera) ignore the parent transform, so move them explicitly.
	var detached: Array[Node3D] = []
	for n in from.find_children("*", "Node3D", true, false):
		if (n as Node3D).top_level:
			detached.append(n)
	from.global_position += delta
	for n in detached:
		n.global_position += delta
	# 2. Build the next region with the persistent nodes swapped in before its _ready runs.
	var next := packed.instantiate() as Node3D
	for node_name in PERSISTENT:
		var own := next.get_node_or_null(node_name)
		var index := own.get_index() if own else -1
		if own:
			next.remove_child(own)
			own.free()
		var moving := from.get_node_or_null(node_name)
		if not moving:
			continue
		var xform: Transform3D = moving.global_transform if moving is Node3D else Transform3D()
		from.remove_child(moving)
		next.add_child(moving)
		if index >= 0:
			next.move_child(moving, mini(index, next.get_child_count() - 1))
		if moving is Node3D:
			moving.global_transform = xform
	# 3. Mission bookkeeping that GameManager.load_chapter would do, minus the scene swap.
	GameManager.current_chapter = chapter
	MissionManager.active_objectives.clear()
	var t1 := Time.get_ticks_usec()
	tree.root.add_child(next)
	print("[REGION] handoff to %s: instantiate %.1f ms, enter+ready %.1f ms" % [scene_path, (t1 - t0) / 1000.0, (Time.get_ticks_usec() - t1) / 1000.0])
	tree.current_scene = next
	from.queue_free()
	GameManager.chapter_changed.emit(chapter)
	MissionManager.set_checkpoint("chapter_%02d_start" % chapter, player.global_transform)
	return next


## --- Co-present staging (no visible swap) ---------------------------------------------
## stage(): the next region is added beside the current one while Mara is still in it.
## The current region is rebased so `from_floor` (a floor point in it, e.g. its exit gate)
## coincides with `to_floor` in the next region's authored space; a connector built by the
## next region joins the two. The next region's _ready builds over several frames
## (`staged = true`) and its gameplay waits for activate().
static func stage(from: Node3D, scene_path: String, from_floor: Vector3, to_floor: Vector3) -> Node3D:
	var tree := from.get_tree()
	prepare(scene_path)
	var t0 := Time.get_ticks_usec()
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	_shift_region(from, to_floor - from_floor)
	var next := packed.instantiate() as Node3D
	next.set("staged", true)
	_swap_persistent(from, next)
	# Saves taken now would record the rebased old region; SaveManager refuses while this is set.
	from.set("transition_started", true)
	tree.root.add_child(next)
	# Only one sun at a time: the next region's directional lights wait for activation.
	for l in next.find_children("*", "DirectionalLight3D", true, false):
		if l.visible:
			l.visible = false
			l.set_meta("region_light", true)
	print("[REGION] staged %s in %.1f ms (world builds over following frames)" % [scene_path, (Time.get_ticks_usec() - t0) / 1000.0])
	return next

## Called when Mara crosses the connector's activation volume (both ends out of sight).
static func activate(from: Node3D, next: Node3D, chapter: int) -> void:
	if not is_instance_valid(next) or next.get("is_active"):
		return
	var tree := next.get_tree()
	if not next.get("is_built"):
		await next.built
	GameManager.current_chapter = chapter
	MissionManager.active_objectives.clear()
	tree.current_scene = next
	for l in next.find_children("*", "DirectionalLight3D", true, false):
		if l.get_meta("region_light", false):
			l.visible = true
	if is_instance_valid(from):
		for l in from.find_children("*", "DirectionalLight3D", true, false):
			l.visible = false
	next.activated.emit()
	GameManager.chapter_changed.emit(chapter)
	var player := next.get_node("Player") as Node3D
	MissionManager.set_checkpoint("chapter_%02d_start" % chapter, player.global_transform)
	if is_instance_valid(from):
		# Fade the old region's ambience out, then release it (WorldEnvironment falls back to the
		# next region's automatically when the old one leaves the tree).
		var tw := next.create_tween().set_parallel(true)
		for a in from.find_children("*", "AudioStreamPlayer*", true, false):
			tw.tween_property(a, "volume_db", -60.0, 1.5)
		tw.chain().tween_callback(from.queue_free)

static func _shift_region(from: Node3D, delta: Vector3) -> void:
	var detached: Array[Node3D] = []
	for n in from.find_children("*", "Node3D", true, false):
		if (n as Node3D).top_level:
			detached.append(n)
	from.global_position += delta
	for n in detached:
		n.global_position += delta

static func _swap_persistent(from: Node3D, next: Node3D) -> void:
	for node_name in PERSISTENT:
		var own := next.get_node_or_null(node_name)
		var index := own.get_index() if own else -1
		if own:
			next.remove_child(own)
			own.free()
		var moving := from.get_node_or_null(node_name)
		if not moving:
			continue
		var xform: Transform3D = moving.global_transform if moving is Node3D else Transform3D()
		from.remove_child(moving)
		next.add_child(moving)
		if index >= 0:
			next.move_child(moving, mini(index, next.get_child_count() - 1))
		if moving is Node3D:
			moving.global_transform = xform
