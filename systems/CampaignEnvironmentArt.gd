extends Node3D
## Reusable Tripo ground/foliage dressing; authored gameplay collision is preserved.
## Load-spike safe: the ground GLB and foliage GLBs load on a worker thread
## (ResourceLoader threaded requests) and placement runs under a per-frame time
## budget, so no single frame pays for the whole dressing pass.
## Pass --profile-build to print per-stage cost.
@export_range(1, 10) var chapter_index := 1
const GROUND := "res://assets/environment/cave/cave_floor_sediment.glb"
const TREE := "res://assets/environment/jungle/jungle_tree.glb"
const FERN := "res://assets/environment/jungle/jungle_fern.glb"
const FRAME_BUDGET_USEC := 4000
signal dressed
var ground_instances: MultiMeshInstance3D
var ground_mesh: Mesh
var ground_bounds: AABB
var ground_preset := -1
var ground_transforms: Array[Transform3D] = []
var foliage: Array[Node3D] = []
var foliage_density := 1.0
var is_dressed := false
var _profile := false

func set_graphics_quality(preset: int) -> void:
	if ground_mesh == null:
		# Asked before the threaded load finished (GraphicsSettings / QA): block on it.
		# Worst case this equals the old synchronous load.
		var packed: PackedScene = null
		if ResourceLoader.load_threaded_get_status(GROUND) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
			packed = ResourceLoader.load_threaded_get(GROUND)
		else:
			packed = load(GROUND)
		if not _make_ground(packed):
			return
	if ground_preset == preset:
		return
	ground_preset = preset
	var tile_size: float = [20.0, 8.0, 6.0][clampi(preset, 0, 2)]
	var columns := int(ceil(120.0 / tile_size))
	var rows := int(ceil(140.0 / tile_size))
	var step_x := 120.0 / columns
	var step_z := 140.0 / rows
	var floor_y := -3.8 if chapter_index == 6 else 0.0
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = ground_mesh
	instances.instance_count = columns * rows
	ground_transforms.clear()
	var scale_factor := Vector3(step_x + 1.5, 0.16, step_z + 1.5) / ground_bounds.size
	for x in range(columns):
		for z in range(rows):
			var basis := Basis(Vector3.UP, PI if (x + z) % 2 == 0 else 0.0).scaled(scale_factor)
			var center := Vector3(-60.0 + step_x * (x + 0.5), floor_y - 0.05, -80.0 + step_z * (z + 0.5))
			var placement := Transform3D(basis, center - basis * ground_bounds.get_center())
			ground_transforms.append(placement)
			instances.set_instance_transform(x * rows + z, placement)
	ground_instances.multimesh = instances

## GraphicsSettings hook (5-level dictionary). Foliage spawned over several frames
## would miss the scene-wide thinning pass, so this node thins its own pieces.
func set_quality_settings(settings: Dictionary) -> void:
	foliage_density = float(settings.get("foliage_density", 1.0))
	_apply_foliage_density()

func _apply_foliage_density() -> void:
	for i in foliage.size():
		if is_instance_valid(foliage[i]):
			foliage[i].visible = fmod(i * 0.6180339, 1.0) < foliage_density

func _ready() -> void:
	_profile = OS.get_cmdline_user_args().has("--profile-build")
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	if graphics and "settings" in graphics:
		foliage_density = float(graphics.settings.get("foliage_density", 1.0))
	var paths := [GROUND]
	if chapter_index == 1:
		paths += [TREE, FERN]
	for p in paths:
		ResourceLoader.load_threaded_request(p)
	var level := get_parent()
	var t := Time.get_ticks_usec()
	# Material swap must happen before the first drawn frame (no white blockout flash).
	preload("res://systems/environment/BlockoutDresser.gd").apply(level)
	for floor_node in ["Ground", "JungleFloor", "SanctuaryGround", "TempleStructure/Floor", "TempleGround", "CityGround", "VaultGround", "CaveGround"]:
		var body := level.get_node_or_null(floor_node)
		if body:
			for child in body.get_children():
				if child is GeometryInstance3D:
					child.visible = false
	preload("res://systems/environment/EnvironmentCollision.gd").attach(level)
	_log("dresser+hide", t)
	_dress.call_deferred()

func _log(label: String, t: int) -> void:
	if _profile:
		print("[CampaignEnvironmentArt] ch%d %s %.1f ms" % [chapter_index, label, (Time.get_ticks_usec() - t) / 1000.0])

func _await_resource(path: String) -> Resource:
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if not is_inside_tree():
			return null
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path)
	return load(path) # request already consumed (set_graphics_quality) -> cache hit

func _dress() -> void:
	var packed: PackedScene = null
	if ground_mesh == null:
		packed = await _await_resource(GROUND) as PackedScene
	if not is_inside_tree():
		return
	var t := Time.get_ticks_usec()
	if ground_mesh == null:
		_make_ground(packed)
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	set_graphics_quality(int(graphics.preset) if graphics else 0)
	_log("ground", t)
	if chapter_index == 1:
		await _await_resource(TREE)
		await _await_resource(FERN)
		var jobs: Array = []
		for i in range(24):
			var side := -1.0 if i % 2 == 0 else 1.0
			var position_hint := Vector3(side * (16.0 + float(i % 3) * 5.0), 0, 22.0 - float(i / 2) * 7.0)
			jobs.append([TREE, position_hint + Vector3.UP * 5.0, Vector3(6, 10, 6), float(i) * 1.37])
		for i in range(60):
			var side := -1.0 if i % 2 == 0 else 1.0
			var position_hint := Vector3(side * (9.0 + float(i % 5) * 3.0), 0.5, 28.0 - float(i / 2) * 3.0)
			jobs.append([FERN, position_hint, Vector3(1.4, 1.0, 1.4), float(i) * 2.4])
		t = Time.get_ticks_usec()
		var frame_start := Time.get_ticks_usec()
		for job in jobs:
			if not is_inside_tree():
				return
			var piece := _place(job[0], job[1], job[2])
			piece.rotation.y = job[3]
			foliage.append(piece)
			piece.visible = fmod((foliage.size() - 1) * 0.6180339, 1.0) < foliage_density
			if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
				await get_tree().process_frame
				frame_start = Time.get_ticks_usec()
		_log("foliage (spread)", t)
	is_dressed = true
	dressed.emit()

func _make_ground(packed: PackedScene) -> bool:
	if packed == null:
		return false
	var source := packed.instantiate()
	var source_mesh := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	ground_mesh = source_mesh.mesh.duplicate() as Mesh
	ground_bounds = source_mesh.get_aabb()
	for surface in range(ground_mesh.get_surface_count()):
		ground_mesh.surface_set_material(surface, source_mesh.get_active_material(surface))
	source.free()
	ground_instances = MultiMeshInstance3D.new()
	ground_instances.name = "SedimentGroundInstances"
	ground_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# LevelCave may already have built its own floor and asked for this one hidden.
	ground_instances.visible = not has_meta("hide_ground")
	add_child(ground_instances)
	return true

func _place(path: String, center: Vector3, dimensions: Vector3) -> Node3D:
	var packed := load(path) as PackedScene
	var piece := packed.instantiate() as Node3D
	add_child(piece)
	var bounds := AABB()
	var started := false
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.get_aabb()
		bounds = bounds.merge(box) if started else box
		started = true
	var factor := dimensions / bounds.size
	piece.scale = factor
	piece.position = center - bounds.get_center() * factor
	if path == TREE or path == FERN:
		var wind := preload("res://systems/FoliageWind.gd").new()
		wind.name = "FoliageWind"
		piece.add_child(wind)
		wind.configure(piece, dimensions.y, center.y - dimensions.y * 0.5)
	return piece
