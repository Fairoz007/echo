class_name Waterfall
extends Node3D
## Self-building waterfall. Origin = base of the cliff under the lip; water falls
## toward local +Z into a WATERFALL_BASIN WaterBody, then a RIVER WaterBody carries
## it downstream (also +Z). Rotate the Waterfall around Y only.
## Children created at runtime: Lip (wet rock StaticBody3D), Sheet, ImpactFoam,
## Mist, Basin (WaterBody), Downstream (WaterBody), Audio.

@export var fall_height := 6.0
@export var width := 3.0
@export var throw_distance := 0.9
@export var basin_size := Vector2(9, 7)
@export var basin_depth := 2.0
@export var downstream_length := 14.0
@export var downstream_width := 4.0
@export var downstream_flow_speed := 1.8
@export var build_lip_rock := true
@export var audio_stream: AudioStream = preload("res://audio/ambience/cave/AMB_PRO_CAVE_WATER.wav")
@export var audio_volume_db := 2.0
@export var mist_amount := 40

var basin: WaterBody
var downstream: WaterBody
var sheet_material: ShaderMaterial
static var _rock_noise: Texture2D

func _ready() -> void:
	WaterBody._make_textures()
	var impact_z := throw_distance + 0.2
	_build_lip()
	_build_sheet()
	# Basin: centered so the impact sits ~1/3 into it.
	basin = WaterBody.new()
	basin.name = "Basin"
	basin.preset_name = "WATERFALL_BASIN"
	basin.size = basin_size
	basin.depth = basin_depth
	basin.position = Vector3(0, 0, impact_z + basin_size.y * 0.5 - basin_size.y * 0.33)
	add_child(basin)
	downstream = WaterBody.new()
	downstream.name = "Downstream"
	var p := WaterPreset.make("RIVER")
	var fwd := global_transform.basis.z.normalized()
	p.flow_velocity = Vector2(fwd.x, fwd.z) * downstream_flow_speed
	downstream.preset = p
	downstream.size = Vector2(downstream_width, downstream_length) if absf(fwd.z) >= absf(fwd.x) else Vector2(downstream_length, downstream_width)
	downstream.depth = 1.2
	add_child(downstream)
	downstream.global_position = basin.global_position + fwd * (basin_size.y * 0.5 + downstream_length * 0.5 - 0.3) + Vector3(0, -0.05, 0)
	_build_foam(Vector3(0, 0.07, impact_z))
	_build_mist(Vector3(0, 0.1, impact_z))
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Audio"
	audio.stream = audio_stream
	audio.volume_db = audio_volume_db
	audio.unit_size = 6.0
	audio.max_distance = 45.0
	audio.position = Vector3(0, fall_height * 0.3, impact_z)
	audio.autoplay = true
	audio.finished.connect(audio.play)
	add_child(audio)

## WaterBody nodes ignore rotation, so a rotated Waterfall still works but keep
## basin_size roughly square if you rotate it by non-90 degree angles.
func _build_lip() -> void:
	if not build_lip_rock:
		return
	var lip := StaticBody3D.new()
	lip.name = "Lip"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width + 3.0, fall_height + 0.6, 2.5)
	mesh.mesh = box
	mesh.material_override = make_wet_rock_material(0.9)
	lip.add_child(mesh)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	cs.shape = bs
	lip.add_child(cs)
	lip.position = Vector3(0, (fall_height + 0.6) * 0.5 - 0.6, -1.25)
	add_child(lip)
	# Source channel water on top of the lip.
	var src := WaterBody.new()
	src.name = "SourceChannel"
	var p := WaterPreset.make("UNDERGROUND_STREAM")
	var fwd := global_transform.basis.z.normalized()
	p.flow_velocity = Vector2(fwd.x, fwd.z) * 1.6
	src.preset = p
	src.size = Vector2(width, 2.4)
	src.depth = 0.3
	src.splashes = false
	src.position = Vector3(0, fall_height + 0.02, -1.2)
	add_child(src)

func _build_sheet() -> void:
	var sheet := MeshInstance3D.new()
	sheet.name = "Sheet"
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Z
	plane.size = Vector2(width, fall_height)
	plane.subdivide_width = 8
	plane.subdivide_depth = 32
	sheet.mesh = plane
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet_material = ShaderMaterial.new()
	sheet_material.shader = preload("res://shaders/waterfall_sheet.gdshader")
	sheet_material.set_shader_parameter("streak_noise", WaterBody._noise_foam)
	sheet_material.set_shader_parameter("normal_noise", WaterBody._noise_normal_fine)
	sheet_material.set_shader_parameter("fall_height", fall_height)
	sheet_material.set_shader_parameter("throw_distance", throw_distance)
	sheet.material_override = sheet_material
	sheet.position = Vector3(0, fall_height * 0.5, 0.05)
	add_child(sheet)

func _build_foam(pos: Vector3) -> void:
	var foam := MeshInstance3D.new()
	foam.name = "ImpactFoam"
	var q := PlaneMesh.new()
	q.size = Vector2(width * 1.8, width * 1.6)
	foam.mesh = q
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/impact_foam.gdshader")
	m.set_shader_parameter("foam_noise", WaterBody._noise_foam)
	m.render_priority = 1
	foam.material_override = m
	foam.position = pos
	add_child(foam)

func _build_mist(pos: Vector3) -> void:
	var mist := CPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = mist_amount
	mist.local_coords = false
	mist.lifetime = 3.0
	mist.preprocess = 3.0
	var quad := QuadMesh.new()
	mist.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.6))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.88, 0.92, 0.94, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mist.material_override = mat
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(width * 0.5, 0.1, 0.4)
	mist.direction = Vector3(0, 1, 0.4)
	mist.spread = 40.0
	mist.initial_velocity_min = 0.6
	mist.initial_velocity_max = 1.8
	mist.gravity = Vector3(0, 0.15, 0)
	mist.damping_min = 0.3
	mist.damping_max = 0.8
	mist.scale_amount_min = 1.0
	mist.scale_amount_max = 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3)); curve.add_point(Vector2(0.4, 1)); curve.add_point(Vector2(1, 1.3))
	mist.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	mist.color_ramp = ramp
	mist.position = pos
	add_child(mist)

static func make_wet_rock_material(wetness := 0.85, color := Color(0.32, 0.30, 0.27)) -> ShaderMaterial:
	WaterBody._make_textures()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/wet_rock.gdshader")
	if _rock_noise == null:
		_rock_noise = WaterBody._noise_tex(0.008, 5, false, 1.0, 91)
		var n := (_rock_noise as NoiseTexture2D).noise as FastNoiseLite
		n.fractal_gain = 0.55
		_rock_noise.width = 512
		_rock_noise.height = 512
	m.set_shader_parameter("rock_noise", _rock_noise)
	m.set_shader_parameter("wetness", wetness)
	m.set_shader_parameter("rock_color", color)
	return m
