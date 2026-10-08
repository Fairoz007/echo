extends CanvasLayer

## Story transition card shown between levels.
## Animated chapter card (title, location, recap subtitles, drifting mist art with a slow
## pan), a progress bar driven by ResourceLoader threaded loading, and a skip prompt once
## the next level is ready. Owned by GameManager.
## Text is taken from COMPLETE_SCREENPLAY.md chapter synopses (the .md files are not
## exported, so the text is embedded here).

signal finished

const MIN_SHOW_TIME := 5.0
const CARDS := {
	0: ["PROLOGUE", "The Descent", "Beneath the mountain", [
		"Flash-forward.",
		"Mara wakes beneath the mountain, separated from her team.",
		"Somewhere in the dark, the stone is humming."]],
	1: ["CHAPTER ONE", "The Arrival", "Expedition camp and Eastern Ridge", [
		"72 hours earlier.",
		"Mara reunites with the expedition: Elias leads the research, Nadiya runs communications,",
		"Tomas handles rescue, Adrian verifies the survey coordinates.",
		"The sealed portal is exactly where the theory said it would be."]],
	2: ["CHAPTER TWO", "Whispers in Stone", "Waterfall ruin", [
		"A blocked sluice conceals a hydraulic counterweight.",
		"Restore the channel. Read what the Vaelor left behind.",
		"The ruins are part of something deeper: an acoustic network."]],
	3: ["CHAPTER THREE", "The Fall", "Ancient bridge over a fissure", [
		"The team must cross an unstable span.",
		"The anchors are brittle. The mountain is restless."]],
	4: ["CHAPTER FOUR", "Beneath", "Collapsed caves", [
		"Mara fell. The team is somewhere above.",
		"Follow the air. Follow the water. Get the radio working."]],
	5: ["CHAPTER FIVE", "Hunters", "Meridian underground checkpoint", [
		"Nadiya's warning was right: Meridian contractors are in the valley.",
		"Lucian Drake wants the aqueduct secured.",
		"Stay hidden, or fight your way through."]],
	6: ["CHAPTER SIX", "The Drowned Temple", "Submerged Vaelor sanctuary", [
		"A diverted aqueduct has drowned the sanctuary.",
		"Lower the water to expose the gate below."]],
	7: ["CHAPTER SEVEN", "City of Echoes", "Lost underground city", [
		"Beyond the temple: an entire civilization built around harmonic stone.",
		"A mural records how it ended."]],
	8: ["CHAPTER EIGHT", "The Betrayal", "Inner sanctum refuge", [
		"Elias is injured. The Acoustic Key is gone.",
		"Someone sold the expedition's coordinates to Meridian."]],
	9: ["CHAPTER NINE", "The Heart Road", "Unstable resonance conduits", [
		"Meridian's blasting is tearing the conduits apart.",
		"Adrian's service route is the only way to reach the core before Drake."]],
	10: ["CHAPTER TEN", "The Heart Vault", "Spherical resonant geode", [
		"Drake intends to weaponize the resonance network.",
		"Four harmonic nodes. Break his control."]],
	11: ["FINALE", "The Mountain Breaks", "Daylight fissure", [
		"The chamber is sealing. The mountain is coming down.",
		"Run for the light."]],
	12: ["EPILOGUE", "Daylight", "Surface ridge, dawn", [
		"The survivors choose preservation over extraction.",
		"Some things are meant to stay beneath."]],
	13: ["", "Echoes Beneath", "Credits", [
		"Thank you for playing."]],
}

var _root: Control
var _art: ColorRect
var _kicker: Label
var _title: Label
var _location: Label
var _subtitle: Label
var _bar: ProgressBar
var _prompt: Label
var _path := ""
var _ready_to_go := false
var _skip_requested := false
var _active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# "Art": slowly panning layered mist + strata lines (works on GL Compatibility).
	_art = ColorRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec3 tint = vec3(0.55, 0.45, 0.32);
uniform float pan = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int k = 0; k < 5; k++){ v += a*n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment(){
	vec2 uv = UV * vec2(1.78, 1.0) + vec2(pan, 0.0);
	float strata = smoothstep(0.45, 0.5, fract(uv.y * 7.0 + fbm(uv * 2.0) * 1.6)) * 0.12;
	float mist = fbm(uv * 1.6 + vec2(TIME * 0.015, 0.0));
	float glow = smoothstep(0.9, 0.0, distance(UV, vec2(0.72, 0.45))) * 0.35;
	vec3 c = tint * (mist * 0.45 + strata + glow);
	float vignette = smoothstep(1.1, 0.35, distance(UV, vec2(0.5)));
	COLOR = vec4(c * vignette, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_art.material = mat
	_root.add_child(_art)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(140, -170)
	column.size = Vector2(1300, 340)
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.add_theme_constant_override("separation", 10)
	_root.add_child(column)
	_kicker = _label(column, 26, Color(0.85, 0.7, 0.45))
	_title = _label(column, 72, Color(0.96, 0.94, 0.9))
	_location = _label(column, 24, Color(0.7, 0.72, 0.72))
	_subtitle = Label.new()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.anchor_left = 0.1
	_subtitle.anchor_right = 0.9
	_subtitle.offset_left = 0
	_subtitle.offset_right = 0
	_subtitle.offset_top = -230
	_subtitle.offset_bottom = -150
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 28)
	_subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	_root.add_child(_subtitle)
	_bar = ProgressBar.new()
	_bar.anchor_left = 0.1
	_bar.anchor_right = 0.9
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -100
	_bar.offset_bottom = -92
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.7, 0.45)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	_root.add_child(_bar)
	_prompt = Label.new()
	_prompt.anchor_left = 0.1
	_prompt.anchor_right = 0.9
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -80
	_prompt.offset_bottom = -50
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_root.add_child(_prompt)
	visible = false

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	parent.add_child(l)
	return l

const RECAP := preload("res://systems/audio/ChapterRecap.gd")

## Recap key = the chapter that just ENDED (PRO, C01..C10, FIN).
static func recap_key_for(next_chapter: int) -> String:
	if next_chapter == 1:
		return "PRO"
	if next_chapter >= 2 and next_chapter <= 11:
		return "C%02d" % (next_chapter - 1)
	if next_chapter == 12:
		return "FIN"
	return ""

func _show_line(text: String) -> void:
	_subtitle.text = text
	_subtitle.modulate.a = 0.0
	create_tween().tween_property(_subtitle, "modulate:a", 1.0, 0.4)

## HUD-compatible hook (ChapterRecap/AudioManager may call this).
func show_subtitle(_speaker: String, text: String, _duration: float) -> void:
	_show_line(text)

func is_active() -> bool:
	return _active

## Shows the card for `chapter`, loads `scene_path` in the background and switches to it.
## With an empty scene_path the card is shown over the current scene (used for credits).
func play(chapter: int, scene_path: String) -> void:
	_active = true
	_path = scene_path
	_ready_to_go = scene_path.is_empty()
	_skip_requested = false
	var card: Array = CARDS.get(chapter, ["", "", "", []])
	_kicker.text = card[0]
	_title.text = card[1]
	_location.text = card[2]
	_subtitle.text = ""
	_bar.value = 0.0
	_bar.visible = not scene_path.is_empty()
	_prompt.text = "Loading..." if not scene_path.is_empty() else "Space / Enter to continue"
	for l in [_kicker, _title, _location]:
		l.modulate.a = 0.0
	_root.modulate.a = 0.0
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not scene_path.is_empty():
		ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	var mat: ShaderMaterial = _art.material
	mat.set_shader_parameter("pan", 0.0)
	var pan := create_tween()
	pan.tween_method(func(v): mat.set_shader_parameter("pan", v), 0.0, 0.6, 30.0)
	var intro := create_tween()
	intro.tween_property(_root, "modulate:a", 1.0, 0.6)
	intro.tween_property(_kicker, "modulate:a", 1.0, 0.5)
	intro.tween_property(_title, "modulate:a", 1.0, 0.8)
	intro.tween_property(_location, "modulate:a", 1.0, 0.5)
	var started := Time.get_ticks_msec()
	var lines: Array = card[3]
	var line_index := 0
	var next_line_at := 1.6
	# Narrated recap of the chapter that just ended (systems/audio/ChapterRecap.gd, text from
	# COMPLETE_SCREENPLAY.md "CHAPTER TRANSITION RECAPS"). Its cues replace the static lines.
	var recap_key := recap_key_for(chapter)
	var recap: Dictionary = RECAP.get_recap(recap_key) if not recap_key.is_empty() else {}
	var cues: Array = recap.get("cues", [])
	var recap_started_at := -1.0
	var recap_length := 0.0
	var cue_index := 0
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - started) / 1000.0
		if not recap.is_empty():
			if recap_started_at < 0.0 and t >= 1.4:
				recap_started_at = t
				recap_length = RECAP.play(recap_key, null)
				if cues.is_empty():
					_show_line(str(recap.get("text", "")))
			if recap_started_at >= 0.0:
				var rt := t - recap_started_at
				while cue_index < cues.size() and rt >= float(cues[cue_index].get("start", 0.0)):
					_show_line(str(cues[cue_index].get("text", "")))
					cue_index += 1
			line_index = lines.size()
			next_line_at = (recap_started_at + recap_length + 0.5) if recap_started_at >= 0.0 else 999.0
		elif line_index < lines.size() and t >= next_line_at:
			_subtitle.text = lines[line_index]
			_subtitle.modulate.a = 0.0
			create_tween().tween_property(_subtitle, "modulate:a", 1.0, 0.4)
			line_index += 1
			next_line_at = t + clampf(lines[line_index - 1].length() * 0.055, 2.2, 4.5)
		if not _ready_to_go:
			var progress := []
			var status := ResourceLoader.load_threaded_get_status(_path, progress)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_ready_to_go = true
				_bar.value = 1.0
				_prompt.text = "Space / Enter to continue"
			elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_bar.value = maxf(_bar.value, float(progress[0]) if progress.size() > 0 else 0.0)
			else:
				push_error("[TRANSITION] Threaded load failed for " + _path + "; falling back to blocking load")
				_ready_to_go = true
		var story_done := line_index >= lines.size() and t >= next_line_at
		if _ready_to_go and (_skip_requested or (t >= MIN_SHOW_TIME and story_done)):
			break
		if _skip_requested and not _ready_to_go:
			_prompt.text = "Loading... (will continue when ready)"
	pan.kill()
	if _skip_requested and not recap.is_empty():
		RECAP.stop()
	if not _path.is_empty():
		var packed: PackedScene = ResourceLoader.load_threaded_get(_path) if ResourceLoader.load_threaded_get_status(_path) == ResourceLoader.THREAD_LOAD_LOADED else load(_path)
		if packed == null:
			# Broken level resource: never change to a null scene (engine error); stay put and report.
			push_error("[TRANSITION] Could not load %s; staying on current scene." % _path)
			_prompt.text = "Level failed to load"
		else:
			get_tree().change_scene_to_packed(packed)
			await get_tree().scene_changed
			await get_tree().process_frame
	var outro := create_tween()
	outro.tween_property(_root, "modulate:a", 0.0, 0.7)
	await outro.finished
	visible = false
	_active = false
	finished.emit()

func _input(event: InputEvent) -> void:
	if not _active:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		skip = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip = true
	elif event is InputEventJoypadButton and event.pressed:
		skip = true
	if skip:
		_skip_requested = true
	# Swallow all input while the card is up so gameplay/pause do not react.
	get_viewport().set_input_as_handled()
