extends Node

## Graphics quality presets for ECHOES BENEATH.
##
## quality_level: 0 ULTRA LOW, 1 LOW, 2 MEDIUM, 3 HIGH, 4 ULTRA.
## `preset` is kept as a read-only legacy tier (0 Low / 1 Balanced / 2 High) because
## world systems (WaterBody, FoliageWind, CavernArt, GrassScatter, ...) call
## set_graphics_quality(tier) and read GraphicsSettings.preset.
## New consumers should read `settings` (Dictionary) or connect to `quality_changed`.
##
## Screen-space effects (SSAO/SSIL/SSR/volumetric fog/TAA/FSR) only exist on the
## Forward+ renderer. On GL Compatibility (safe mode / fallback) they are skipped.

signal quality_changed(level: int, settings: Dictionary)

const QUALITY_NAMES := ["Ultra Low", "Low", "Medium", "High", "Ultra"]
## Legacy alias so older UI/QA code that iterates PRESETS still works.
const PRESETS := QUALITY_NAMES
const DEFAULT_LEVEL := 1
const SETTINGS_PATH := "user://settings.cfg"

const TABLE := {
	#                 ULTRA LOW  LOW     MEDIUM   HIGH     ULTRA
	"render_scale":      [0.5,   0.67,   0.77,    1.0,     1.0],
	"upscaler":          ["bilinear", "fsr1", "fsr1", "bilinear", "bilinear"],
	"shadow_atlas":      [1024,  2048,   2048,    4096,    8192],
	"shadow_distance":   [20.0,  35.0,   60.0,    100.0,   160.0],
	"shadows":           [false, true,   true,    true,    true],
	"soft_shadow":       [0,     0,      1,       2,       3],
	"ssao":              [false, false,  true,    true,    true],
	"ssil":              [false, false,  false,   false,   true],
	"ssr":               [false, false,  false,   true,    true],
	"volumetric_fog":    [false, false,  false,   true,    true],
	"glow":              [false, false,  true,    true,    true],
	"lod_bias":          [0.35,  0.6,    1.0,     1.5,     2.0],
	"msaa":              [0,     0,      0,       1,       2],   # 0 off, 1 2x, 2 4x
	"fxaa":              [false, true,   true,    false,   false],
	"taa":               [false, false,  false,   false,   true],
	"vegetation_density":[0.25,  0.5,    0.75,    1.0,     1.0],
	"water_quality":     [0,     0,      1,       2,       2],   # 0 low, 1 medium, 2 high
	"max_fps":           [60,    60,     0,       0,       0],   # 0 = uncapped (vsync governs)
	# --- Foliage / character keys (read by the wind, nature and character systems
	# with defaults; see get_setting()). Keep every row 5 entries long.
	"foliage_density":   [0.35,  0.6,    0.8,     1.0,     1.0],  # fraction of authored trees/ferns kept
	"foliage_wind_detail":[0,    1,      1,       2,       2],    # 0 primary sway only, 1 +leaf flutter, 2 +secondary branch
	"leaf_particles":    [0,     0,      1,       1,       1],    # 0 off, 1 on (falling-leaf emitters)
	"vegetation_interaction":[0, 1,      1,       1,       1],    # 0 off, 1 player pushes grass/foliage
	"character_ik_quality":[0,   0,      1,       2,       2],    # 0 off/cheap, 1 foot IK, 2 foot+hand/look IK
	"natural_lighting":  [0.0,   0.0,    0.0,     0.65,    1.0],  # authored light balance -> refined High/Ultra
}
## Legacy 3-tier mapping consumed by set_graphics_quality(tier).
const LEGACY_TIER := [0, 0, 1, 2, 2]

var quality_level := DEFAULT_LEVEL
var settings: Dictionary = {}
var preset: int:
	get:
		return LEGACY_TIER[quality_level]
	set(value):
		# Legacy callers set 0..2; map onto the 5-level scale.
		quality_level = [1, 2, 3][clampi(value, 0, 2)]

var vegetation_density: float:
	get:
		return float(settings.get("vegetation_density", 1.0))
var water_quality: int:
	get:
		return int(settings.get("water_quality", 2))

## Safe accessor for consumers: GraphicsSettings.get_setting("foliage_density", 1.0)
func get_setting(key: String, default_value: Variant = null) -> Variant:
	return settings.get(key, default_value)

func is_forward_plus() -> bool:
	return RenderingServer.get_rendering_device() != null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in TABLE:
		if TABLE[key].size() != QUALITY_NAMES.size():
			push_error("GraphicsSettings.TABLE[%s] needs %d entries" % [key, QUALITY_NAMES.size()])
	var level := DEFAULT_LEVEL
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		if cfg.has_section_key("graphics", "quality_level"):
			level = int(cfg.get_value("graphics", "quality_level", DEFAULT_LEVEL))
		elif cfg.has_section_key("graphics", "preset"):
			# Migrate old 3-step preset (0 Low, 1 Balanced, 2 High).
			level = [1, 2, 3][clampi(int(cfg.get_value("graphics", "preset", 1)), 0, 2)]
	for argument in OS.get_cmdline_user_args():
		if argument == "--safe-graphics":
			level = 0
		elif argument.begins_with("--quality="):
			level = int(argument.get_slice("=", 1))
	get_tree().scene_changed.connect(_on_scene_changed)
	apply_quality(level, false)

## Legacy entry point (0..2) kept for existing callers; prefer apply_quality().
func apply_preset(index: int, persist := true) -> void:
	apply_quality([1, 2, 3][clampi(index, 0, 2)], persist)

func apply_quality(level: int, persist := true) -> void:
	quality_level = clampi(level, 0, QUALITY_NAMES.size() - 1)
	settings = {}
	for key in TABLE:
		settings[key] = TABLE[key][quality_level]
	settings["name"] = QUALITY_NAMES[quality_level]
	settings["forward_plus"] = is_forward_plus()
	_apply_viewport()
	if persist:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("graphics", "quality_level", quality_level)
		if cfg.has_section_key("graphics", "preset"):
			cfg.erase_section_key("graphics", "preset")
		cfg.save(SETTINGS_PATH)
	_apply_scene()
	quality_changed.emit(quality_level, settings)

func _apply_viewport() -> void:
	Engine.max_fps = int(settings.max_fps)
	var viewport := get_viewport()
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(settings.msaa)]
	viewport.mesh_lod_threshold = 1.0 / float(settings.lod_bias)
	RenderingServer.directional_shadow_atlas_set_size(int(settings.shadow_atlas), true)
	viewport.positional_shadow_atlas_size = int(settings.shadow_atlas) / 2
	var soft := int(settings.soft_shadow)
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	if is_forward_plus():
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if settings.upscaler == "fsr1" else Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = float(settings.render_scale)
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if settings.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.use_taa = bool(settings.taa)
	else:
		# GL Compatibility: no 3D scaling (only bilinear is honoured) and no TAA.
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = float(settings.render_scale)

func _on_scene_changed() -> void:
	await get_tree().process_frame
	_apply_scene()

func _apply_scene() -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var fp := is_forward_plus()
	for mesh in scene.find_children("*", "GeometryInstance3D", true, false):
		mesh.lod_bias = float(settings.lod_bias)
	for light in scene.find_children("*", "Light3D", true, false):
		if not light.has_meta("quality_shadow"):
			light.set_meta("quality_shadow", light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta("quality_shadow")) and bool(settings.shadows)
		if light is DirectionalLight3D:
			if not light.has_meta("quality_shadow_distance"):
				light.set_meta("quality_shadow_distance", light.directional_shadow_max_distance)
			light.directional_shadow_max_distance = minf(float(light.get_meta("quality_shadow_distance")), float(settings.shadow_distance))
	var env_keys := {"ssao_enabled": "ssao", "ssil_enabled": "ssil", "ssr_enabled": "ssr", "volumetric_fog_enabled": "volumetric_fog", "glow_enabled": "glow", "sdfgi_enabled": "ssil"}
	var environments: Array = []
	for world in scene.find_children("*", "WorldEnvironment", true, false):
		environments.append(world)
	for camera in scene.find_children("*", "Camera3D", true, false):
		if camera.environment:
			environments.append(camera)
	for holder in environments:
		var environment: Environment = holder.environment
		if environment == null:
			continue
		for property in env_keys:
			if not holder.has_meta(property):
				holder.set_meta(property, environment.get(property))
			var authored := bool(holder.get_meta(property))
			var wanted := bool(settings[env_keys[property]])
			# Effects the level designer never enabled stay off; SSAO/SSR/fog may be
			# promoted on High/Ultra Forward+ even if not authored (except SDFGI/SSIL).
			var enable: bool = wanted and (authored or (fp and property in ["ssao_enabled", "ssr_enabled"]))
			if property != "glow_enabled" and not fp:
				enable = false
			environment.set(property, enable)
	var tier: int = LEGACY_TIER[quality_level]
	var density := float(settings.foliage_density)
	var foliage_index := 0
	for model in scene.find_children("*", "Node3D", true, false):
		if model.scene_file_path.ends_with("jungle_tree.glb") or model.scene_file_path.ends_with("jungle_fern.glb"):
			# Deterministic thinning: keep `density` fraction of authored foliage instances.
			model.visible = fmod(foliage_index * 0.6180339, 1.0) < density
			foliage_index += 1
	for node in scene.find_children("*", "Node", true, false):
		if node.has_method("set_graphics_quality"):
			node.set_graphics_quality(tier)
		if node.has_method("set_quality_settings"):
			node.set_quality_settings(settings)
