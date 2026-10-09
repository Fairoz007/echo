extends Node

## MaraAppearance (autoload): Mara Vale's cosmetic profile.
## Saved to user://appearance.cfg and applied to every Mara rig that enters the tree
## (the player and cutscene/NPC instances of the CHR_Mara GLBs).
##
## Mara is a single skinned mesh with one atlas texture, so there are no separate
## outfit, skin or hair materials. The recolor is done by a ShaderMaterial that reuses the
## original Color/Normal/ORM textures and classifies each texel by HSV:
##   skin      = warm orange, mid saturation, bright
##   hair      = dark red-brown, saturated (approximate: also touches some dark leather)
##   outfit A  = olive-green jacket/shirt panels
##   outfit B  = khaki/tan trousers and pouches (low-saturation warm)
## Each class is recoloured with luminance preserved, so folds and shading survive.

signal profile_changed

const SAVE_PATH := "user://appearance.cfg"
const MARA_MARKER := "/characters/mara/"
const ATTACH_GROUP := "mara_appearance_accessory"

## Safe body limits. The capsule is 1.72 m and Mara is normalised to 1.70 m,
## so height stays within +1 % / -4 % (1.632..1.717 m) and never pokes out of the capsule.
const HEIGHT_MIN := 0.96
const HEIGHT_MAX := 1.01
const BUILD_MIN := 0.94
const BUILD_MAX := 1.06

const OUTFIT_PRESETS := {
	"Expedition": [Color(0.42, 0.45, 0.28), Color(0.55, 0.46, 0.32)],
	"Desert": [Color(0.70, 0.58, 0.40), Color(0.80, 0.72, 0.56)],
	"Glacier": [Color(0.26, 0.38, 0.52), Color(0.36, 0.38, 0.42)],
	"Ember": [Color(0.62, 0.24, 0.16), Color(0.30, 0.26, 0.24)],
	"Midnight": [Color(0.16, 0.18, 0.24), Color(0.22, 0.22, 0.26)],
	"Moss": [Color(0.24, 0.36, 0.22), Color(0.38, 0.32, 0.22)],
}
const SKIN_TONES := [
	Color(0.96, 0.80, 0.68), Color(0.90, 0.68, 0.52), Color(0.80, 0.56, 0.40),
	Color(0.64, 0.42, 0.28), Color(0.46, 0.30, 0.20), Color(0.32, 0.21, 0.15),
]
const HAIR_COLORS := [
	Color(0.36, 0.18, 0.10), Color(0.12, 0.08, 0.06), Color(0.55, 0.36, 0.18),
	Color(0.80, 0.64, 0.38), Color(0.55, 0.16, 0.08), Color(0.45, 0.45, 0.47),
]
const ACCESSORIES := ["hat", "backpack", "satchel", "headlamp"]

const DEFAULTS := {
	"outfit_preset": "Expedition",
	"outfit_primary": Color(0.42, 0.45, 0.28),
	"outfit_secondary": Color(0.55, 0.46, 0.32),
	"outfit_strength": 0.0,   # 0 = original texture
	"skin_tone": Color(0.90, 0.68, 0.52),
	"skin_strength": 0.0,
	"hair_color": Color(0.36, 0.18, 0.10),
	"hair_strength": 0.0,
	"hat": false, "backpack": false, "satchel": false, "headlamp": false,
	"height": 1.0,
	"build": 1.0,
}

var profile: Dictionary = DEFAULTS.duplicate(true)
var _shader: Shader

const SHADER_CODE := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform vec4 albedo_mod : source_color = vec4(1.0);
uniform vec3 outfit_a = vec3(0.42, 0.45, 0.28);
uniform vec3 outfit_b = vec3(0.55, 0.46, 0.32);
uniform float outfit_strength = 0.0;
uniform vec3 skin_tone = vec3(0.9, 0.68, 0.52);
uniform float skin_strength = 0.0;
uniform vec3 hair_color = vec3(0.36, 0.18, 0.1);
uniform float hair_strength = 0.0;
uniform float debug_masks = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
float band(float x, float a, float b, float soft) {
	return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x));
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// Recolour keeping the texel's luminance relative to a reference luminance.
vec3 retint(vec3 src, vec3 target, float ref_l) {
	float l = luma(src) / max(ref_l, 0.02);
	return clamp(target * l, 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_mod;
	vec3 c = tex.rgb;
	// Classify in sRGB space (thresholds were picked on the atlas image).
	// Classify on a blurred (higher mip) sample so texture noise does not speckle the masks.
	vec3 cls = texture(albedo_tex, UV, 1.5).rgb * albedo_mod.rgb;
	vec3 s = pow(max(cls, vec3(0.0)), vec3(1.0 / 2.2));
	vec3 hsv = rgb2hsv(s);
	float h = hsv.x; float sat = hsv.y; float v = hsv.z;
	float warm = 1.0 - smoothstep(0.075, 0.09, h); // red..orange (also catches h~1.0 reds via wrap below)
	warm = max(warm, smoothstep(0.96, 0.98, h));
	float skin = warm * smoothstep(0.20, 0.28, sat) * (1.0 - smoothstep(0.80, 0.9, sat)) * smoothstep(0.46, 0.56, v);
	float hair = warm * smoothstep(0.45, 0.55, sat) * band(v, 0.12, 0.50, 0.04) * (1.0 - skin);
	float out_a = band(h, 0.135, 0.36, 0.02) * smoothstep(0.11, 0.17, sat) * smoothstep(0.14, 0.22, v);
	float out_b = band(h, 0.085, 0.14, 0.01) * smoothstep(0.14, 0.22, sat) * (1.0 - smoothstep(0.50, 0.58, sat)) * smoothstep(0.42, 0.52, v);
	// Swatch colours arrive as sRGB (no source_color hint: the Compatibility renderer
	// did not linearise them consistently), so convert here.
	vec3 lin_a = pow(outfit_a, vec3(2.2));
	vec3 lin_b = pow(outfit_b, vec3(2.2));
	vec3 lin_skin = pow(skin_tone, vec3(2.2));
	vec3 lin_hair = pow(hair_color, vec3(2.2));
	vec3 col = c;
	col = mix(col, retint(c, lin_a, 0.16), out_a * outfit_strength);
	col = mix(col, retint(c, lin_b, 0.40), out_b * outfit_strength);
	vec3 sk = retint(c, lin_skin, 0.45);
	sk = mix(sk, vec3(luma(sk)), 0.22); // tame the saturation boost of dark tones
	col = mix(col, sk, skin * skin_strength);
	col = mix(col, retint(c, lin_hair, 0.04), hair * hair_strength);
	if (debug_masks > 0.5) col = vec3(skin + hair, out_a, out_b + hair);
	ALBEDO = col;
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		AO = orm.r; ROUGHNESS = orm.g; METALLIC = orm.b;
	} else {
		ROUGHNESS = 0.8; METALLIC = 0.0;
	}
	if (has_normal) NORMAL_MAP = texture(normal_tex, UV).rgb;
}
"""

func _ready() -> void:
	load_profile()
	get_tree().node_added.connect(_on_node_added)

# ---------------------------------------------------------------- persistence

func load_profile() -> void:
	profile = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in DEFAULTS:
		if cfg.has_section_key("mara", key):
			var v = cfg.get_value("mara", key)
			if typeof(v) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and v is int):
				profile[key] = v
	_sanitize()

func save_profile() -> void:
	_sanitize()
	var cfg := ConfigFile.new()
	for key in profile:
		cfg.set_value("mara", key, profile[key])
	cfg.save(SAVE_PATH)

func _sanitize() -> void:
	profile.height = clampf(float(profile.height), HEIGHT_MIN, HEIGHT_MAX)
	profile.build = clampf(float(profile.build), BUILD_MIN, BUILD_MAX)
	for k in ["outfit_strength", "skin_strength", "hair_strength"]:
		profile[k] = clampf(float(profile[k]), 0.0, 1.0)

func set_value(key: String, value) -> void:
	profile[key] = value
	_sanitize()
	apply_all()
	profile_changed.emit()

func set_outfit_preset(preset: String) -> void:
	if not OUTFIT_PRESETS.has(preset):
		return
	profile.outfit_preset = preset
	profile.outfit_primary = OUTFIT_PRESETS[preset][0]
	profile.outfit_secondary = OUTFIT_PRESETS[preset][1]
	profile.outfit_strength = 0.0 if preset == "Expedition" else 0.85
	apply_all()
	profile_changed.emit()

func reset_profile() -> void:
	profile = DEFAULTS.duplicate(true)
	apply_all()
	profile_changed.emit()

func randomize_profile() -> void:
	var names := OUTFIT_PRESETS.keys()
	set_outfit_preset(names[randi() % names.size()])
	profile.outfit_strength = 0.85
	profile.skin_tone = SKIN_TONES[randi() % SKIN_TONES.size()]
	profile.skin_strength = randf_range(0.5, 1.0)
	profile.hair_color = HAIR_COLORS[randi() % HAIR_COLORS.size()]
	profile.hair_strength = randf_range(0.5, 1.0)
	for a in ACCESSORIES:
		profile[a] = randf() < 0.5
	profile.height = randf_range(HEIGHT_MIN, HEIGHT_MAX)
	profile.build = randf_range(BUILD_MIN, BUILD_MAX)
	_sanitize()
	apply_all()
	profile_changed.emit()

# ---------------------------------------------------------------- discovery

func _on_node_added(node: Node) -> void:
	if node is Skeleton3D:
		_apply_later.call_deferred(weakref(node))

func _apply_later(reference: WeakRef) -> void:
	# Two frames: lets Player._ready normalise the visual height first.
	var skel := reference.get_ref() as Skeleton3D
	if skel == null:
		return
	await get_tree().process_frame
	skel = reference.get_ref() as Skeleton3D
	if skel and is_mara_skeleton(skel):
		apply_to_skeleton(skel)

func is_mara_skeleton(skel: Skeleton3D) -> bool:
	if skel.find_bone("Spine02") < 0 or skel.find_bone("Head") < 0:
		return false
	var n: Node = skel
	while n:
		if n.scene_file_path.contains(MARA_MARKER) or n.is_in_group("player") or n.is_in_group("mara_preview"):
			return true
		n = n.get_parent()
	return false

## Finds the player's skeleton using the Player API if present.
static func skeleton_of(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root.has_method("get_skeleton"):
		var s = root.get_skeleton()
		if s is Skeleton3D:
			return s
	if root.has_method("get_visual_root"):
		var v = root.get_visual_root()
		if v is Node:
			var s2 := (v as Node).find_child("Skeleton3D", true, false) as Skeleton3D
			if s2:
				return s2
	return root.find_child("Skeleton3D", true, false) as Skeleton3D

func apply_all() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var done := {}
	for p in tree.get_nodes_in_group("player"):
		var s := skeleton_of(p)
		if s:
			apply_to_skeleton(s)
			done[s] = true
	for s in tree.root.find_children("*", "Skeleton3D", true, false):
		if not done.has(s) and is_mara_skeleton(s):
			apply_to_skeleton(s)

# ---------------------------------------------------------------- application

func apply_to_skeleton(skel: Skeleton3D) -> void:
	for mi in skel.get_children():
		if mi is MeshInstance3D:
			_apply_material(mi)
	_apply_body(skel)
	_apply_accessories(skel)

func _apply_material(mi: MeshInstance3D) -> void:
	var mat := mi.material_override as ShaderMaterial
	if mat == null or not mat.has_meta("mara_appearance"):
		var src := mi.get_active_material(0) as BaseMaterial3D
		if src == null and mi.mesh:
			src = mi.mesh.surface_get_material(0) as BaseMaterial3D
		if src == null:
			return
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER_CODE
		mat = ShaderMaterial.new()
		mat.shader = _shader
		mat.set_meta("mara_appearance", true)
		mat.set_shader_parameter("albedo_tex", src.albedo_texture)
		mat.set_shader_parameter("albedo_mod", src.albedo_color)
		if src.normal_enabled and src.normal_texture:
			mat.set_shader_parameter("normal_tex", src.normal_texture)
			mat.set_shader_parameter("has_normal", true)
		var orm := src as ORMMaterial3D
		if orm and orm.orm_texture:
			mat.set_shader_parameter("orm_tex", orm.orm_texture)
			mat.set_shader_parameter("has_orm", true)
		elif src.roughness_texture:
			mat.set_shader_parameter("orm_tex", src.roughness_texture)
			mat.set_shader_parameter("has_orm", true)
	var active := float(profile.outfit_strength) + float(profile.skin_strength) + float(profile.hair_strength) > 0.001
	if not active:
		# Untouched profile: keep the original imported material (cheapest, exact).
		mi.material_override = null
		mi.set_meta("mara_appearance_mat", mat)
		return
	mat.set_shader_parameter("outfit_a", profile.outfit_primary)
	mat.set_shader_parameter("outfit_b", profile.outfit_secondary)
	mat.set_shader_parameter("outfit_strength", profile.outfit_strength)
	mat.set_shader_parameter("skin_tone", profile.skin_tone)
	mat.set_shader_parameter("skin_strength", profile.skin_strength)
	mat.set_shader_parameter("hair_color", profile.hair_color)
	mat.set_shader_parameter("hair_strength", profile.hair_strength)
	mi.material_override = mat

## Scales the Skeleton3D node (not the player root), so the collision capsule,
## camera rig and Player's height normalisation are untouched. Feet stay on the
## ground because the skeleton origin is at the soles.
func _apply_body(skel: Skeleton3D) -> void:
	var h := float(profile.height)
	var b := float(profile.build)
	skel.scale = Vector3(b, h, b)

# ---------------------------------------------------------------- accessories

func _apply_accessories(skel: Skeleton3D) -> void:
	for a in ACCESSORIES:
		var node_name: String = "MaraAcc_" + str(a)
		var existing := skel.get_node_or_null(node_name)
		if bool(profile.get(a, false)):
			if existing == null:
				var att := _build_accessory(skel, a)
				if att:
					att.name = node_name
					skel.add_child(att)
		elif existing:
			existing.queue_free()
			existing.name = node_name + "_dead"

## Skeleton (model) space: up +Y, Mara faces +X, +Z is her right side. Model is 1 unit tall.
## Accessories are authored in that space, then converted into the bone's local frame.
func _build_accessory(skel: Skeleton3D, kind: String) -> BoneAttachment3D:
	var bone := ""
	var parts: Array = [] # [mesh, model-space Transform3D, material]
	match kind:
		"hat":
			bone = "Head"
			var felt := _mat(Color(0.36, 0.27, 0.17), 0.9)
			var band := _mat(Color(0.16, 0.11, 0.08), 0.8)
			parts.append([_cyl(0.105, 0.105, 0.006, 28), _at(Vector3(0.056, 0.952, 0.0)), felt])
			parts.append([_cyl(0.050, 0.060, 0.050, 24), _at(Vector3(0.052, 0.978, 0.0)), felt])
			parts.append([_cyl(0.0615, 0.0615, 0.012, 24), _at(Vector3(0.052, 0.962, 0.0)), band])
		"headlamp":
			bone = "Head"
			var strap := _mat(Color(0.08, 0.08, 0.09), 0.7)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.054
			torus.outer_radius = 0.061
			torus.rings = 24
			torus.ring_segments = 6
			parts.append([torus, Transform3D(Basis(Vector3(0, 0, 1), 0.12), Vector3(0.056, 0.925, -0.002)), strap])
			var lamp := BoxMesh.new()
			lamp.size = Vector3(0.022, 0.022, 0.034)
			parts.append([lamp, _at(Vector3(0.114, 0.932, -0.002)), _mat(Color(0.18, 0.18, 0.2), 0.4, 0.6)])
			var lens := _cyl(0.009, 0.009, 0.004, 14)
			var lens_mat := _mat(Color(1.0, 0.95, 0.8), 0.2)
			lens_mat.emission_enabled = true
			lens_mat.emission = Color(1.0, 0.92, 0.7)
			lens_mat.emission_energy_multiplier = 2.0
			parts.append([lens, Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(0.126, 0.932, -0.002)), lens_mat])
		"backpack":
			bone = "Spine02"
			var canvas := _mat(Color(0.30, 0.26, 0.18), 0.95)
			var body := BoxMesh.new()
			body.size = Vector3(0.075, 0.20, 0.17)
			parts.append([body, _at(Vector3(-0.085, 0.715, -0.004)), canvas])
			var roll := _cyl(0.026, 0.026, 0.17, 14)
			parts.append([roll, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.082, 0.828, -0.004)), _mat(Color(0.20, 0.24, 0.20), 0.9)])
			var pocket := BoxMesh.new()
			pocket.size = Vector3(0.03, 0.08, 0.12)
			parts.append([pocket, _at(Vector3(-0.132, 0.67, -0.004)), _mat(Color(0.26, 0.22, 0.15), 0.95)])
			for zz in [-0.055, 0.055]:
				var strap := BoxMesh.new()
				strap.size = Vector3(0.11, 0.012, 0.022)
				parts.append([strap, Transform3D(Basis(Vector3(0, 0, 1), -0.35), Vector3(-0.01, 0.80, zz)), _mat(Color(0.12, 0.1, 0.08), 0.8)])
		"satchel":
			bone = "Spine01"
			var leather := _mat(Color(0.38, 0.22, 0.12), 0.65)
			var bag := BoxMesh.new()
			bag.size = Vector3(0.10, 0.075, 0.035)
			parts.append([bag, _at(Vector3(0.06, 0.515, -0.105)), leather])
			var flap := BoxMesh.new()
			flap.size = Vector3(0.104, 0.03, 0.038)
			parts.append([flap, _at(Vector3(0.06, 0.548, -0.106)), _mat(Color(0.30, 0.17, 0.09), 0.6)])
		_:
			return null
	var idx := skel.find_bone(bone)
	if idx < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	att.add_to_group(ATTACH_GROUP)
	var inv := skel.get_bone_global_rest(idx).affine_inverse()
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[2]
		mi.transform = inv * (p[1] as Transform3D)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		att.add_child(mi)
	return att

static func _at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos)

static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m

static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m
