extends Node3D

const _Buses := preload("res://systems/audio/AudioBuses.gd")
const _Zone := preload("res://systems/audio/ReverbZone.gd")

## Scene-owned loops and sparse positional events; all stop with the chapter.
var _drip_timer := 0.0
var _rock_timer := 0.0

func _ready() -> void:
	# Gains re-balanced for the -26 LUFS ambience / -16 LUFS dialogue master (see AUDIO_REPORT.md).
	_Buses.ensure()
	_Zone.default_preset = "cave"
	_Buses.apply_reverb("cave")
	_add_loop("res://audio/ambience/cave/AMB_PRO_CAVE_ROOMTONE.wav", Vector3.ZERO, -16.0, false)
	_add_loop("res://audio/ambience/cave/AMB_PRO_CAVE_WATER.wav", Vector3(-2.0, 0.4, -18.0), -14.0, true)
	_drip_timer = randf_range(3.0, 7.0)
	_rock_timer = randf_range(15.0, 25.0)
	play_event("res://audio/movement/FOL_PRO_BREATH_RECOVERY.wav", Vector3.ZERO, -17.0, false)

func _add_loop(path: String, pos: Vector3, gain: float, spatial: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamWAV
	if not stream:
		return
	stream = stream.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if spatial:
		var source := AudioStreamPlayer3D.new()
		source.stream = stream
		source.bus = "Ambience"
		source.volume_db = gain
		source.unit_size = 2.5
		source.max_distance = 14.0
		add_child(source)
		source.position = pos
		source.play()
	else:
		var source := AudioStreamPlayer.new()
		source.stream = stream
		source.bus = "Ambience"
		source.volume_db = gain
		add_child(source)
		source.play()

func play_event(path: String, pos: Vector3, gain: float = -12.0, spatial: bool = true) -> void:
	if not ResourceLoader.exists(path):
		return
	if spatial:
		AudioManager.play_sound_3d(load(path), pos, gain, "SFX", 14.0)
	else:
		var source := AudioStreamPlayer.new()
		source.stream = load(path)
		source.bus = "UI" if "/ui/" in path else "SFX"
		source.volume_db = gain
		add_child(source)
		source.finished.connect(func(): source.queue_free())
		source.play()

func _process(delta: float) -> void:
	_drip_timer -= delta
	_rock_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(4.0, 10.0)
		play_event("res://audio/water/SFX_PRO_CAVE_DRIP.wav", Vector3(randf_range(-2.5, 2.5), 1.0, randf_range(-22.0, -4.0)), -11.0)
	if _rock_timer <= 0.0:
		_rock_timer = randf_range(18.0, 32.0)
		play_event("res://audio/destruction/SFX_PRO_ROCK_SHIFT.wav", Vector3(2.4, 0.8, -8.0), -23.0)

func _exit_tree() -> void:
	_Buses.apply_reverb("outdoor")
