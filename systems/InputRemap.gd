extends Node

## Control customization autoload ("InputRemap").
## - Captures the project.godot / built-in default bindings at startup, adds defaults for the
##   runtime-created actions (reload, melee, walk, dive, fire, aim) and gamepad defaults.
## - Loads user://controls.cfg and applies it to InputMap.
## - Each action has two slots: SLOT_KBM (keyboard / mouse) and SLOT_PAD (gamepad).
## - Options (mouse sensitivity, invert Y, stick sensitivity, deadzone, toggle modes, FOV)
##   are properties; any change emits `changed`.

signal changed
signal bindings_changed(action: StringName)

const SLOT_KBM := 0
const SLOT_PAD := 1
const CONFIG_PATH := "user://controls.cfg"
const BASE_MOUSE_SENSITIVITY := 0.003 ## CameraController.mouse_sensitivity default

## Gameplay actions in display order: [action, readable name, section].
const ACTIONS := [
	["move_forward", "Move forward", "Movement"],
	["move_back", "Move back", "Movement"],
	["move_left", "Move left", "Movement"],
	["move_right", "Move right", "Movement"],
	["jump", "Jump / swim up", "Movement"],
	["sprint", "Sprint", "Movement"],
	["walk", "Walk", "Movement"],
	["crouch", "Crouch", "Movement"],
	["dive", "Dive", "Movement"],
	["interact", "Interact", "Actions"],
	["flashlight", "Flashlight", "Actions"],
	["journal", "Field journal", "Actions"],
	["map", "World map", "Actions"],
	["aim", "Aim", "Combat"],
	["fire", "Fire", "Combat"],
	["reload", "Reload", "Combat"],
	["melee", "Melee", "Combat"],
]
## Actions that may share a binding (they are never active in the same context).
const SHAREABLE := [["crouch", "dive"]]
const TOGGLEABLE := ["sprint", "crouch", "aim"]

## Keyboard/mouse defaults for actions that Player.gd creates at runtime (it skips existing ones).
const RUNTIME_KBM := {
	"reload": KEY_R, "melee": KEY_Q, "walk": KEY_ALT, "dive": KEY_C,
	"fire": -MOUSE_BUTTON_LEFT, "aim": -MOUSE_BUTTON_RIGHT, "journal": KEY_J,
	"map": KEY_M,
}
## Gamepad defaults (Xbox layout). Ints are buttons; [axis, sign] are stick / trigger motions.
const PAD_DEFAULTS := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1], "move_back": [JOY_AXIS_LEFT_Y, 1],
	"move_left": [JOY_AXIS_LEFT_X, -1], "move_right": [JOY_AXIS_LEFT_X, 1],
	"jump": JOY_BUTTON_A, "sprint": JOY_BUTTON_LEFT_STICK, "walk": JOY_BUTTON_DPAD_DOWN,
	"crouch": JOY_BUTTON_B, "dive": JOY_BUTTON_B, "interact": JOY_BUTTON_X,
	"flashlight": JOY_BUTTON_DPAD_UP, "aim": [JOY_AXIS_TRIGGER_LEFT, 1],
	"fire": [JOY_AXIS_TRIGGER_RIGHT, 1], "reload": JOY_BUTTON_Y,
	"melee": JOY_BUTTON_RIGHT_SHOULDER, "journal": JOY_BUTTON_BACK,
	"map": JOY_BUTTON_DPAD_RIGHT,
}

var config_path := CONFIG_PATH

# Options ------------------------------------------------------------------------------
var mouse_sensitivity := 1.0:      ## multiplier on BASE_MOUSE_SENSITIVITY (0.1 - 3.0)
	set(v): mouse_sensitivity = clampf(v, 0.1, 3.0); _emit()
var invert_y := false:
	set(v): invert_y = v; _emit()
var stick_sensitivity := 1.0:      ## right-stick look multiplier (0.1 - 3.0)
	set(v): stick_sensitivity = clampf(v, 0.1, 3.0); _emit()
var deadzone := 0.2:               ## applied to every action's InputMap deadzone (0.05 - 0.9)
	set(v): deadzone = clampf(v, 0.05, 0.9); _apply_deadzone(); _emit()
var toggle_sprint := false:
	set(v): toggle_sprint = v; _release_toggle("sprint"); _emit()
var toggle_crouch := false:
	set(v): toggle_crouch = v; _release_toggle("crouch"); _emit()
var toggle_aim := false:
	set(v): toggle_aim = v; _release_toggle("aim"); _emit()
var fov := 75.0:                   ## player camera vertical FOV (60 - 100)
	set(v): fov = clampf(v, 60.0, 100.0); _apply_fov(); _emit()

const OPTION_DEFAULTS := {
	"mouse_sensitivity": 1.0, "invert_y": false, "stick_sensitivity": 1.0, "deadzone": 0.2,
	"toggle_sprint": false, "toggle_crouch": false, "toggle_aim": false, "fov": 75.0,
}

var _defaults := {}   # action -> [kbm_event_or_null, pad_event_or_null]
var _toggled := {}    # action -> bool
var _ready_done := false
var _cams: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()
	load_config()
	_ready_done = true
	get_tree().node_added.connect(_on_node_added)
	changed.connect(_apply_fov)

# ------------------------------------------------------------------- defaults / config

func _capture_defaults() -> void:
	for entry in ACTIONS:
		var action: String = entry[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		var kbm: InputEvent = null
		var pad: InputEvent = null
		for e in InputMap.action_get_events(action):
			if kbm == null and _slot_of(e) == SLOT_KBM:
				kbm = e
			elif pad == null and _slot_of(e) == SLOT_PAD:
				pad = e
		if kbm == null and RUNTIME_KBM.has(action):
			kbm = _make_kbm(RUNTIME_KBM[action])
		if pad == null and PAD_DEFAULTS.has(action):
			pad = _make_pad(PAD_DEFAULTS[action])
		_defaults[action] = [kbm, pad]
		_set_slot_event(action, SLOT_KBM, kbm)
		_set_slot_event(action, SLOT_PAD, pad)

func _make_kbm(code: int) -> InputEvent:
	if code < 0:
		var m := InputEventMouseButton.new()
		m.button_index = -code
		return m
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k

func _make_pad(spec) -> InputEvent:
	if spec is Array:
		var m := InputEventJoypadMotion.new()
		m.axis = spec[0]
		m.axis_value = float(spec[1])
		return m
	var b := InputEventJoypadButton.new()
	b.button_index = spec
	return b

func load_config(path := "") -> void:
	if path != "":
		config_path = path
	var cfg := ConfigFile.new()
	var ok := cfg.load(config_path) == OK
	for entry in ACTIONS:
		var action: String = entry[0]
		for slot in [SLOT_KBM, SLOT_PAD]:
			var ev: InputEvent = _defaults[action][slot]
			var section := "kbm" if slot == SLOT_KBM else "pad"
			if ok and cfg.has_section_key(section, action):
				var stored = cfg.get_value(section, action)
				ev = str_to_var(stored) if stored is String and stored != "" else null
			_set_slot_event(action, slot, ev)
	for key in OPTION_DEFAULTS:
		set(key, cfg.get_value("options", key, OPTION_DEFAULTS[key]) if ok else OPTION_DEFAULTS[key])
	_apply_deadzone()
	changed.emit()

func save_config() -> bool:
	var cfg := ConfigFile.new()
	for entry in ACTIONS:
		var action: String = entry[0]
		var kbm := get_event(action, SLOT_KBM)
		var pad := get_event(action, SLOT_PAD)
		cfg.set_value("kbm", action, var_to_str(kbm) if kbm else "")
		cfg.set_value("pad", action, var_to_str(pad) if pad else "")
	for key in OPTION_DEFAULTS:
		cfg.set_value("options", key, get(key))
	return cfg.save(config_path) == OK

# ------------------------------------------------------------------- bindings

static func _slot_of(e: InputEvent) -> int:
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		return SLOT_PAD
	if e is InputEventKey or e is InputEventMouseButton:
		return SLOT_KBM
	return -1

func get_event(action: String, slot: int) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for e in InputMap.action_get_events(action):
		if _slot_of(e) == slot:
			return e
	return null

func _set_slot_event(action: String, slot: int, ev: InputEvent) -> void:
	for e in InputMap.action_get_events(action):
		if _slot_of(e) == slot:
			InputMap.action_erase_event(action, e)
	if ev:
		InputMap.action_add_event(action, ev)

## Strip a captured event down to what identifies the binding.
static func normalize(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return k
	if e is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = e.button_index
		return m
	if e is InputEventJoypadButton:
		var b := InputEventJoypadButton.new()
		b.button_index = e.button_index
		return b
	if e is InputEventJoypadMotion:
		var j := InputEventJoypadMotion.new()
		j.axis = e.axis
		j.axis_value = signf(e.axis_value)
		return j
	return null

static func same_event(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null or a.get_class() != b.get_class():
		return false
	if a is InputEventKey:
		var ka: int = a.physical_keycode if a.physical_keycode != 0 else a.keycode
		var kb: int = b.physical_keycode if b.physical_keycode != 0 else b.keycode
		return ka == kb
	if a is InputEventMouseButton or a is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false

static func _shareable(a: String, b: String) -> bool:
	for group in SHAREABLE:
		if a in group and b in group:
			return true
	return false

## Returns the gameplay action (other than `action`) already bound to `event`, or "".
func find_conflict(action: String, event: InputEvent) -> String:
	var slot := _slot_of(event)
	for entry in ACTIONS:
		var other: String = entry[0]
		if other == action or _shareable(action, other):
			continue
		if same_event(get_event(other, slot), event):
			return other
	return ""

## Binds `event` to `action` in `slot` (SLOT_KBM / SLOT_PAD; -1 = infer from the event).
## on_conflict: "swap" gives the other action this action's previous binding,
## "cancel" leaves everything unchanged, "steal" unbinds the other action.
## Returns {"ok": bool, "conflict": String}.
func rebind(action: String, event: InputEvent, slot := -1, on_conflict := "cancel") -> Dictionary:
	var ev := normalize(event)
	if ev == null or not _defaults.has(action):
		return {"ok": false, "conflict": ""}
	var ev_slot := _slot_of(ev)
	if slot == -1:
		slot = ev_slot
	if slot != ev_slot:
		return {"ok": false, "conflict": ""}
	var other := find_conflict(action, ev)
	if other != "":
		match on_conflict:
			"swap":
				var previous := get_event(action, slot)
				_set_slot_event(other, slot, previous.duplicate() if previous else null)
				bindings_changed.emit(other)
			"steal":
				_set_slot_event(other, slot, null)
				bindings_changed.emit(other)
			_:
				return {"ok": false, "conflict": other}
	_set_slot_event(action, slot, ev)
	bindings_changed.emit(action)
	return {"ok": true, "conflict": other}

func unbind(action: String, slot: int) -> void:
	_set_slot_event(action, slot, null)
	bindings_changed.emit(action)

func reset_action(action: String) -> void:
	if not _defaults.has(action):
		return
	for slot in [SLOT_KBM, SLOT_PAD]:
		var d: InputEvent = _defaults[action][slot]
		_set_slot_event(action, slot, d.duplicate() if d else null)
	bindings_changed.emit(action)

func reset_all(include_options := true) -> void:
	for entry in ACTIONS:
		reset_action(entry[0])
	if include_options:
		for key in OPTION_DEFAULTS:
			set(key, OPTION_DEFAULTS[key])
	changed.emit()

func default_event(action: String, slot: int) -> InputEvent:
	return _defaults[action][slot] if _defaults.has(action) else null

func is_default(action: String) -> bool:
	for slot in [SLOT_KBM, SLOT_PAD]:
		var cur := get_event(action, slot)
		var d: InputEvent = _defaults[action][slot]
		if (cur == null) != (d == null) or (cur and not same_event(cur, d)):
			return false
	return true

# ------------------------------------------------------------------- display names

static func action_label(action: String) -> String:
	for entry in ACTIONS:
		if entry[0] == action:
			return entry[1]
	return action.capitalize()

const _PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4", JOY_BUTTON_TOUCHPAD: "Touchpad",
}

static func event_label(e: InputEvent) -> String:
	if e == null:
		return "—"
	if e is InputEventKey:
		var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		var mapped := code
		if e.physical_keycode != 0 and DisplayServer.get_name() != "headless":
			mapped = DisplayServer.keyboard_get_keycode_from_physical(code)
		var s := OS.get_keycode_string(mapped if mapped != 0 else code)
		return s if s != "" else "Key %d" % code
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT: return "Left Mouse"
			MOUSE_BUTTON_RIGHT: return "Right Mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle Mouse"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %d" % e.button_index
	if e is InputEventJoypadButton:
		return _PAD_BUTTONS.get(e.button_index, "Button %d" % e.button_index)
	if e is InputEventJoypadMotion:
		var pos: bool = e.axis_value > 0
		match e.axis:
			JOY_AXIS_LEFT_X: return "L Stick Right" if pos else "L Stick Left"
			JOY_AXIS_LEFT_Y: return "L Stick Down" if pos else "L Stick Up"
			JOY_AXIS_RIGHT_X: return "R Stick Right" if pos else "R Stick Left"
			JOY_AXIS_RIGHT_Y: return "R Stick Down" if pos else "R Stick Up"
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
		return "Axis %d%s" % [e.axis, "+" if pos else "-"]
	return e.as_text()

# ------------------------------------------------------------------- options / hooks

## Effective radians-per-pixel for CameraController.
func get_mouse_sensitivity() -> float:
	return BASE_MOUSE_SENSITIVITY * mouse_sensitivity

## Right-stick look vector (after deadzone), scaled by stick_sensitivity, Y already inverted
## when invert_y is on. Multiply by a turn rate (rad/s) and delta in CameraController.
func get_look_vector() -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if v.length() < deadzone:
		return Vector2.ZERO
	v = v.normalized() * inverse_lerp(deadzone, 1.0, minf(v.length(), 1.0))
	if invert_y:
		v.y = -v.y
	return v * stick_sensitivity

func is_toggle(action: String) -> bool:
	match action:
		"sprint": return toggle_sprint
		"crouch": return toggle_crouch
		"aim": return toggle_aim
	return false

func _emit() -> void:
	if _ready_done:
		changed.emit()

func _apply_deadzone() -> void:
	for entry in ACTIONS:
		if InputMap.has_action(entry[0]):
			InputMap.action_set_deadzone(entry[0], deadzone)

func _apply_fov() -> void:
	if not is_inside_tree():
		return
	_cams = _cams.filter(func(c): return is_instance_valid(c))
	for cam in _cams:
		_push_camera(cam)

func _push_camera(cam: Node) -> void:
	if "mouse_sensitivity" in cam:
		cam.mouse_sensitivity = get_mouse_sensitivity()
	var c = cam.get("camera")
	if c is Camera3D:
		c.fov = fov

func _on_node_added(node: Node) -> void:
	if node.get_script() and node.get_script().get_global_name() == &"CameraController":
		_cams.append(node)
		(func():
			if is_instance_valid(node):
				_push_camera(node)).call_deferred()

# Toggle mode: on a fresh press, flip a latch and hold the action through the API.
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for action in TOGGLEABLE:
		if is_toggle(action) and InputMap.has_action(action) and InputMap.event_is_action(event, action, true):
			if get_tree().paused:
				return
			if event.is_pressed():
				_toggled[action] = not _toggled.get(action, false)
			if _toggled[action]:
				Input.action_press(action)
			else:
				Input.action_release(action)

func _release_toggle(action: String) -> void:
	if _toggled.get(action, false):
		_toggled[action] = false
		Input.action_release(action)

func is_latched(action: String) -> bool:
	return _toggled.get(action, false)
