extends RefCounted
class_name AudioBuses

## Idempotent bus graph + effects. AudioManager creates the bus names; this adds routing and DSP.
##   Master  <- [Limiter]
##   Music, SFX[Reverb], Ambience[Reverb], UI -> Master
##   Dialogue[Reverb, Compressor] -> Master ; Radio[Distortion] -> Dialogue (Dialogue fader also governs radio)
##   Underwater[LowPass] -> SFX (route SFX here while submerged via set_underwater)
## Reverb is the "zone" reverb: ReverbZone / Soundscape drive its parameters. Wet 0 = bypassed.
const BUSES := ["Music", "SFX", "Dialogue", "Ambience", "UI", "Radio", "Underwater"]

const REVERB_PRESETS := {
	# room_size, damping, wet (SFX), predelay ms, hipass
	"outdoor": [0.25, 0.7, 0.0, 20.0, 0.2],
	"ruin": [0.55, 0.5, 0.12, 30.0, 0.15],
	"cave": [0.75, 0.35, 0.22, 45.0, 0.1],
	"temple": [0.8, 0.25, 0.26, 55.0, 0.1],
	"vast": [0.95, 0.2, 0.3, 80.0, 0.1],
	"vault": [0.9, 0.15, 0.34, 70.0, 0.05],
	"tunnel": [0.45, 0.4, 0.2, 15.0, 0.15],
}

static func ensure() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for bus_name in ["Music", "SFX", "Dialogue", "Ambience", "UI"]:
		AudioServer.set_bus_send(_idx(bus_name), "Master")
	AudioServer.set_bus_send(_idx("Radio"), "Dialogue")
	AudioServer.set_bus_send(_idx("Underwater"), "SFX")
	_ensure_effect("Master", "AudioEffectHardLimiter", func():
		var l := AudioEffectHardLimiter.new()
		l.ceiling_db = -1.0
		return l)
	for bus_name in ["SFX", "Ambience", "Dialogue"]:
		_ensure_effect(bus_name, "AudioEffectReverb", func():
			var r := AudioEffectReverb.new()
			r.wet = 0.0
			r.dry = 1.0
			return r)
	_ensure_effect("Dialogue", "AudioEffectCompressor", func():
		var c := AudioEffectCompressor.new()
		c.threshold = -18.0
		c.ratio = 2.5
		c.attack_us = 5000.0
		c.release_ms = 120.0
		return c)
	_ensure_effect("Radio", "AudioEffectDistortion", func():
		var d := AudioEffectDistortion.new()
		d.mode = AudioEffectDistortion.MODE_CLIP
		d.drive = 0.15
		d.pre_gain = 0.0
		d.post_gain = -2.0
		return d)
	_ensure_effect("Underwater", "AudioEffectLowPassFilter", func():
		var f := AudioEffectLowPassFilter.new()
		f.cutoff_hz = 900.0
		return f)

## Apply a named reverb space (see REVERB_PRESETS). Dialogue gets 40% of the SFX wet so speech stays intelligible.
static func apply_reverb(preset: String) -> void:
	ensure()
	var p: Array = REVERB_PRESETS.get(preset, REVERB_PRESETS["outdoor"])
	for bus_name in ["SFX", "Ambience", "Dialogue"]:
		var r := _effect(bus_name, "AudioEffectReverb") as AudioEffectReverb
		if r == null:
			continue
		r.room_size = p[0]
		r.damping = p[1]
		r.predelay_msec = p[3]
		r.hipass = p[4]
		var wet: float = p[2] * (0.4 if bus_name == "Dialogue" else (0.6 if bus_name == "Ambience" else 1.0))
		r.wet = wet
		AudioServer.set_bus_effect_enabled(_idx(bus_name), _effect_index(bus_name, "AudioEffectReverb"), wet > 0.001)

static func set_underwater(enabled: bool) -> void:
	ensure()
	# Underwater: muffle SFX + ambience; keep dialogue clear.
	for bus_name in ["SFX", "Ambience"]:
		var lp := _effect(bus_name, "AudioEffectLowPassFilter")
		if lp == null:
			var e := AudioEffectLowPassFilter.new()
			e.cutoff_hz = 900.0
			AudioServer.add_bus_effect(_idx(bus_name), e)
		AudioServer.set_bus_effect_enabled(_idx(bus_name), _effect_index(bus_name, "AudioEffectLowPassFilter"), enabled)

static func _idx(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)

static func _effect_index(bus_name: String, cls: String) -> int:
	var b := _idx(bus_name)
	for i in AudioServer.get_bus_effect_count(b):
		if AudioServer.get_bus_effect(b, i).get_class() == cls:
			return i
	return -1

static func _effect(bus_name: String, cls: String) -> AudioEffect:
	var i := _effect_index(bus_name, cls)
	return AudioServer.get_bus_effect(_idx(bus_name), i) if i >= 0 else null

static func _ensure_effect(bus_name: String, cls: String, factory: Callable) -> void:
	if _idx(bus_name) >= 0 and _effect_index(bus_name, cls) == -1:
		AudioServer.add_bus_effect(_idx(bus_name), factory.call())
