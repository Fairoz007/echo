extends Node3D
## Legacy cosmetic surface (Chapter 6). Parent translation remains the puzzle's water level.
## Now renders with the shared realistic water shader (FLOODED_TEMPLE preset).
## New content should use systems/water/WaterBody.tscn instead (mesh + volume + contract).
@export var surface_size := Vector2(80.0, 80.0)
@export var surface_offset := 0.4
@export_range(8, 96) var subdivisions := 64
@export var preset_name := "FLOODED_TEMPLE"
var surface_mesh: PlaneMesh
var surface: MeshInstance3D
var preset: WaterPreset
var time := 0.0

func set_graphics_quality(preset_index: int) -> void:
	subdivisions = 8 if preset_index == 0 else 64 if preset_index == 2 else 24
	if surface_mesh:
		surface_mesh.subdivide_width = subdivisions
		surface_mesh.subdivide_depth = subdivisions
	if surface:
		surface.material_override = _make_material(preset_index == 0)

func _ready() -> void:
	preset = WaterPreset.make(preset_name)
	WaterBody._make_textures()
	surface = MeshInstance3D.new()
	surface.name = "AnimatedWaterSurface"
	var plane := PlaneMesh.new()
	surface_mesh = plane
	plane.size = surface_size
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	surface.mesh = plane
	surface.position.y = surface_offset
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings")
	surface.material_override = _make_material(graphics != null and int(graphics.preset) == 0)
	add_child(surface)

func _make_material(low: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water_surface_low.gdshader" if low else "res://shaders/water_surface.gdshader")
	preset.apply_to(material, low)
	material.set_shader_parameter("normal_a", WaterBody._noise_normal)
	if not low:
		material.set_shader_parameter("normal_b", WaterBody._noise_normal_fine)
		material.set_shader_parameter("foam_noise", WaterBody._noise_foam)
	return material

func _process(delta: float) -> void:
	time += delta
	if surface and surface.material_override:
		surface.material_override.set_shader_parameter("water_time", time)

## Same contract as WaterBody for code that only has this node.
func get_surface_height(world_pos: Vector3) -> float:
	var h := 0.0
	var q := Vector2(world_pos.x, world_pos.z) - preset.flow_velocity * time
	var graphics := get_tree().root.get_node_or_null("GraphicsSettings") if is_inside_tree() else null
	for i in preset.wave_count(graphics != null and int(graphics.preset) == 0):
		var w: Vector4 = preset.waves[i]
		var d := Vector2(w.x + 1e-5, w.y).normalized()
		var k := TAU / maxf(w.w, 0.01)
		h += w.z * sin(k * d.dot(q) - sqrt(9.81 * k) * preset.wave_speed * time + float(i) * 1.7)
	return global_position.y + surface_offset + h
