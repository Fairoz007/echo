extends Node

## Global Spatial Audio & Dynamic Music Manager
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	print("[AUDIO] Audio system initialized.")

func play_sound_3d(stream: AudioStream, global_pos: Vector3, max_db: float = 0.0) -> void:
	if not stream:
		return
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = max_db
	player.position = global_pos
	player.unit_size = 5.0
	player.max_distance = 30.0
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
