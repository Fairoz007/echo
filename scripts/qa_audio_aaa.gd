extends SceneTree
## Headless audio-pass check: compiles audio systems, verifies every manifest/preset path exists on disk.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fails := 0
	for p in ["res://systems/audio/AudioBuses.gd", "res://systems/audio/ReverbZone.gd", "res://systems/audio/Soundscape.gd",
			"res://systems/audio/ChapterRecap.gd", "res://systems/CampaignDialogue.gd", "res://systems/PrologueSoundscape.gd"]:
		var s = load(p)
		print("checked ", p, " ", s != null)
		if s == null or not (s as Script).can_instantiate():
			printerr("COMPILE FAIL ", p); fails += 1
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://audio/dialogue_manifest.json"))
	var n := 0
	for id in m:
		n += 1
		var st = load(m[id]["path"]) if ResourceLoader.exists(m[id]["path"]) else null
		if not st is AudioStream or absf(st.get_length() - float(m[id]["duration"])) > 0.1 or m[id].get("cues", []).is_empty():
			printerr("MISSING ", id); fails += 1
	var sc = JSON.parse_string(FileAccess.get_file_as_string("res://audio/campaign_soundscapes.json"))
	for ch in sc["chapters"]:
		for e in sc["chapters"][ch]["beds"] + sc["chapters"][ch]["emitters"] + sc["chapters"][ch]["oneshots"]:
			if not ResourceLoader.exists(e["path"]) or not load(e["path"]) is AudioStream:
				printerr("MISSING ", ch, " ", e["path"]); fails += 1
	var ev = JSON.parse_string(FileAccess.get_file_as_string("res://audio/campaign_events.json"))
	for a in ev["aliases"]:
		if not m.has(ev["aliases"][a]):
			printerr("ALIAS ", a); fails += 1
	print("AUDIO_AAA_QA dialogue=%d recaps=%d fails=%d" % [n, ev["recaps"].size(), fails])
	fails += await _runtime()
	print("AUDIO_AAA_QA_RUNTIME fails=%d" % fails)
	quit(1 if fails else 0)

func _runtime() -> int:
	var f := 0
	var level := Node3D.new()
	level.name = "QALevel"
	root.add_child(level)
	current_scene = level
	var cam := Camera3D.new()
	level.add_child(cam)
	for ch in ["PRO", "C01", "C06", "C07", "C10", "EPI"]:
		var sc = load("res://systems/audio/Soundscape.gd").attach(level, ch)
		await process_frame
		var playing := 0
		for c in sc.get_children():
			if (c is AudioStreamPlayer or c is AudioStreamPlayer3D) and c.playing:
				playing += 1
		print("soundscape ", ch, " layers playing=", playing, " reverb_wet=", AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX"), 0).wet)
		if playing == 0: f += 1
		if ch == "C06":
			sc.set_water_state("rising", Vector3(0, 0, -5)); await create_timer(0.3).timeout
			sc.set_water_state("draining", Vector3(0, 0, -5)); await create_timer(0.3).timeout
			sc.footstep(Vector3.ZERO, "water"); sc.footstep(Vector3.ZERO, "mud")
			sc.add_reverb_zone(Vector3.ZERO, Vector3(4, 4, 4), "temple")
			sc.set_underwater(true); sc.set_underwater(false)
		sc.queue_free()
		await process_frame
	var d: float = load("res://systems/audio/ChapterRecap.gd").play("C03", null)
	print("recap C03 duration=", d, " playing=", root.get_node("AudioManager").dialogue_player.playing, " bus=", root.get_node("AudioManager").dialogue_player.bus)
	if d <= 1.0 or not root.get_node("AudioManager").dialogue_player.playing: f += 1
	print("buses: ", range(AudioServer.bus_count).map(func(i): return "%s->%s fx%d" % [AudioServer.get_bus_name(i), AudioServer.get_bus_send(i), AudioServer.get_bus_effect_count(i)]))
	return f
