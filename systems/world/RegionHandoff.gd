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

## --- In-world chapter progression (no story card, no scene reload, no new Mara) ---------
const PASSAGE := preload("res://systems/world/SeamlessPassage.gd")

## Walkable boundary: the previous region has an exit passage; when Mara reaches its middle
## leg the next region is built with an identical entry passage behind its spawn, the old
## region is rebased so both passages coincide, and the old region is released.
static func hand_off_passage(from: Node3D, exit_passage: Node3D, chapter: int, scene_path: String) -> Node3D:
	var tree := from.get_tree()
	var t0 := Time.get_ticks_usec()
	prepare(scene_path)
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	var next := packed.instantiate() as Node3D
	var own := next.get_node_or_null("Player") as Node3D
	var spawn: Transform3D = own.transform if own else Transform3D()
	var t_next := PASSAGE.entry_transform(spawn)
	# Rebase the old region (rotation included) so its exit passage lands on the entry copy.
	var delta := t_next * exit_passage.global_transform.affine_inverse()
	var detached: Array[Node3D] = []
	for n in from.find_children("*", "Node3D", true, false):
		if (n as Node3D).top_level:
			detached.append(n)
	from.global_transform = delta * from.global_transform
	for n in detached:
		n.global_transform = delta * n.global_transform
	var cam := from.get_node_or_null("CameraController")
	if cam and "yaw" in cam:
		cam.yaw += delta.basis.get_euler().y
	_swap_persistent(from, next)
	var t1 := Time.get_ticks_usec()
	tree.root.add_child(next)
	var t2 := Time.get_ticks_usec()
	var entry := PASSAGE.create(next, t_next, "EntryPassage")
	PASSAGE.clear_volume(next, entry, spawn.origin)
	_finish(from, next, chapter, true)
	print("[REGION] passage handoff to %s: instantiate %.1f ms, enter+ready %.1f ms, total %.1f ms" % [scene_path, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (Time.get_ticks_usec() - t0) / 1000.0])
	# Late-built region art (deferred dressing) gets the same clearance a moment later.
	tree.create_timer(1.5).timeout.connect(func(): if is_instance_valid(entry): PASSAGE.clear_volume(next, entry, spawn.origin))
	return next

## Scripted boundary (a fall, a cinematic, a flashback): short fade on the same Mara.
static func hand_off_fade(from: Node3D, chapter: int, scene_path: String) -> void:
	var tree := from.get_tree()
	prepare(scene_path)
	var fade := _fade_layer(tree)
	# Freeze Mara for the fade: a scripted fall would otherwise keep falling (to the kill plane).
	var frozen := from.get_node_or_null("Player") as Node3D
	if frozen:
		frozen.set_physics_process(false)
		if "velocity" in frozen:
			frozen.velocity = Vector3.ZERO
	var tw := fade.create_tween()
	tw.tween_property(fade.get_child(0), "color:a", 1.0, 0.6)
	await tw.finished
	var t0 := Time.get_ticks_usec()
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	var next := packed.instantiate() as Node3D
	var own := next.get_node_or_null("Player") as Node3D
	var spawn: Transform3D = own.transform if own else Transform3D()
	_swap_persistent(from, next)
	tree.root.add_child(next)
	var player := next.get_node_or_null("Player") as Node3D
	if player:
		player.global_transform = spawn
		if "velocity" in player:
			player.velocity = Vector3.ZERO
		# A scripted fall ends at the next spawn: forget the fall so landing doesn't hurt.
		if "_air_peak_fall_speed" in player:
			player.set("_air_peak_fall_speed", 0.0)
		player.set_physics_process(true)
		var cam := next.get_node_or_null("CameraController")
		if cam:
			if "yaw" in cam:
				cam.yaw = spawn.basis.get_euler().y
			if cam.has_method("snap_to_target"):
				cam.snap_to_target()
	_finish(from, next, chapter, false)
	print("[REGION] fade handoff to %s in %.1f ms" % [scene_path, (Time.get_ticks_usec() - t0) / 1000.0])
	await tree.process_frame
	var tw2 := fade.create_tween()
	tw2.tween_property(fade.get_child(0), "color:a", 0.0, 0.8)
	tw2.tween_callback(fade.queue_free)

static func _finish(from: Node3D, next: Node3D, chapter: int, keep_old_briefly: bool) -> void:
	var tree := next.get_tree()
	GameManager.current_chapter = chapter
	MissionManager.active_objectives.clear()
	tree.current_scene = next
	if keep_old_briefly:
		for l in from.find_children("*", "DirectionalLight3D", true, false):
			l.visible = false
		var tw := next.create_tween().set_parallel(true)
		for a in from.find_children("*", "AudioStreamPlayer*", true, false):
			tw.tween_property(a, "volume_db", -60.0, 1.0)
		tw.chain().tween_callback(from.queue_free)
	else:
		from.queue_free()
	GameManager.chapter_changed.emit(chapter)
	var player := next.get_node_or_null("Player") as Node3D
	if player:
		MissionManager.set_checkpoint("chapter_%02d_start" % chapter, player.global_transform)
	show_title(tree, chapter)

static func _fade_layer(tree: SceneTree) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	tree.root.add_child(layer)
	return layer

## Non-blocking chapter title: fades in over gameplay and out again; no input needed.
static func show_title(tree: SceneTree, chapter: int) -> void:
	var cards: Dictionary = load("res://ui/StoryTransition.gd").CARDS
	var card: Array = cards.get(chapter, [])
	if card.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "ChapterTitle"
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-300, 90)
	box.custom_minimum_size = Vector2(600, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in [[card[0], 18], [card[1], 40], [card[2], 18]]:
		var l := Label.new()
		l.text = t[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", t[1])
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		box.add_child(l)
	box.modulate.a = 0.0
	layer.add_child(box)
	tree.root.add_child(layer)
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(3.0)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.tween_callback(layer.queue_free)
