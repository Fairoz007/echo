extends Node
## Authoritative map state for the mini-map and the full-screen world map.
##
## Coordinates: the campaign is still a chain of chapter scenes, each with its own local space.
## The map uses ONE world-map coordinate system (metres, x = east, y = south / world +Z) in which
## each region is placed by an offset (`offset`). Map position = level-local XZ - bake origin + offset.
## Player position is never stored here: it is read from the live Player each query, converted
## into the owning level's local space (so it survives region rebasing / staged co-presence).
## Regions joined by an in-world passage are drawn with a solid route; regions joined by a fade
## (fall, scripted descent) are drawn apart with a dashed "unsurveyed" route — never as touching.
##
## Data: content/map/regions.json (authored), content/map/baked/index.json (dev/map_bake.gd output),
## content/map/objective_targets.json (objective id -> node paths).

signal waypoint_changed
signal discovery_changed(region_id: String)
signal region_changed(region_id: String)

const FOG_CELL := 4.0 ## metres per fog-of-war cell
const REVEAL_RADIUS := 26.0
const POI_DISCOVER_RADIUS := 30.0
const REGION_GAP := 70.0
const DEPTH_STEP := 60.0
const SETTINGS_PATH := "user://map_settings.cfg"
## Chapter pairs connected by a physical passage (GameManager.IN_WORLD_EXITS + staged aqueduct).
const PASSAGE_LINKS := [[1, 2], [4, 5], [5, 6], [6, 7], [7, 8], [9, 10]]

var layer_kinds: Array = []
var regions: Array = [] ## merged authored + baked region dictionaries, campaign order
var by_id: Dictionary = {}
var by_chapter: Dictionary = {}
var targets: Dictionary = {}
var routes: Array = [] ## [{from, to, passage: bool, a: Vector2, b: Vector2}]

# Persistent exploration state.
var fog: Dictionary = {} ## region_id -> PackedByteArray (1 = revealed)
var discovered_regions: Array = []
var discovered_pois: Array = [] ## stable ids "<region>:<poi id>"
var waypoint: Dictionary = {} ## {region, pos: [x,y,z]}

# Settings (per machine, not per save).
var minimap_rotates := true
var nav_indicator := true

var _fog_images: Dictionary = {}
var _fog_textures: Dictionary = {}
var _fog_dirty: Dictionary = {}
var _textures: Dictionary = {}
var _heights: Dictionary = {}
var _level_cache: Dictionary = {} ## region_id -> WeakRef(level node)
var _poi_cache: Dictionary = {} ## region_id -> {level_id, pois: Array}
var _enemy_cache: Array = []
var _enemy_t := 0.0
var _reveal_t := 0.0
var _current_region := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_data()
	_load_settings()

func _load_data() -> void:
	var cfg: Dictionary = _json("res://content/map/regions.json")
	var baked: Dictionary = _json("res://content/map/baked/index.json")
	targets = _json("res://content/map/objective_targets.json")
	layer_kinds = cfg.get("layer_kinds", [])
	var depth_of := {}
	for k in layer_kinds:
		depth_of[k["id"]] = int(k["depth"])
	var cursor := 0.0
	for r in cfg.get("regions", []):
		var reg: Dictionary = (r as Dictionary).duplicate(true)
		var b: Dictionary = baked.get(reg["id"], {})
		if b.is_empty():
			continue
		reg["origin"] = Vector2(b["origin"][0], b["origin"][1])
		reg["res"] = float(b["res"])
		reg["cells"] = Vector2i(int(b["size"][0]), int(b["size"][1]))
		reg["size_m"] = Vector2(reg["cells"]) * float(reg["res"])
		reg["layers"] = b.get("layers", [])
		reg["water"] = b.get("water", [])
		reg["depth"] = int(depth_of.get(reg.get("kind", "surface"), 0))
		reg["offset"] = Vector2(cursor, reg["depth"] * DEPTH_STEP)
		cursor += reg["size_m"].x + REGION_GAP
		reg["fog_size"] = Vector2i(int(ceil(reg["size_m"].x / FOG_CELL)), int(ceil(reg["size_m"].y / FOG_CELL)))
		regions.append(reg)
		by_id[reg["id"]] = reg
		by_chapter[int(reg["chapter"])] = reg
	for i in range(regions.size() - 1):
		var a: Dictionary = regions[i]
		var c: Dictionary = regions[i + 1]
		var passage := false
		for link in PASSAGE_LINKS:
			if int(link[0]) == int(a["chapter"]) and int(link[1]) == int(c["chapter"]):
				passage = true
		routes.append({"from": a["id"], "to": c["id"], "passage": passage,
			"a": a["offset"] + Vector2(a["size_m"].x, a["size_m"].y * 0.5),
			"b": c["offset"] + Vector2(0, c["size_m"].y * 0.5)})

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

# ------------------------------------------------------------------ coordinates

func local_to_map(region_id: String, local: Vector3) -> Vector2:
	var reg: Dictionary = by_id.get(region_id, {})
	if reg.is_empty():
		return Vector2.ZERO
	return Vector2(local.x, local.z) - reg["origin"] + reg["offset"]

func map_to_local(region_id: String, map: Vector2) -> Vector2:
	var reg: Dictionary = by_id[region_id]
	return map - reg["offset"] + reg["origin"]

func region_at_map(map: Vector2) -> String:
	for reg in regions:
		if Rect2(reg["offset"], reg["size_m"]).has_point(map):
			return reg["id"]
	return ""

func region_rect(region_id: String) -> Rect2:
	var reg: Dictionary = by_id.get(region_id, {})
	return Rect2(reg["offset"], reg["size_m"]) if not reg.is_empty() else Rect2()

func world_rect() -> Rect2:
	var r := Rect2()
	for i in regions.size():
		var rr := Rect2(regions[i]["offset"], regions[i]["size_m"])
		r = rr if i == 0 else r.merge(rr)
	return r

func layer_for(region_id: String, y: float) -> String:
	var reg: Dictionary = by_id.get(region_id, {})
	if reg.is_empty() or reg["layers"].is_empty():
		return ""
	for l in reg["layers"]:
		if y >= float(l["min"]) - 0.5 and y < float(l["max"]):
			return l["id"]
	return reg["layers"][0]["id"]

func layer_info(region_id: String, layer_id: String) -> Dictionary:
	for l in by_id.get(region_id, {}).get("layers", []):
		if l["id"] == layer_id:
			return l
	return {}

func region_texture(region_id: String, layer_id: String) -> Texture2D:
	var key := region_id + "/" + layer_id
	if not _textures.has(key):
		var l := layer_info(region_id, layer_id)
		_textures[key] = load("res://content/map/baked/" + l["image"]) if not l.is_empty() and ResourceLoader.exists("res://content/map/baked/" + l["image"]) else null
	return _textures[key]

## Floor height (level-local y) under a local XZ point on a layer; NAN where nothing is walkable.
func floor_height(region_id: String, layer_id: String, local_xz: Vector2) -> float:
	var key := region_id + "/" + layer_id
	if not _heights.has(key):
		var l := layer_info(region_id, layer_id)
		var tex: Texture2D = load("res://content/map/baked/" + l["height"]) if not l.is_empty() and ResourceLoader.exists("res://content/map/baked/" + l["height"]) else null
		_heights[key] = tex.get_image() if tex else null
	var img: Image = _heights[key]
	if img == null:
		return NAN
	var reg: Dictionary = by_id[region_id]
	var origin3: Vector2 = reg["origin"]
	var cell := Vector2i(((local_xz - origin3) / float(reg["res"])).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= img.get_width() or cell.y >= img.get_height():
		return NAN
	var px := img.get_pixelv(cell)
	if px.a < 0.5:
		return NAN
	var l2 := layer_info(region_id, layer_id)
	return lerpf(float(l2["y_min"]), float(l2["y_max"]), px.r)

# ------------------------------------------------------------------ live player

func current_region_id() -> String:
	var reg: Dictionary = by_chapter.get(GameManager.current_chapter, {})
	return reg.get("id", "")

## The level node that owns a region (current scene, or a staged/co-present sibling).
func level_node(region_id: String) -> Node3D:
	var ref: WeakRef = _level_cache.get(region_id)
	var cached: Object = ref.get_ref() if ref else null
	if cached is Node3D and (cached as Node).is_inside_tree():
		return cached
	var reg: Dictionary = by_id.get(region_id, {})
	if reg.is_empty():
		return null
	var scene_path: String = reg["scene"]
	var candidates: Array = get_tree().root.get_children()
	var cs := get_tree().current_scene
	if cs:
		candidates.append_array(cs.get_children())
	for n in candidates:
		if n is Node3D and (n as Node).scene_file_path == scene_path:
			_level_cache[region_id] = weakref(n)
			return n
	return null

func player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func player_local() -> Vector3:
	var p := player()
	var lvl := level_node(current_region_id())
	if p == null:
		return Vector3.ZERO
	return lvl.to_local(p.global_position) if lvl else p.global_position

func player_map_pos() -> Vector2:
	return local_to_map(current_region_id(), player_local())

## Heading in map space: radians, 0 = facing map north (-Y), clockwise positive.
func player_heading() -> float:
	var p := player()
	if p == null:
		return 0.0
	var f: Vector3 = p.get_facing_forward() if p.has_method("get_facing_forward") else -p.global_basis.z
	var lvl := level_node(current_region_id())
	if lvl:
		f = lvl.global_basis.inverse() * f
	return atan2(f.x, -f.z)

func camera_heading() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return player_heading()
	var f := -cam.global_basis.z
	var lvl := level_node(current_region_id())
	if lvl:
		f = lvl.global_basis.inverse() * f
	return atan2(f.x, -f.z)

func player_layer() -> String:
	return layer_for(current_region_id(), player_local().y)

# ------------------------------------------------------------------ discovery

func _process(delta: float) -> void:
	var rid := current_region_id()
	if rid != _current_region:
		_current_region = rid
		region_changed.emit(rid)
	if rid == "" or player() == null or level_node(rid) == null:
		return
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		return
	_reveal_t -= delta
	if _reveal_t <= 0.0:
		_reveal_t = 0.2
		reveal_around(rid, player_local(), REVEAL_RADIUS)
		_discover_pois(rid)
	for k in _fog_dirty.keys():
		_update_fog_texture(k)
	_fog_dirty.clear()

func _fog_bytes(region_id: String) -> PackedByteArray:
	if not fog.has(region_id):
		var fs: Vector2i = by_id[region_id]["fog_size"]
		var b := PackedByteArray()
		b.resize(fs.x * fs.y)
		fog[region_id] = b
	return fog[region_id]

func reveal_around(region_id: String, local: Vector3, radius: float) -> void:
	var reg: Dictionary = by_id.get(region_id, {})
	if reg.is_empty():
		return
	if not discovered_regions.has(region_id):
		discovered_regions.append(region_id)
		discovery_changed.emit(region_id)
	var bytes := _fog_bytes(region_id)
	var fs: Vector2i = reg["fog_size"]
	var origin: Vector2 = reg["origin"]
	var c: Vector2 = (Vector2(local.x, local.z) - origin) / FOG_CELL
	var rc := radius / FOG_CELL
	var changed := false
	for zi in range(maxi(int(c.y - rc), 0), mini(int(c.y + rc) + 1, fs.y)):
		for xi in range(maxi(int(c.x - rc), 0), mini(int(c.x + rc) + 1, fs.x)):
			if Vector2(xi + 0.5, zi + 0.5).distance_to(c) <= rc and bytes[zi * fs.x + xi] == 0:
				bytes[zi * fs.x + xi] = 1
				changed = true
	if changed:
		fog[region_id] = bytes
		_fog_dirty[region_id] = true

func is_revealed(region_id: String, local: Vector3) -> bool:
	var reg: Dictionary = by_id.get(region_id, {})
	if reg.is_empty() or not fog.has(region_id):
		return false
	var fs: Vector2i = reg["fog_size"]
	var origin2: Vector2 = reg["origin"]
	var c := Vector2i(((Vector2(local.x, local.z) - origin2) / FOG_CELL).floor())
	if c.x < 0 or c.y < 0 or c.x >= fs.x or c.y >= fs.y:
		return false
	return fog[region_id][c.y * fs.x + c.x] == 1

func revealed_fraction(region_id: String) -> float:
	if not fog.has(region_id):
		return 0.0
	var bytes: PackedByteArray = fog[region_id]
	var n := 0
	for v in bytes:
		n += v
	return float(n) / maxf(bytes.size(), 1)

func fog_texture(region_id: String) -> Texture2D:
	if not _fog_textures.has(region_id):
		_update_fog_texture(region_id)
	return _fog_textures[region_id]

func _update_fog_texture(region_id: String) -> void:
	var fs: Vector2i = by_id[region_id]["fog_size"]
	var bytes := _fog_bytes(region_id)
	var img := Image.create_from_data(fs.x, fs.y, false, Image.FORMAT_L8, _scale_bytes(bytes))
	_fog_images[region_id] = img
	if _fog_textures.has(region_id) and (_fog_textures[region_id] as ImageTexture).get_size() == Vector2(fs):
		(_fog_textures[region_id] as ImageTexture).update(img)
	else:
		_fog_textures[region_id] = ImageTexture.create_from_image(img)

func _scale_bytes(b: PackedByteArray) -> PackedByteArray:
	var out := b.duplicate()
	for i in out.size():
		out[i] = 255 if out[i] else 0
	return out

# ------------------------------------------------------------------ markers

## Points of interest found in the live level: tombs, landmarks, exits, connections, relics.
func _scan_pois(region_id: String) -> Array:
	var lvl := level_node(region_id)
	if lvl == null:
		return []
	var cache: Dictionary = _poi_cache.get(region_id, {})
	if cache.get("level", 0) == lvl.get_instance_id() and Time.get_ticks_msec() - int(cache.get("t", 0)) < 15000:
		return cache["pois"]
	var pois: Array = []
	var reg: Dictionary = by_id[region_id]
	for lm in reg.get("landmarks", []):
		var n := lvl.get_node_or_null(str(lm["path"])) as Node3D
		if n:
			pois.append({"id": "lm_" + str(lm["path"]), "type": "landmark", "label": lm["name"], "local": lvl.to_local(n.global_position)})
	var expl := lvl.get_node_or_null("CampaignExploration")
	if expl:
		var titles := {}
		var records: Dictionary = _json("res://content/exploration.json")
		for rec in records.get(str(reg["chapter"]), []):
			titles[rec["id"]] = rec["name"]
		for room in expl.get_children():
			if room is Node3D and str(room.name).contains("TOMB"):
				pois.append({"id": str(room.name), "type": "tomb", "label": titles.get(str(room.name), "Optional tomb"), "local": lvl.to_local((room as Node3D).global_position)})
	for tb in reg.get("tombs", []):
		var tn := lvl.get_node_or_null(str(tb["path"])) as Node3D
		if tn:
			pois.append({"id": "tomb_" + str(tb["path"]), "type": "tomb", "label": tb["name"], "local": lvl.to_local(tn.global_position)})
	var exit_path: String = GameManager.IN_WORLD_EXITS.get(int(reg["chapter"]), "")
	if exit_path != "":
		var ex := lvl.get_node_or_null(exit_path) as Node3D
		if ex:
			var nxt: Dictionary = by_chapter.get(int(reg["chapter"]) + 1, {})
			pois.append({"id": "exit", "type": "exit", "label": "Route to " + str(nxt.get("name", "next region")), "local": lvl.to_local(ex.global_position)})
	for n in lvl.find_children("*", "Node3D", true, false):
		var nm := str(n.name)
		var kind := ""
		if nm.begins_with("Ladder") or nm.contains("Stair") or nm.contains("Elevator") or nm.begins_with("Lift"):
			kind = "connection"
		elif nm.contains("CaveEntrance") or nm.contains("TunnelMouth") or nm == "ExitTunnel":
			kind = "cave"
		if kind != "":
			pois.append({"id": kind + "_" + str(lvl.get_path_to(n)), "type": kind, "label": nm.capitalize(), "local": lvl.to_local((n as Node3D).global_position)})
	var hunt := lvl.get_node_or_null("RelicHunt")
	if hunt:
		for s in hunt.get_children():
			if s is Node3D and (s as Node3D).visible:
				pois.append({"id": "relic_" + str(s.name), "type": "collectible", "label": "Relic shard", "local": lvl.to_local((s as Node3D).global_position), "node": weakref(s)})
	_poi_cache[region_id] = {"level": lvl.get_instance_id(), "t": Time.get_ticks_msec(), "pois": pois}
	return pois

func _discover_pois(region_id: String) -> void:
	var here := player_local()
	for poi in _scan_pois(region_id):
		var key: String = region_id + ":" + str(poi["id"])
		if discovered_pois.has(key):
			continue
		if (poi["local"] as Vector3).distance_to(here) < POI_DISCOVER_RADIUS:
			discovered_pois.append(key)
			discovery_changed.emit(region_id)

func _marker(region_id: String, type: String, local: Vector3, label: String) -> Dictionary:
	return {"type": type, "region": region_id, "local": local, "map": local_to_map(region_id, local), "layer": layer_for(region_id, local.y), "label": label}

## All markers to draw right now. Undiscovered locations are not returned (fog of war):
## objective markers always show, enemies only once alerted, relics only with Resource Awareness.
func get_markers() -> Array:
	var out: Array = []
	var rid := current_region_id()
	var lvl := level_node(rid)
	if lvl:
		for oid in MissionManager.active_objectives:
			for path in targets.get(oid, []):
				var n := lvl.get_node_or_null(str(path)) as Node3D
				if n and n.is_visible_in_tree() and not (n is Area3D and not (n as Area3D).monitoring and str(path).ends_with("Interactable3D")):
					out.append(_marker(rid, "objective", lvl.to_local(n.global_position), str(MissionManager.active_objectives[oid])))
		var awareness: bool = SkillManager.unlocked_skills.get("survivor_resource_awareness", false)
		for poi in _scan_pois(rid):
			if poi["type"] == "collectible":
				var sn: Object = (poi["node"] as WeakRef).get_ref()
				if awareness and sn is Node3D and (sn as Node3D).is_visible_in_tree() and (poi["local"] as Vector3).distance_to(player_local()) < 45.0:
					out.append(_marker(rid, "collectible", poi["local"], poi["label"]))
			elif discovered_pois.has(rid + ":" + str(poi["id"])):
				out.append(_marker(rid, poi["type"], poi["local"], poi["label"]))
		for e in _enemies(lvl):
			out.append(_marker(rid, "enemy", lvl.to_local(e.global_position), "Hostile"))
	# Discovered POIs of other regions are remembered by id only; show their region label instead.
	if not waypoint.is_empty():
		var p: Array = waypoint["pos"]
		out.append(_marker(waypoint["region"], "waypoint", Vector3(p[0], p[1], p[2]), "Waypoint"))
	return out

func _enemies(lvl: Node3D) -> Array:
	_enemy_t -= get_process_delta_time()
	if _enemy_t <= 0.0:
		_enemy_t = 3.0
		_enemy_cache = lvl.find_children("*", "EnemyBase", true, false)
	var out: Array = []
	for e in _enemy_cache:
		if not is_instance_valid(e) or not (e as Node).is_inside_tree():
			continue
		var st: int = e.current_state
		# Revealed only once the enemy is engaged/aware (Meridian radio chatter gives them away).
		if st in [EnemyBase.AIState.SUSPICIOUS, EnemyBase.AIState.ALERT, EnemyBase.AIState.COMBAT, EnemyBase.AIState.TAKE_COVER]:
			out.append(e)
	return out

# ------------------------------------------------------------------ waypoint

func set_waypoint_map(map: Vector2) -> bool:
	var rid := region_at_map(map)
	if rid == "":
		return false
	var lxz := map_to_local(rid, map)
	# Snap onto a real floor: the player's layer if that layer has floor here, else the top layer.
	var y := NAN
	var pref := player_layer() if rid == current_region_id() else ""
	if pref != "":
		y = floor_height(rid, pref, lxz)
	if is_nan(y):
		for l in by_id[rid]["layers"]:
			y = floor_height(rid, l["id"], lxz)
			if not is_nan(y):
				break
	if is_nan(y):
		y = 0.0
	waypoint = {"region": rid, "pos": [lxz.x, y, lxz.y]}
	waypoint_changed.emit()
	return true

func clear_waypoint() -> void:
	waypoint = {}
	waypoint_changed.emit()

## Distance + guidance for the waypoint, from real coordinates. Floor-aware: a waypoint on a
## different layer does not get a misleading straight-line arrow.
func waypoint_info() -> Dictionary:
	if waypoint.is_empty():
		return {}
	var p: Array = waypoint["pos"]
	var wl := Vector3(p[0], p[1], p[2])
	var rid := current_region_id()
	if waypoint["region"] != rid:
		return {"same_region": false, "distance": -1.0, "hint": "In " + str(by_id.get(waypoint["region"], {}).get("name", "another region"))}
	var here := player_local()
	var d := here.distance_to(wl)
	var wlayer := layer_for(rid, wl.y)
	var mylayer := layer_for(rid, here.y)
	var info := {"same_region": true, "distance": d, "local": wl, "same_layer": wlayer == mylayer, "dy": wl.y - here.y, "hint": ""}
	if wlayer != mylayer:
		info["hint"] = ("Upper level" if wl.y > here.y else "Lower level") + " — find a way " + ("up" if wl.y > here.y else "down")
	elif absf(wl.y - here.y) > 4.0:
		info["hint"] = "%d m %s" % [int(absf(wl.y - here.y)), "above" if wl.y > here.y else "below"]
	return info

# ------------------------------------------------------------------ persistence

func serialize() -> Dictionary:
	var f := {}
	for k in fog:
		f[k] = Marshalls.raw_to_base64((fog[k] as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE))
	return {"v": 1, "fog": f, "regions": discovered_regions.duplicate(), "pois": discovered_pois.duplicate(), "waypoint": waypoint.duplicate(true)}

func deserialize(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	var d: Dictionary = data
	var f: Variant = d.get("fog", {})
	if f is Dictionary:
		for k in f:
			if not by_id.has(k) or not f[k] is String:
				continue
			var fs: Vector2i = by_id[k]["fog_size"]
			var raw := Marshalls.base64_to_raw(f[k]).decompress(fs.x * fs.y, FileAccess.COMPRESSION_DEFLATE)
			if raw.size() == fs.x * fs.y:
				fog[k] = raw
				_fog_dirty[k] = true
	for k in d.get("regions", []):
		if k is String and by_id.has(k):
			discovered_regions.append(k)
	for k in d.get("pois", []):
		if k is String:
			discovered_pois.append(k)
	var w: Variant = d.get("waypoint", {})
	if w is Dictionary and by_id.has(w.get("region", "")) and w.get("pos") is Array and (w["pos"] as Array).size() == 3:
		waypoint = w
	for k in _fog_dirty.keys():
		_update_fog_texture(k)
	_fog_dirty.clear()
	waypoint_changed.emit()

func reset() -> void:
	fog.clear()
	discovered_regions.clear()
	discovered_pois.clear()
	waypoint = {}
	_poi_cache.clear()
	for k in _fog_textures.keys():
		_fog_dirty[k] = true
	for k in _fog_dirty.keys():
		_update_fog_texture(k)
	_fog_dirty.clear()

func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		minimap_rotates = bool(c.get_value("map", "minimap_rotates", true))
		nav_indicator = bool(c.get_value("map", "nav_indicator", true))

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("map", "minimap_rotates", minimap_rotates)
	c.set_value("map", "nav_indicator", nav_indicator)
	c.save(SETTINGS_PATH)
