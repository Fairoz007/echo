extends Node3D
class_name Soundscape

const _Buses := preload("res://systems/audio/AudioBuses.gd")
const _Zone := preload("res://systems/audio/ReverbZone.gd")

## Scene-owned chapter soundscape. Everything is a child of the level, so it stops with the chapter.
##
## LEVEL API (call from the level's _ready):
##   var sc := Soundscape.attach(self, "C06")             # beds, emitters, random one-shots, chapter reverb
##   sc.add_emitter("res://audio/ambience/lost_city/AMB_WATERFALL_RESONANT_LOOP.ogg", Vector3(4, 2, -30), 0.0, 40.0)
##   sc.add_reverb_zone(Vector3(0, 2, -20), Vector3(12, 6, 30), "cave")  # local reverb override volume
##   sc.set_water_state("rising" | "draining" | "idle", Vector3 position)  # Drowned Temple loops
##   sc.play_oneshot("res://audio/vaelor/SFX_STONE_MECHANISM_GRIND.wav", pos, -6.0)
##   sc.footstep(global_pos, "mud" | "water" | "wet_rock" | "stone" | "grass")  # surface-aware step
##   sc.set_underwater(true/false)                         # lowpass SFX + ambience
## Presets live in res://audio/campaign_soundscapes.json ("chapters" -> key).
const PRESETS := "res://audio/campaign_soundscapes.json"
const STEPS := {
	"mud": "res://audio/footsteps/mud/FOL_MUD_STEP_%02d.wav",
	"water": "res://audio/footsteps/water/FOL_WADE_STEP_%02d.wav",
	"wet_rock": "res://audio/footsteps/rock/FOL_PRO_WET_ROCK_STEP_%02d.wav",
	"stone": "res://audio/footsteps/stone/FOL_STONE_STEP_%02d.wav",
	"grass": "res://audio/footsteps/grass/FOL_JUNGLE_STEP_%02d.wav",
}
var chapter := ""
var preset: Dictionary = {}
var surface := "stone"
var _oneshots: Array = []
var _timers: Array = []
var _water: AudioStreamPlayer3D
var _water_state := "idle"
var _last_step := 0
var _bed_gain := -4.0

static func attach(level: Node, chapter_key: String) -> Node:
	var existing: Node = level.get_node_or_null("Soundscape")
	if existing != null and existing.get_script() == load("res://systems/audio/Soundscape.gd"):
		return existing
	var sc: Node = load("res://systems/audio/Soundscape.gd").new()
	sc.name = "Soundscape"
	sc.chapter = chapter_key
	level.add_child(sc)
	return sc

func _ready() -> void:
	_Buses.ensure()
	if FileAccess.file_exists(PRESETS):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PRESETS))
		if parsed is Dictionary:
			_bed_gain = float(parsed.get("bed_gain_db", -4.0))
			preset = parsed.get("chapters", {}).get(chapter, {})
	surface = preset.get("surface", "stone")
	_Zone.default_preset = preset.get("reverb", "outdoor")
	_Buses.apply_reverb(_Zone.default_preset)
	for bed in preset.get("beds", []):
		add_bed(bed.get("path", ""), float(bed.get("gain_db", 0.0)))
	for e in preset.get("emitters", []):
		var p: Array = e.get("position", [0, 2, -12])
		add_emitter(e.get("path", ""), Vector3(p[0], p[1], p[2]), float(e.get("gain_db", 0.0)), float(e.get("max_distance", 30.0)))
	for o in preset.get("oneshots", []):
		_oneshots.append(o)
		var iv: Array = o.get("interval", [8, 16])
		_timers.append(randf_range(float(iv[0]), float(iv[1])))

func _exit_tree() -> void:
	_Buses.set_underwater(false)
	_Buses.apply_reverb("outdoor")

static func load_loop(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		s.loop = true
	elif s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s

## Non-positional bed (room tone, wind, insects). Random start offset avoids identical loop phase.
func add_bed(path: String, gain_db: float = 0.0) -> AudioStreamPlayer:
	var s := load_loop(path)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "Ambience"
	p.volume_db = _bed_gain + gain_db
	add_child(p)
	p.play(randf() * s.get_length() * 0.8)
	return p

## Positional loop (waterfall, generator, stream). Uses the level's coordinate space.
func add_emitter(path: String, global_pos: Vector3, gain_db: float = 0.0, max_distance: float = 30.0) -> AudioStreamPlayer3D:
	var s := load_loop(path)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "Ambience"
	p.volume_db = gain_db
	p.unit_size = max_distance * 0.25
	p.max_distance = max_distance
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	p.global_position = global_pos
	p.play(randf() * s.get_length() * 0.8)
	return p

func add_reverb_zone(center: Vector3, size: Vector3, reverb_preset: String) -> Node:
	var z := _Zone.new()
	z.preset = reverb_preset
	z.size = size
	add_child(z)
	z.global_position = center
	return z

func play_oneshot(path: String, global_pos: Vector3, gain_db: float = -8.0, max_distance: float = 20.0) -> void:
	if ResourceLoader.exists(path):
		AudioManager.play_sound_3d(load(path), global_pos, gain_db, "SFX", max_distance)

func footstep(global_pos: Vector3, surface_override: String = "") -> void:
	var pattern: String = STEPS.get(surface_override if surface_override != "" else surface, STEPS["stone"])
	var v := randi_range(1, 4)
	if v == _last_step:
		v = v % 4 + 1
	_last_step = v
	var path := pattern % v
	if ResourceLoader.exists(path):
		var player := AudioStreamPlayer3D.new()
		player.stream = load(path)
		player.bus = "SFX"
		player.volume_db = -10.0
		player.pitch_scale = randf_range(0.94, 1.06)
		player.max_distance = 12.0
		add_child(player)
		player.global_position = global_pos
		player.finished.connect(player.queue_free)
		player.play()

## Drowned Temple water: crossfades between rising / draining loops at a basin position.
func set_water_state(state: String, global_pos: Vector3 = Vector3.ZERO, fade: float = 1.5) -> void:
	if state == _water_state:
		return
	_water_state = state
	if is_instance_valid(_water):
		var old := _water
		var t := create_tween()
		t.tween_property(old, "volume_db", -60.0, fade)
		t.tween_callback(old.queue_free)
		_water = null
	if state == "idle":
		return
	var path: String = preset.get("water_loops", {}).get(state, "res://audio/ambience/temple/AMB_WATER_%s_LOOP.ogg" % state.to_upper())
	_water = add_emitter(path, global_pos, -60.0, 45.0)
	if _water:
		create_tween().tween_property(_water, "volume_db", 0.0, fade)

func set_underwater(enabled: bool) -> void:
	_Buses.set_underwater(enabled)

func _process(delta: float) -> void:
	if _oneshots.is_empty():
		return
	var listener := get_viewport().get_camera_3d()
	if listener == null:
		return
	for i in _oneshots.size():
		_timers[i] -= delta
		if _timers[i] <= 0.0:
			var o: Dictionary = _oneshots[i]
			var iv: Array = o.get("interval", [8, 16])
			_timers[i] = randf_range(float(iv[0]), float(iv[1]))
			var r := float(o.get("radius", 10.0))
			var pos := listener.global_position + Vector3(randf_range(-r, r), randf_range(0.5, 3.0), randf_range(-r, r))
			play_oneshot(o.get("path", ""), pos, float(o.get("gain_db", -10.0)), r * 2.0)
