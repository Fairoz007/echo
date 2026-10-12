extends SceneTree
## Chapter 7 City of Echoes functional test (headless OK): main seals, gate gating, the
## three tombs (incl. failure/recovery), and save-state round trip.
var fails := 0
func _check(label: String, ok: bool, info := "") -> void:
	print("CH7 ", "PASS " if ok else "FAIL ", label, " ", info)
	if not ok:
		fails += 1
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	change_scene_to_file("res://levels/Chapter7.tscn")
	for i in 120:
		await physics_frame
	var lvl := current_scene
	var city = lvl.city
	var player = lvl.get_node("Player")
	var mm := root.get_node("MissionManager")
	_check("city built", city != null and city.get_node_or_null("PlazaDistrict") != null and city.get_node_or_null("ResonantChamber") != null)
	for d in ["PlazaDistrict", "ScholarsQuarter", "EchoGardens", "TempleDistrict", "CollapsedAqueduct", "MeridianForwardCamp", "CausewayGate", "HallOfWeights", "SunkenArchive", "ResonantChamber"]:
		_check("district " + d, city.get_node_or_null(d) != null)
	_check("dial tombs replaced", lvl.get_node_or_null("CampaignExploration") == null)
	lvl._on_mural_examined(player)
	_check("seal objectives open", mm.active_objectives.has("obj_c07_seal_scholar") and mm.active_objectives.has("obj_c07_cut_fuse"), str(mm.active_objectives.keys()))
	# Exit is locked while the gate is shut.
	lvl._on_causeway_exit(player)
	_check("exit locked before gate", not lvl.transition_started)
	# Scholar's Quarter: lectern refuses until all tablets read.
	city._on_lectern()
	_check("lectern needs tablets", not city.seals.scholar)
	for t in city.scholar_tablets:
		t._on_read(player)
	city._on_lectern()
	_check("scholar seal", city.seals.scholar)
	# Echo Gardens: wrong order resets, hymn order (mid, low, high) solves.
	city._strike("low")
	_check("wrong first note resets", city.garden_progress.is_empty() and city.garden_fails == 1)
	for v in ["mid", "low", "high"]:
		city._strike(v)
	_check("garden seal", city.seals.garden)
	# Temple District: altar locked until all four braziers burn together.
	city._on_altar()
	_check("altar locked", not city.seals.temple)
	for i in 4:
		city._light_brazier(i)
	_check("sanctum open", city._temple_open())
	city._on_altar()
	_check("temple seal", city.seals.temple)
	_check("gate still shut without fuse", not city.gate_open)
	city._on_fuse()
	_check("gate opens", city.gate_open and (not is_instance_valid(city.gate_bar) or city.gate_bar.is_queued_for_deletion()))
	_check("cross objective", mm.active_objectives.has("obj_c07_cross_causeway"))
	# Hall of Weights: unequal does nothing; 1+4 vs 2+3 solves.
	city._cycle_weight(0)
	_check("one weight not solved", not city.weights_solved)
	city._reset_weights()
	city._cycle_weight(0); city._cycle_weight(3); city._cycle_weight(3)  # 1 left, 4 right
	city._cycle_weight(1); city._cycle_weight(1)  # 2 right  -> 1 vs 6
	_check("unbalanced not solved", not city.weights_solved)
	city._reset_weights()
	city._cycle_weight(0); city._cycle_weight(3)  # 1,4 left
	city._cycle_weight(1); city._cycle_weight(1); city._cycle_weight(2); city._cycle_weight(2)  # 2,3 right
	_check("hall of weights solved", city.weights_solved and (not is_instance_valid(city.weights_door) or city.weights_door.is_queued_for_deletion()))
	# Sunken Archive: overfill drains (recovery), 3+2+2 = 7 solves.
	for i in 4:
		city._valve(3)
	_check("overfill drains to 0", city.water_level == 0 and not city.archive_solved)
	city._valve(3); city._valve(2); city._valve(2)
	_check("sunken archive solved", city.archive_solved)
	# Resonant Chamber: linked turns; #2 twice, #3 three times from [1,0,2,3].
	city._turn_resonator(0)
	_check("linked turn moves neighbour", city.resonators == [2, 1, 2, 3], str(city.resonators))
	city._turn_resonator(0); city._turn_resonator(0); city._turn_resonator(0)  # back: +4 on 0 and 1 => [1,0,2,3]
	city._turn_resonator(2); city._turn_resonator(2)
	city._turn_resonator(3); city._turn_resonator(3); city._turn_resonator(3)
	_check("resonant chamber solved", city.chamber_solved, str(city.resonators))
	# Persistence: state round-trips into a fresh city.
	var state: Dictionary = city.get_persistent_state()
	var fresh = load("res://systems/levelb/Chapter7City.gd").new()
	root.add_child(fresh)
	fresh.build(lvl)
	fresh.restore_persistent_state(state)
	_check("restore: seals+gate", fresh.seals.values().all(func(v): return v) and fresh.gate_open and (not is_instance_valid(fresh.gate_bar) or fresh.gate_bar.is_queued_for_deletion()))
	_check("restore: tombs", fresh.weights_solved and fresh.archive_solved and fresh.chamber_solved and fresh._temple_open())
	fresh.queue_free()
	lvl._on_causeway_exit(player)
	_check("exit proceeds once gate open", lvl.transition_started)
	print("CH7 RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
