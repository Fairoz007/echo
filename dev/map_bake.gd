extends SceneTree
## DEV TOOL: bakes cartography for the world map from each chapter's real collision geometry.
## For every grid cell it casts rays down through the level and records walkable floors
## (upward-facing hits with >=1.5 m headroom). Floors are split into map layers by the height
## bands in content/map/regions.json, shaded by height + hillshade, cliffs outlined, water
## (WaterVolume areas) tinted. Output: content/map/baked/<region>_<layer>.png + index.json.
## Usage: godot --headless --path . -s res://dev/map_bake.gd [-- --only=6 --stats]
const OUT := "res://content/map/baked/"
const MAX_CELLS := 640 # per axis
const PAPER := Color(0.0, 0.0, 0.0, 0.0)

var stats := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = int(a.substr(7))
		if a == "--stats":
			stats = true
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/map/regions.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var index_path := OUT + "index.json"
	var index: Dictionary = {}
	if FileAccess.file_exists(index_path):
		index = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	for region in cfg["regions"]:
		var ch: int = int(region["chapter"])
		if only >= 0 and ch != only:
			continue
		var entry := await _bake(region)
		if not entry.is_empty():
			index[region["id"]] = entry
	var f := FileAccess.open(index_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t"))
	f.close()
	print("BAKE_DONE ", index.size(), " regions")
	quit(0)

func _bake(region: Dictionary) -> Dictionary:
	var scene_path: String = region["scene"]
	var lvl: Node = load(scene_path).instantiate()
	root.add_child(lvl)
	for i in 120:
		await physics_frame
	var player := lvl.get_node_or_null("Player") as CollisionObject3D
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	# Ground-truth extents: every static collision object (not the 3 km kill/backdrop planes).
	var box := AABB()
	var first := true
	for n in lvl.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape == null or not (cs.get_parent() is StaticBody3D or cs.get_parent() is AnimatableBody3D or cs.get_parent() is RigidBody3D):
			continue
		var r: Vector3 = _shape_extent(cs.shape)
		if r.x > 400.0 or r.z > 400.0:
			continue
		var b := AABB(cs.global_position - r, r * 2.0)
		box = b if first else box.merge(b)
		first = false
	for n in lvl.find_children("*", "CSGShape3D", true, false):
		var csg := n as CSGShape3D
		if csg.use_collision and csg.is_root_shape():
			var b2 := csg.global_transform * csg.get_aabb()
			if b2.size.x < 800.0 and b2.size.z < 800.0:
				box = b2 if first else box.merge(b2)
				first = false
	if first:
		push_warning("no collision in " + scene_path)
		lvl.queue_free()
		return {}
	var b_min := Vector2(box.position.x, box.position.z) - Vector2(4, 4)
	var b_size := Vector2(box.size.x, box.size.z) + Vector2(8, 8)
	var res := maxf(0.5, ceilf(maxf(b_size.x, b_size.y) / MAX_CELLS * 4.0) / 4.0)
	var w := int(ceil(b_size.x / res))
	var h := int(ceil(b_size.y / res))
	var top := box.end.y + 2.0
	var bottom := box.position.y - 2.0
	var space := (lvl as Node3D).get_world_3d().direct_space_state if lvl is Node3D else root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.exclude = exclude
	q.collide_with_areas = false
	q.hit_back_faces = false
	var up := PhysicsRayQueryParameters3D.new()
	up.exclude = exclude
	up.hit_back_faces = false
	# floors[i] = PackedFloat32Array of walkable floor heights (top-down order) for cell i.
	var floors: Array = []
	floors.resize(w * h)
	var hist := {}
	for zi in h:
		for xi in w:
			var x := b_min.x + (xi + 0.5) * res
			var z := b_min.y + (zi + 0.5) * res
			var ys := PackedFloat32Array()
			var y := top
			for k in 8:
				q.from = Vector3(x, y, z)
				q.to = Vector3(x, bottom, z)
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					break
				var p: Vector3 = hit.position
				if (hit.normal as Vector3).y > 0.55:
					up.from = p + Vector3(0, 0.05, 0)
					up.to = p + Vector3(0, 1.55, 0)
					if space.intersect_ray(up).is_empty():
						ys.append(p.y)
						var bucket := int(floor(p.y / 2.0)) * 2
						hist[bucket] = hist.get(bucket, 0) + 1
				y = p.y - 0.05
			floors[zi * w + xi] = ys
	if stats:
		var keys := hist.keys()
		keys.sort()
		var line := ""
		for kk in keys:
			line += "%d:%d " % [kk, hist[kk]]
		print("HIST ", region["id"], " ", line)
	# Water boxes (WaterVolume areas) in map space.
	var water: Array = []
	for n in lvl.find_children("*", "Area3D", true, false):
		var a := n as Area3D
		if a.get_script() == null or not str(a.get_script().resource_path).ends_with("WaterVolume.gd"):
			continue
		for c in a.get_children():
			if c is CollisionShape3D and c.shape:
				var e: Vector3 = _shape_extent(c.shape)
				var ab := AABB(c.global_position - e, e * 2.0)
				water.append([ab.position.x, ab.position.z, ab.size.x, ab.size.z, ab.position.y, ab.end.y])
	var layers: Array = region.get("layers", [{"id": "main", "min": -1000.0, "max": 1000.0}])
	var entry := {"origin": [b_min.x, b_min.y], "res": res, "size": [w, h], "layers": [], "water": water}
	for layer in layers:
		var lo: float = float(layer.get("min", -1000.0))
		var hi: float = float(layer.get("max", 1000.0))
		var hm := PackedFloat32Array()
		hm.resize(w * h)
		var y_min := INF
		var y_max := -INF
		var count := 0
		for i in w * h:
			var v := NAN
			for fy in floors[i]:
				if fy >= lo and fy < hi:
					v = fy
					break
			hm[i] = v
			if not is_nan(v):
				y_min = minf(y_min, v)
				y_max = maxf(y_max, v)
				count += 1
		if count == 0:
			continue
		var img := _shade(hm, w, h, res, y_min, y_max, water, b_min, lo, hi)
		if not DisplayServer.get_name() == "headless":
			var ceiling: float = minf(hi, y_max + float(region.get("ceiling_clear", 5.0)))
			var cap := await _capture(lvl, b_min, b_size, w, h, ceiling, maxf(lo, y_min - 1.0))
			img = _compose(img, cap, hm, w, h)
		var file := "%s_%s.png" % [region["id"], layer["id"]]
		img.save_png(ProjectSettings.globalize_path(OUT + file))
		# Height grid (8-bit, y_min..y_max) for layer auto-selection & floor-aware guidance.
		var hgrid := Image.create(w, h, false, Image.FORMAT_LA8)
		for zi in h:
			for xi in w:
				var v2: float = hm[zi * w + xi]
				if is_nan(v2):
					hgrid.set_pixel(xi, zi, Color(0, 0, 0, 0))
				else:
					var t := (v2 - y_min) / maxf(y_max - y_min, 0.01)
					hgrid.set_pixel(xi, zi, Color(t, t, t, 1))
		var hfile := "%s_%s_h.png" % [region["id"], layer["id"]]
		hgrid.save_png(ProjectSettings.globalize_path(OUT + hfile))
		entry["layers"].append({"id": layer["id"], "kind": layer.get("kind", region.get("kind", "surface")), "name": layer.get("name", region["name"]), "min": lo, "max": hi, "image": file, "height": hfile, "y_min": y_min, "y_max": y_max, "cells": count})
		print("BAKED %s/%s %dx%d res=%.2f cells=%d y=%.1f..%.1f" % [region["id"], layer["id"], w, h, res, count, y_min, y_max])
	lvl.queue_free()
	for i in 10:
		await physics_frame
	return entry

## Orthographic top-down render of the art between `floor_y` and `ceiling` (roofs culled by near plane).
func _capture(lvl: Node, b_min: Vector2, b_size: Vector2, w: int, h: int, ceiling: float, floor_y: float) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.world_3d = (lvl as Node3D).get_world_3d()
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = b_size.x
	cam.near = 0.05
	cam.far = maxf(ceiling - floor_y + 1.0, 2.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	vp.add_child(cam)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(b_min.x + b_size.x * 0.5, ceiling, b_min.y + b_size.y * 0.5))
	cam.current = true
	for i in 6:
		await process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h)
	return img

## Bronze-graded art inside the walkable mask (x relief), dimmed art outside it.
func _compose(relief: Image, cap: Image, hm: PackedFloat32Array, w: int, h: int) -> Image:
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint := Color(0.86, 0.74, 0.52)
	for zi in h:
		for xi in w:
			var c := cap.get_pixel(xi, zi)
			var r := relief.get_pixel(xi, zi)
			var lum := minf(pow(c.r * 0.3 + c.g * 0.55 + c.b * 0.15, 0.7) * 1.35, 1.0)
			var graded := Color(tint.r * lum, tint.g * lum, tint.b * lum).lerp(c, 0.35)
			if not is_nan(hm[zi * w + xi]) and r.a > 0.0:
				var rl := (r.r + r.g + r.b) / 3.0 / 0.6
				var mixed := graded * clampf(rl, 0.45, 1.3)
				mixed = mixed.lerp(r, 0.35)
				out.set_pixel(xi, zi, Color(mixed.r, mixed.g, mixed.b, 1.0))
			elif c.a > 0.05:
				out.set_pixel(xi, zi, Color(graded.r * 0.4, graded.g * 0.4, graded.b * 0.45, 0.8 * c.a))
	return out

func _shape_extent(s: Shape3D) -> Vector3:
	if s is BoxShape3D:
		return (s as BoxShape3D).size * 0.5
	if s is CylinderShape3D:
		var c := s as CylinderShape3D
		return Vector3(c.radius, c.height * 0.5, c.radius)
	if s is CapsuleShape3D:
		var cp := s as CapsuleShape3D
		return Vector3(cp.radius, cp.height * 0.5, cp.radius)
	if s is SphereShape3D:
		var r := (s as SphereShape3D).radius
		return Vector3(r, r, r)
	if s is ConcavePolygonShape3D or s is ConvexPolygonShape3D or s is HeightMapShape3D:
		var pts := PackedVector3Array()
		if s is ConcavePolygonShape3D:
			pts = (s as ConcavePolygonShape3D).get_faces()
		elif s is ConvexPolygonShape3D:
			pts = (s as ConvexPolygonShape3D).points
		else:
			var hm := s as HeightMapShape3D
			return Vector3(hm.map_width * 0.5, 50.0, hm.map_depth * 0.5)
		var mx := Vector3.ZERO
		for p in pts:
			mx = mx.max(p.abs())
		return mx
	return Vector3(2, 2, 2)

## Cartographic style: bronze-sand relief by height, hillshade, dark cliff edges, teal water.
func _shade(hm: PackedFloat32Array, w: int, h: int, res: float, y_min: float, y_max: float, water: Array, b_min: Vector2, lo: float, hi: float) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	var low := Color(0.30, 0.27, 0.21)
	var high := Color(0.78, 0.70, 0.52)
	var light := Vector3(-0.5, 0.75, -0.45).normalized()
	var span := maxf(y_max - y_min, 1.0)
	for zi in h:
		for xi in w:
			var v: float = hm[zi * w + xi]
			if is_nan(v):
				continue
			var t := clampf((v - y_min) / span, 0.0, 1.0)
			var col := low.lerp(high, pow(t, 0.8))
			var vx := _nb(hm, w, h, xi + 1, zi, v) - _nb(hm, w, h, xi - 1, zi, v)
			var vz := _nb(hm, w, h, xi, zi + 1, v) - _nb(hm, w, h, xi, zi - 1, v)
			var n := Vector3(-vx / (2.0 * res), 1.0, -vz / (2.0 * res)).normalized()
			var shade := clampf(0.55 + 0.6 * n.dot(light), 0.35, 1.15)
			col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
			# Edge = neighbour missing or a step > 0.7 m (wall, cliff, ledge).
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ax: int = xi + d.x
				var az: int = zi + d.y
				if ax < 0 or az < 0 or ax >= w or az >= h:
					edge = true
					break
				var nv: float = hm[az * w + ax]
				if is_nan(nv) or absf(nv - v) > 0.7:
					edge = true
					break
			if edge:
				col = col.darkened(0.55)
			# Contour every 4 m.
			elif int(floor(v / 4.0)) != int(floor(_nb(hm, w, h, xi + 1, zi, v) / 4.0)) or int(floor(v / 4.0)) != int(floor(_nb(hm, w, h, xi, zi + 1, v) / 4.0)):
				col = col.darkened(0.18)
			img.set_pixel(xi, zi, col)
	var water_col := Color(0.16, 0.42, 0.50, 0.82)
	for wb in water:
		if float(wb[5]) < lo or float(wb[4]) >= hi:
			continue
		var x0 := int((float(wb[0]) - b_min.x) / res)
		var z0 := int((float(wb[1]) - b_min.y) / res)
		var x1 := int((float(wb[0]) + float(wb[2]) - b_min.x) / res)
		var z1 := int((float(wb[1]) + float(wb[3]) - b_min.y) / res)
		for zi in range(maxi(z0, 0), mini(z1, h)):
			for xi in range(maxi(x0, 0), mini(x1, w)):
				var base := img.get_pixel(xi, zi)
				var c := base.blend(water_col) if base.a > 0.0 else water_col
				img.set_pixel(xi, zi, c)
	return img

func _nb(hm: PackedFloat32Array, w: int, h: int, x: int, z: int, fallback: float) -> float:
	if x < 0 or z < 0 or x >= w or z >= h:
		return fallback
	var v: float = hm[z * w + x]
	return fallback if is_nan(v) else v
