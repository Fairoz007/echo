extends Node
## Records meaningful (active) playtime per named zone, excluding idle time and pauses.
## Active = the player moved more than 0.4 m/s or interacted within the last 8 s.
## Totals are written to user://playtime_<key>.json on exit (and on request), so human
## playtests produce real per-district numbers instead of planned durations.

const IDLE_GRACE := 8.0

var key := "level"
var zones: Array = [] ## [name, Rect2 on XZ]
var totals := {}
var idle_total := 0.0
var _since_active := 0.0
var _last_pos := Vector3.INF

static func attach(level: Node, p_key: String, p_zones: Array) -> Node:
	var t: Node = load("res://systems/PlaytimeTracker.gd").new()
	t.name = "PlaytimeTracker"
	t.key = p_key
	t.zones = p_zones
	level.add_child(t)
	return t

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var p := player.global_position
	var moved := 0.0 if _last_pos == Vector3.INF else Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length() / maxf(delta, 0.0001)
	_last_pos = p
	if moved > 0.4 or Input.is_action_pressed("interact"):
		_since_active = 0.0
	else:
		_since_active += delta
	if _since_active > IDLE_GRACE:
		idle_total += delta
		return
	var zone := "Streets"
	for z in zones:
		if (z[1] as Rect2).has_point(Vector2(p.x, p.z)):
			zone = z[0]
			break
	totals[zone] = float(totals.get(zone, 0.0)) + delta

func active_total() -> float:
	var t := 0.0
	for v in totals.values():
		t += v
	return t

func write() -> void:
	var f := FileAccess.open("user://playtime_%s.json" % key, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"active_seconds": totals, "active_total": active_total(), "idle_seconds": idle_total}, "  "))

func _exit_tree() -> void:
	write()
	print("[PLAYTIME] %s active %.0f s (idle %.0f s): %s" % [key, active_total(), idle_total, totals])
