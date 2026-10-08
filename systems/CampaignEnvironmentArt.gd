extends Node3D
## Reusable Tripo ground/foliage dressing; authored gameplay collision is preserved.
@export_range(1, 10) var chapter_index := 1
const GROUND := "res://assets/environment/cave/cave_floor_sediment.glb"
const TREE := "res://assets/environment/jungle/jungle_tree.glb"
const FERN := "res://assets/environment/jungle/jungle_fern.glb"
var ground_instances: MultiMeshInstance3D
var ground_mesh: Mesh
var ground_bounds: AABB
var ground_preset := -1
var ground_transforms: Array[Transform3D] = []

func set_graphics_quality(preset: int) -> void:
	if ground_mesh == null or ground_preset == preset:
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

func _ready() -> void:
	var source := (load(GROUND) as PackedScene).instantiate()
	var source_mesh := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	ground_mesh = source_mesh.mesh.duplicate() as Mesh
	ground_bounds = source_mesh.get_aabb()
	for surface in range(ground_mesh.get_surface_count()):
		ground_mesh.surface_set_material(surface, source_mesh.get_active_material(surface))
	source.free()
	ground_instances = MultiMeshInstance3D.new()
	ground_instances.name = "SedimentGroundInstances"
	ground_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_instances)
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	set_graphics_quality(int(graphics.preset) if graphics else 0)
	var level := get_parent()
	preload("res://systems/environment/EnvironmentCollision.gd").attach(level)
	preload("res://systems/environment/BlockoutDresser.gd").apply(level)
	for floor_node in ["Ground", "JungleFloor", "SanctuaryGround", "TempleStructure/Floor", "TempleGround", "CityGround", "VaultGround", "CaveGround"]:
		var body := level.get_node_or_null(floor_node)
		if body:
			for child in body.get_children():
				if child is GeometryInstance3D:
					child.visible = false
	if chapter_index == 1:
		for i in range(24):
			var side := -1.0 if i % 2 == 0 else 1.0
			var position_hint := Vector3(side * (16.0 + float(i % 3) * 5.0), 0, 22.0 - float(i / 2) * 7.0)
			var tree := _place(TREE, position_hint + Vector3.UP * 5.0, Vector3(6, 10, 6))
			tree.rotation.y = float(i) * 1.37
		for i in range(60):
			var side := -1.0 if i % 2 == 0 else 1.0
			var position_hint := Vector3(side * (9.0 + float(i % 5) * 3.0), 0.5, 28.0 - float(i / 2) * 3.0)
			var fern := _place(FERN, position_hint, Vector3(1.4, 1.0, 1.4))
			fern.rotation.y = float(i) * 2.4

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
