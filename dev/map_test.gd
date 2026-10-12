extends SceneTree
## DEV QA: mini-map + world map in every region of the campaign.
## Checks position/heading accuracy against the live Player, map alignment with real geometry
## (baked floor height under Mara == her feet), fog reveal, objective markers, layer switching,
## world-map open/close input state, waypoint, save/load persistence, Ch7 districts, frame cost.
## Usage: xvfb-run godot --path . --rendering-method gl_compatibility -s res://dev/map_test.gd [-- --only=7 --shots]
const OUT := "res://screenshots/map/"
var gm: Node
var wm: Node
var passed := 0
var failed := 0
var shots := false

func _init() -> void:
	call_deferred("_run")

func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%-58s %-40s %s" % [label, detail, "PASS" if ok else "FAIL"])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _shot(name: String) -> void:
	if not shots:
		return
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))

func _run() -> void:
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = int(a.substr(7))
		if a == "--shots":
			shots = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	gm = root.get_node("GameManager")
	wm = root.get_node("WorldMapManager")
	var gs = root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_quality"):
		gs.apply_quality(1, false)
	for reg in wm.regions:
		var ch: int = int(reg["chapter"])
		if only >= 0 and ch != only:
			continue
		await _region(reg)
	if only < 0 or only == 1:
		await _persistence()
	print("MAP_TEST %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _load(reg: Dictionary) -> Node3D:
	gm.current_chapter = int(reg["chapter"])
	change_scene_to_file(reg["scene"])
	await _frames(90)
	gm.change_state(gm.GameState.GAMEPLAY)
	paused = false
	await _frames(30)
	return current_scene as Node3D

func _region(reg: Dictionary) -> void:
	var rid: String = reg["id"]
	var lvl := await _load(reg)
	var p := lvl.get_node_or_null("Player") as CharacterBody3D
	if p == null:
		_check(rid + ": player present", false)
		return
	for i in 120:
		if p.is_on_floor():
			break
		await physics_frame
	_check(rid + ": region resolved", wm.current_region_id() == rid, wm.current_region_id())
	var local: Vector3 = lvl.to_local(p.global_position)
	var mp: Vector2 = wm.player_map_pos()
	var back: Vector2 = wm.map_to_local(rid, mp)
	_check(rid + ": map<->local round trip", back.distance_to(Vector2(local.x, local.z)) < 0.01, "%.3f m" % back.distance_to(Vector2(local.x, local.z)))
	var layer: String = wm.player_layer()
	var fh: float = wm.floor_height(rid, layer, Vector2(local.x, local.z))
	# Sample a 1 m neighbourhood: the 8-bit height grid quantises and the capsule may sit on a prop edge.
	var best := INF
	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 0.0, 1.0]:
			var h: float = wm.floor_height(rid, layer, Vector2(local.x + dx, local.z + dz))
			if not is_nan(h):
				best = minf(best, absf(h - local.y))
	var span: float = float(wm.layer_info(rid, layer).get("y_max", 0.0)) - float(wm.layer_info(rid, layer).get("y_min", 0.0))
	_check(rid + ": map floor matches Mara's feet", best <= 0.6 + span / 255.0, "map %.2f / feet %.2f (best %.2f)" % [fh, local.y, best])
	# Heading: face the four compass points; map north = local -Z.
	var hd_ok := true
	var worst := 0.0
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		p.facing_yaw = yaw
		await _frames(3)
		var f: Vector3 = lvl.global_basis.inverse() * p.get_facing_forward()
		var expected := atan2(f.x, -f.z)
		var err := absf(wrapf(wm.player_heading() - expected, -PI, PI))
		worst = maxf(worst, err)
		hd_ok = hd_ok and err < 0.02
	_check(rid + ": heading matches facing", hd_ok, "worst %.3f rad" % worst)
	await _frames(20)
	_check(rid + ": fog revealed around Mara", wm.is_revealed(rid, local) and wm.discovered_regions.has(rid), "%.1f%% surveyed" % (wm.revealed_fraction(rid) * 100.0))
	var hud := lvl.get_node_or_null("HUD")
	var mini = hud.get_node_or_null("MiniMap") if hud else null
	await process_frame
	_check(rid + ": HUD mini-map visible", mini != null and mini.visible)
	if mini:
		var obj: Control = hud.get_node("TopRightMargin/ObjectiveLabel")
		var r1 := Rect2(mini.global_position, Vector2(mini.DIAMETER, mini.DIAMETER))
		_check(rid + ": mini-map does not cover objective", not r1.intersects(obj.get_global_rect()) or not obj.visible, str(obj.get_global_rect()))
	var markers: Array = wm.get_markers()
	var n_obj := 0
	for m in markers:
		if m["type"] == "objective":
			n_obj += 1
	var expect_obj := false
	for oid in root.get_node("MissionManager").active_objectives:
		for path in wm.targets.get(oid, []):
			if lvl.get_node_or_null(str(path)):
				expect_obj = true
	_check(rid + ": objective marker(s)", n_obj > 0 or not expect_obj, "%d objective / %d markers" % [n_obj, markers.size()])
	await _shot(rid + "_hud")
	# Layers: walk every layer band present and check auto-selection.
	if reg.get("layers", []).size() > 1:
		for l in wm.by_id[rid]["layers"]:
			var y := lerpf(float(l["y_min"]), float(l["y_max"]), 0.5)
			_check(rid + ": layer auto-select " + str(l["id"]), wm.layer_for(rid, float(l["y_min"]) + 0.1) == l["id"], "y %.1f" % y)
	# World map: open with the "map" action, gameplay paused, close restores.
	var ev := InputEventAction.new()
	ev.action = "map"
	ev.pressed = true
	root.get_viewport().push_input(ev)
	await process_frame
	await process_frame
	_check(rid + ": M opens world map (paused)", gm.world_map.visible and paused, "paused=%s" % paused)
	var before := p.global_position
	Input.action_press("move_forward")
	Input.action_press("fire")
	await process_frame
	await process_frame
	_check(rid + ": no movement while map open", p.global_position.distance_to(before) < 0.01)
	Input.action_release("move_forward")
	Input.action_release("fire")
	# Waypoint 15 m east of Mara via the map's own placement path.
	var screen: Vector2 = gm.world_map.view.map_to_screen(mp + Vector2(15, 0))
	gm.world_map._place(screen)
	await _frames(1)
	var wi: Dictionary = wm.waypoint_info()
	_check(rid + ": waypoint placed + distance", not wi.is_empty() and wi["same_region"] and absf(wi["distance"] - Vector2(15, 0).length()) < 6.0, str(wi.get("distance", -1)))
	await _shot(rid + "_map")
	var ev2 := InputEventAction.new()
	ev2.action = "map"
	ev2.pressed = true
	root.get_viewport().push_input(ev2)
	await process_frame
	await process_frame
	_check(rid + ": M closes map, unpaused", not gm.world_map.visible and not paused and hud.visible)
	if rid == "city":
		await _city_districts(lvl, p)
	if rid == "temple":
		await _frame_cost(hud)
	wm.clear_waypoint()

func _city_districts(lvl: Node3D, p: CharacterBody3D) -> void:
	for lm in wm.by_id["city"].get("landmarks", []):
		var n := lvl.get_node_or_null(str(lm["path"])) as Node3D
		if n == null:
			_check("city: landmark " + str(lm["name"]), false, "missing node")
			continue
		p.global_position = n.global_position + Vector3(0, 3, 0)
		p.velocity = Vector3.ZERO
		await _frames(45)
		var key: String = "city:lm_" + str(lm["path"])
		_check("city: district discovered " + str(lm["name"]), wm.discovered_pois.has(key) and wm.is_revealed("city", lvl.to_local(p.global_position)), "%.0f%% surveyed" % (wm.revealed_fraction("city") * 100.0))
		await _shot("city_" + str(lm["path"]).get_file())

func _frame_cost(hud: Node) -> void:
	var mini: Control = hud.get_node("MiniMap")
	var t_on := []
	var t_off := []
	for pass_i in 2:
		mini.process_mode = Node.PROCESS_MODE_INHERIT if pass_i == 0 else Node.PROCESS_MODE_DISABLED
		mini.visible = pass_i == 0
		await _frames(10)
		for i in 60:
			var t0 := Time.get_ticks_usec()
			if pass_i == 0:
				mini._process(0.016)
			wm._process(0.016)
			(t_on if pass_i == 0 else t_off).append((Time.get_ticks_usec() - t0) / 1000.0)
			await process_frame
	mini.process_mode = Node.PROCESS_MODE_INHERIT
	t_on.sort()
	t_off.sort()
	print("PERF map CPU per frame: minimap+manager median %.3f ms p95 %.3f ms | manager only median %.3f ms" % [t_on[30], t_on[57], t_off[30]])
	_check("temple: map CPU cost < 1.5 ms (median)", t_on[30] < 1.5, "%.3f ms" % t_on[30])

func _persistence() -> void:
	var sm := root.get_node("SaveManager")
	var reg: Dictionary = wm.by_id["camp_ridge"]
	var lvl := await _load(reg)
	var p := lvl.get_node("Player") as CharacterBody3D
	p.global_position += Vector3(20, 2, -20)
	await _frames(40)
	wm.set_waypoint_map(wm.player_map_pos() + Vector2(-10, 10))
	var frac: float = wm.revealed_fraction("camp_ridge")
	var wp: Dictionary = wm.waypoint.duplicate(true)
	var n_regions: int = wm.discovered_regions.size()
	sm.save_directory = "user://map_test/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://map_test/"))
	_check("persist: save", sm.save_game(3))
	wm.reset()
	_check("persist: reset clears fog", wm.revealed_fraction("camp_ridge") == 0.0 and wm.waypoint.is_empty())
	_check("persist: load", sm.load_game(3))
	_check("persist: fog restored", absf(wm.revealed_fraction("camp_ridge") - frac) < 0.0001, "%.4f vs %.4f" % [wm.revealed_fraction("camp_ridge"), frac])
	_check("persist: waypoint restored", wm.waypoint.get("region", "") == wp["region"] and (wm.waypoint["pos"] as Array)[0] == (wp["pos"] as Array)[0])
	_check("persist: discovered regions restored", wm.discovered_regions.size() == n_regions, str(wm.discovered_regions))
	sm.restore_pending = false
	sm.save_directory = "user://"
