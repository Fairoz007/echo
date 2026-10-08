extends Node
class_name CampaignDialogue

const _Soundscape := preload("res://systems/audio/Soundscape.gd")

## Reusable original story sequences, exploration VO and scene-owned soundscapes.
var chapter_key := ""
var hud: Node
var events: Dictionary = {}
var _revision := 0
var _subtitle_revision := 0
var _subtitle_label: Label
var _hook_events_played: Dictionary = {}
var _configured := false
var _swim_timer := 0.0
var _nature_events_played: Dictionary = {}

func _init() -> void:
	name = "CampaignDialogue"

func configure(chapter: String, subtitle_hud: Node = null) -> void:
	if _configured:
		return
	_configured = true
	chapter_key = chapter
	hud = subtitle_hud
	var file := "res://audio/campaign_events.json"
	if FileAccess.file_exists(file):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
		if parsed is Dictionary:
			events = parsed.get("events", {}).get(chapter_key, {})
	if not is_instance_valid(hud):
		hud = self
		_create_subtitle_overlay()
	_start_ambience()
	_connect_story_hooks()

func _connect_story_hooks() -> void:
	var scene := get_parent()
	if chapter_key == "C01":
		var survey := scene.get_node_or_null("CampArea/SurveyTable/Interactable3D")
		if survey and survey.has_signal("interacted"):
			survey.interacted.connect(func(_player): _queue_hook_event("team"))
	elif chapter_key == "C05":
		# The patrol's command follows Mara's opening assessment.
		_queue_hook_event("patrol", 1.5)
	elif chapter_key == "C10":
		var encounter := scene.get_node_or_null("CentralPlatform/DrakeTrigger")
		if encounter:
			encounter.body_entered.connect(func(body):
				if body is Player:
					_queue_hook_event("warning"))
		for node_name in ["North", "South", "East", "West"]:
			var node := scene.get_node_or_null("ResonanceChamber/Node%s/Interactable3D" % node_name)
			if node and node.has_signal("interacted"):
				node.interacted.connect(func(_player): _check_vault_collapse())
	elif chapter_key == "FIN":
		_play_escape_collapse()

func _check_vault_collapse() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or _nature_events_played.has("vault_collapse"):
		return
	var scene := get_parent()
	if bool(scene.get("is_overload_triggered")):
		_nature_events_played["vault_collapse"] = true
		var platform := scene.get_node_or_null("CentralPlatform") as Node3D
		if platform:
			AudioManager.play_sfx("collapse", platform.global_position)

func _play_escape_collapse() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player:
		AudioManager.play_sfx("collapse", player.global_position + Vector3(0, 3, 5))

func _process(delta: float) -> void:
	if not _configured or chapter_key != "C06":
		return
	_swim_timer = maxf(0.0, _swim_timer - delta)
	var player := get_parent().get_node_or_null("Player") as Player
	if player and player.current_state == Player.State.SWIM and Vector2(player.velocity.x, player.velocity.z).length() > 0.3 and _swim_timer <= 0.0:
		_swim_timer = 0.9
		AudioManager.play_sfx("swim", player.global_position)

func _queue_hook_event(event_key: String, initial_delay: float = 0.05) -> void:
	if not is_inside_tree():
		return
	if _hook_events_played.has(event_key):
		return
	_hook_events_played[event_key] = true
	var revision := _revision
	# Let the level controller start its main story line first.
	await get_tree().create_timer(initial_delay).timeout
	if not is_inside_tree() or revision != _revision:
		return
	var elapsed := 0.0
	while AudioManager.dialogue_player.playing and elapsed < 30.0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if revision != _revision or not is_inside_tree():
			return
	var scene := get_parent()
	if not is_instance_valid(scene) or scene != get_tree().current_scene:
		return
	if bool(scene.get("transition_started")) or AudioManager.dialogue_player.playing:
		return
	if chapter_key == "C05" and int(scene.get("enemies_remaining")) <= 0:
		return
	if chapter_key == "C10" and bool(scene.get("is_overload_triggered")):
		return
	await play_event(event_key)

func _create_subtitle_overlay() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_subtitle_label = Label.new()
	_subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_label.offset_top = -140.0
	_subtitle_label.offset_bottom = -55.0
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 24)
	_subtitle_label.add_theme_constant_override("outline_size", 6)
	_subtitle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle_label.visible = false
	overlay.add_child(_subtitle_label)

func show_subtitle(speaker: String, text: String, duration: float) -> void:
	if not is_inside_tree() or not is_instance_valid(_subtitle_label):
		return
	_subtitle_revision += 1
	var revision := _subtitle_revision
	_subtitle_label.text = "%s: %s" % [speaker, text]
	_subtitle_label.visible = true
	await get_tree().create_timer(duration).timeout
	if not is_inside_tree():
		return
	if revision == _subtitle_revision and is_instance_valid(_subtitle_label):
		_subtitle_label.visible = false

func play_event(event_key: String) -> void:
	_revision += 1
	var revision := _revision
	var ids: Array = events.get(event_key, [])
	for dialogue_id in ids:
		if revision != _revision or not is_inside_tree():
			return
		var entry: Dictionary = AudioManager.dialogue_catalog.get(dialogue_id, {})
		var duration := AudioManager.play_dialogue(dialogue_id, hud, entry.get("speaker", "Mara"), entry.get("text", ""), 3.5)
		var serial := AudioManager.dialogue_serial
		await get_tree().create_timer(duration + 0.15).timeout
		if not is_inside_tree():
			return
		# An interaction or danger bark supersedes this optional sequence.
		if serial != AudioManager.dialogue_serial:
			return

func cancel() -> void:
	_revision += 1
	_subtitle_revision += 1
	AudioManager.stop_dialogue()
	if is_instance_valid(_subtitle_label):
		_subtitle_label.visible = false

func _start_ambience() -> void:
	# Chapter beds, emitters, one-shots and zone reverb come from systems/audio/Soundscape.gd presets.
	# Levels can fetch the same instance via _Soundscape.attach(level, chapter) to add emitters/zones.
	var scene := get_parent()
	if is_instance_valid(scene):
		_Soundscape.attach.call_deferred(scene, chapter_key)
