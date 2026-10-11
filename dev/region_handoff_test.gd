extends SceneTree
## Unified world: Ch5 -> aqueduct -> Ch6 walked with real input, no swap card/respawn/reset.
## Needs a window for mouse capture + screenshots:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility -s res://dev/region_handoff_test.gd -- --out=<dir>

var fails := 0
var out := ""
var frame_ms: Array[float] = []
var base_worst := 0.0

func _check(label: String, ok: bool, info := "") -> void:
	print("HANDOFF ", "PASS " if ok else "FAIL ", label, " ", info)
	if not ok:
		fails += 1

func _snap(name: String) -> void:
	if out != "":
		root.get_viewport().get_texture().get_image().save_png(out.path_join(name))

func _init() -> void:
	call_deferred("_run")

func _frame() -> void:
	var f0 := Time.get_ticks_usec()
	await process_frame
	frame_ms.append((Time.get_ticks_usec() - f0) / 1000.0)

## Steers toward `target` with move inputs relative to the camera, like a player would.
func _walk_to(player: Node3D, target: Vector3, label: String, max_frames := 900) -> bool:
	for i in max_frames:
		var off := target - player.global_position
		off.y = 0.0
		if off.length() < 0.9:
			_release()
			return true
		var dir: Vector3 = player.camera_pivot.global_basis.inverse() * off.normalized()
		_release()
		Input.action_press("move_right" if dir.x > 0.0 else "move_left", absf(dir.x))
		Input.action_press("move_back" if dir.z > 0.0 else "move_forward", absf(dir.z))
		# Turn the camera to face travel so screenshots look where Mara walks.
		var cam_dir := off.normalized()
		player.camera_pivot.yaw = lerp_angle(player.camera_pivot.yaw, atan2(-cam_dir.x, -cam_dir.z), 0.08)
		await _frame()
		if i % 150 == 0:
			print("HANDOFF walking ", label, " pos=", player.global_position, " floor=", player.is_on_floor())
	_release()
	_snap("stuck_%s.png" % label.replace(" ", "_"))
	_check("reach " + label, false, str(player.global_position))
	return false

func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var gm := root.get_node("GameManager")
	var mm := root.get_node("MissionManager")
	var sm := root.get_node("SaveManager")
	change_scene_to_file("res://levels/Chapter5.tscn")
	for i in 60:
		await physics_frame
	var ch5 := current_scene
	var player = ch5.get_node("Player")
	player.global_position = ch5.get_node("ObservationPerch/DrakeTrigger").global_position + Vector3(0, -1.0, 0)
	for i in 30:
		await physics_frame
	_check("Ch5 side: save before staging", sm.save_game(0))
	frame_ms.clear()
	for i in 60:
		await _frame()
	var base_sorted := frame_ms.duplicate()
	base_sorted.sort()
	print("HANDOFF baseline Ch5 frames (this renderer): median %.0f ms, worst %.0f ms" % [base_sorted[30], base_sorted[-1]])
	base_worst = base_sorted[-1]
	# Ghosting the patrol: reaching the perch observes Drake and stages Ch6.
	await physics_frame
	_check("drake observed + temple staged", ch5.has_seen_drake and ch5.temple != null)
	var temple: Node3D = ch5.temple
	frame_ms.clear()
	var waited := 0
	while not temple.is_built and waited < 1200:
		await _frame()
		waited += 1
	var build_max: float = frame_ms.max() if frame_ms.size() else 0.0
	var over_100 := frame_ms.filter(func(v): return v > 100.0).size()
	print("HANDOFF staged build: %d frames, worst %.0f ms, frames >100ms: %d" % [frame_ms.size(), build_max, over_100])
	_check("staged build completed", temple.is_built, "frames=%d" % waited)
	_check("still in Ch5 while staged", current_scene == ch5 and gm.current_chapter != 6)
	_check("save refused while staged (rebased coords)", not sm.manual_save())
	# This test covers the boundary, not stealth: take the patrol out so it can't shoot Mara.
	for e in ch5.get_node("Enemies").get_children():
		if e.has_method("die"):
			e.die()
	player.current_health = 63.0
	player.set("ammunition", 7)
	var player_id: int = player.get_instance_id()
	var hud_id: int = ch5.hud.get_instance_id() if ch5.hud else 0
	# Walk from the perch to the gate and through the aqueduct.
	var gate: Vector3 = ch5.get_node("TempleEntrance").global_position
	frame_ms.clear()
	var pivot_jump := 0.0
	var last_rel: Vector3 = player.camera_pivot.global_position - player.global_position
	if not await _walk_to(player, gate + Vector3(0, 0, 6), "gate approach"): return _done()
	_snap("seam_01_gate.png")
	var aq: Node3D = temple.get_node("Ch5Ch6Aqueduct")
	for wp in ["QA_AqA", "QA_AqB"]:
		if not await _walk_to(player, aq.get_node(wp).global_position, wp): return _done()
		_snap("seam_02_%s.png" % wp)
		var rel: Vector3 = player.camera_pivot.global_position - player.global_position
		pivot_jump = maxf(pivot_jump, rel.distance_to(last_rel))
		last_rel = rel
	var act: Vector3 = aq.get_node("RegionActivation").global_position
	if not await _walk_to(player, act + Vector3(0, 0, -1.5), "activation"): return _done()
	for i in 20:
		await _frame()
	_check("Ch6 active after aqueduct", current_scene == temple and gm.current_chapter == 6 and temple.is_active)
	if not await _walk_to(player, Vector3(0, 1.0, 22.5), "temple landing"): return _done()
	for i in 120:
		await _frame()
	_snap("seam_03_landing.png")
	var walk_max: float = frame_ms.max()
	print("HANDOFF walk+activation: %d frames, worst %.0f ms, frames >100ms: %d" % [frame_ms.size(), walk_max, frame_ms.filter(func(v): return v > 100.0).size()])
	_check("same Player instance", is_instance_valid(player) and player.get_instance_id() == player_id and player.get_parent() == temple)
	_check("same HUD instance", temple.hud and temple.hud.get_instance_id() == hud_id)
	_check("health preserved", is_equal_approx(player.current_health, 63.0), str(player.current_health))
	_check("ammo preserved", player.get("ammunition") == 7, str(player.get("ammunition")))
	_check("Ch6 objective active", mm.active_objectives.has("obj_c06_drain_temple"), str(mm.active_objectives.keys()))
	_check("old region released", not is_instance_valid(ch5))
	_check("single player", get_nodes_in_group("player").size() == 1)
	_check("wind preset switched to CAVE", WindSystem.current_preset == WindSystem.Preset.CAVE, str(WindSystem.current_preset))
	_check("Ch6 soundscape running", temple.get_node_or_null("Soundscape") != null)
	_check("on landing floor", player.is_on_floor() and absf(player.global_position.y - 1.0) < 0.3, str(player.global_position))
	# Absolute frame times are meaningless on a software renderer; compare to this run's own
	# Ch5 baseline. A blocking build would show as a frame far above it.
	_check("no frame >1.5x renderer baseline during walk/activation", walk_max < base_worst * 1.5 + 50.0, "%.0f ms vs baseline worst %.0f ms" % [walk_max, base_worst])
	# Ch6 side save/load: a standalone Ch6 load must put Mara back on the landing.
	var saved_pos: Vector3 = player.global_position
	_check("Ch6 side: manual save accepted", sm.manual_save())
	_check("load_game ok", sm.load_game(0))
	gm.load_chapter(6, "res://levels/Chapter6.tscn")
	var t := 0
	while t < 1500 and not (current_scene and current_scene != temple and current_scene.name == "Chapter6" and current_scene.get("is_active")):
		await process_frame
		t += 1
	for i in 120:
		await physics_frame
	var p2 = get_first_node_in_group("player")
	_check("reloaded into Ch6", current_scene and current_scene.name == "Chapter6" and p2 != null)
	if p2:
		_check("reloaded position matches save", p2.global_position.distance_to(saved_pos) < 0.5, "%s vs %s" % [p2.global_position, saved_pos])
		_check("standalone Ch6 aqueduct sealed by rockfall", current_scene.aqueduct.rockfall.visible)
	_done()

func _done() -> void:
	print("HANDOFF RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
