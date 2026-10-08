extends Node

## Asset-backed audio with bounded spatial voices and scene-safe dialogue.
const MAX_SPATIAL_VOICES := 24
var music_player: AudioStreamPlayer
var dialogue_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var spatial_players: Array[AudioStreamPlayer3D] = []
var dialogue_catalog: Dictionary = {}
var story_aliases: Dictionary = {}
var _dialogue_scene: Node
var _missing_logged: Dictionary = {}
var _last_step := -1
var _duck_music_db := 0.0
var _duck_ambience_db := 0.0
var _duck_active := false
var dialogue_serial := 0
var _event_last_played: Dictionary = {}
var _event_scene_id := 0
## Narration (chapter recaps) survives scene changes; regular dialogue is scene-bound.
var _dialogue_persistent := false
## Mix levels re-balanced for the AUDIO_REPORT.md mastering pass (dialogue ~+2.5 dB, SFX +3..+12 dB).
const DIALOGUE_DB := -5.5
const DUCK_MUSIC_DB := 6.0
const DUCK_AMBIENCE_DB := 4.0

func _ready() -> void:
	for bus_name in ["Music", "Dialogue", "SFX", "Ambience", "UI", "Radio", "ReverbSend", "Underwater"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	dialogue_player = AudioStreamPlayer.new()
	dialogue_player.bus = "Dialogue"
	dialogue_player.volume_db = DIALOGUE_DB
	# Keeps playing while the tree is paused (story transition cards, pause menu narration).
	dialogue_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialogue_player)
	dialogue_player.finished.connect(_restore_mix)
	var manifest := "res://audio/dialogue_manifest.json"
	if FileAccess.file_exists(manifest):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if parsed is Dictionary:
			dialogue_catalog = parsed
	var event_file := "res://audio/campaign_events.json"
	if FileAccess.file_exists(event_file):
		var event_data = JSON.parse_string(FileAccess.get_file_as_string(event_file))
		if event_data is Dictionary:
			story_aliases = event_data.get("aliases", {})
	print("[AUDIO] Asset-backed audio initialized; %d dialogue entries." % dialogue_catalog.size())

func _process(_delta: float) -> void:
	if dialogue_player.playing and not _dialogue_persistent and (not is_instance_valid(_dialogue_scene) or _dialogue_scene != get_tree().current_scene):
		stop_dialogue()

func stop_dialogue() -> void:
	dialogue_serial += 1
	dialogue_player.stop()
	_dialogue_persistent = false
	_restore_mix()

func _restore_mix() -> void:
	if not _duck_active:
		return
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _duck_music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), _duck_ambience_db)
	_duck_active = false

func play_dialogue(dialogue_id: String, hud: Node, speaker: String, text: String, fallback_duration: float = 3.5) -> float:
	stop_dialogue()
	var duration := fallback_duration
	var entry: Dictionary = dialogue_catalog.get(dialogue_id, {})
	speaker = entry.get("speaker", speaker)
	text = entry.get("text", text)
	var path: String = entry.get("path", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			duration = stream.get_length() + 0.2
			dialogue_player.stream = stream
			dialogue_player.bus = "Radio" if entry.get("radio", false) else "Dialogue"
			_dialogue_scene = get_tree().current_scene
			_dialogue_persistent = bool(entry.get("narration", false)) or dialogue_id.begins_with("REC_")
			_duck_music_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
			_duck_ambience_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))
			_duck_active = true
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _duck_music_db - DUCK_MUSIC_DB)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), _duck_ambience_db - DUCK_AMBIENCE_DB)
			dialogue_player.play()
	elif not _missing_logged.has(dialogue_id):
		_missing_logged[dialogue_id] = true
		push_warning("[AUDIO] Unproduced dialogue %s; using canonical subtitle fallback." % dialogue_id)
	if is_instance_valid(hud):
		hud.show_subtitle(speaker, text, duration)
	return duration

func play_story_line(speaker: String, text: String, duration: float = 3.5, hud: Node = null) -> float:
	if not is_instance_valid(hud) and is_instance_valid(get_tree().current_scene):
		hud = get_tree().current_scene.get_node_or_null("HUD")
	var dialogue_id: String = story_aliases.get(text, "")
	if dialogue_id.is_empty():
		# Preserve subtitle coverage for unsupported legacy lines.
		if is_instance_valid(hud):
			hud.show_subtitle(speaker, text, duration)
		return duration
	return play_dialogue(dialogue_id, hud, speaker, text, duration)

func play_sfx(event_id: String, global_pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	if _event_scene_id != scene.get_instance_id():
		_event_scene_id = scene.get_instance_id()
		_event_last_played.clear()
	var cooldown := 0.75 if event_id in ["splash", "splash_exit"] else 0.6 if event_id == "swim" else 6.0 if event_id in ["breath", "collapse"] else 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0.0 and now - float(_event_last_played.get(event_id, -100.0)) < cooldown:
		return
	if event_id == "footstep_stone":
		if not is_instance_valid(get_tree().current_scene):
			return
		# Surface-aware footsteps (mud/water/wet_rock/stone/grass) when the level has a Soundscape.
		var soundscape := _find_soundscape(scene)
		if soundscape:
			soundscape.footstep(global_pos)
			return
		var variant := randi_range(1, 4)
		if variant == _last_step:
			variant = (variant % 4) + 1
		_last_step = variant
		var scene_name: String = get_tree().current_scene.name
		var path := "res://audio/footsteps/stone/FOL_STONE_STEP_%02d.wav" % variant
		if scene_name in ["Prologue", "Chapter4"]:
			path = "res://audio/footsteps/rock/FOL_PRO_WET_ROCK_STEP_%02d.wav" % variant
		elif scene_name in ["Chapter1", "Finale"]:
			path = "res://audio/footsteps/grass/FOL_JUNGLE_STEP_%02d.wav" % variant
		if ResourceLoader.exists(path):
			play_sound_3d(load(path), global_pos, -15.0, "SFX", 10.0)
		return
	var event_paths := {
		"fire": "res://audio/combat/SFX_COMBAT_FIRE.wav",
		"reload": "res://audio/combat/SFX_COMBAT_RELOAD.wav",
		"impact": "res://audio/combat/SFX_COMBAT_IMPACT.wav",
		"melee": "res://audio/combat/SFX_COMBAT_TAKEDOWN.wav",
		"takedown": "res://audio/combat/SFX_COMBAT_TAKEDOWN.wav",
		"splash": "res://audio/water/SFX_WATER_ENTRY.wav",
		"splash_exit": "res://audio/water/SFX_WATER_EXIT_SPLASH.wav",
		"swim": "res://audio/water/SFX_SWIM_STROKE.wav",
		"breath": "res://audio/movement/FOL_BREATH_RUNNING.wav",
		"collapse": "res://audio/destruction/SFX_ROCK_COLLAPSE.wav"
	}
	var path: String = event_paths.get(event_id, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		_event_last_played[event_id] = now
		# Remastered one-shots are hotter: impact/takedown gained up to +12 dB, others ~+3 dB.
		var gain := -8.0 if event_id == "fire" else -11.0 if event_id == "collapse" else -24.0 if event_id in ["impact", "melee", "takedown"] else -17.0
		play_sound_3d(load(path), global_pos, gain, "SFX", 50.0 if event_id in ["fire", "collapse"] else 14.0)

func play_sound_3d(stream: AudioStream, global_pos: Vector3, max_db: float = -8.0, bus: String = "SFX", max_distance: float = 20.0) -> void:
	if not stream or not is_instance_valid(get_tree().current_scene):
		return
	spatial_players = spatial_players.filter(func(p): return is_instance_valid(p))
	if spatial_players.size() >= MAX_SPATIAL_VOICES:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "SFX"
	player.volume_db = max_db
	player.unit_size = 2.0
	player.max_distance = max_distance
	get_tree().current_scene.add_child(player)
	player.global_position = global_pos
	spatial_players.append(player)
	player.finished.connect(func(): player.queue_free())
	player.play()

func _find_soundscape(scene: Node) -> Node:
	for child in scene.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path == "res://systems/audio/Soundscape.gd" and child.has_method("footstep"):
			return child
	return null
