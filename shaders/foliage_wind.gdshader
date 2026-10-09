// PBR foliage with tiered wind response (keeps the original Tripo texture inputs).
// Driven by systems/nature/WindSystem.gd through wind_common.gdshaderinc.
//   primary (trunk_bend) : whole-plant sway, weight hn^2 with a root lock -> base never moves
//   branch_sway          : grows with distance from the trunk axis (flex mask) and height
//   leaf_flutter         : fast secondary flutter on the flexible outer parts, per-vertex phase
//   interact_strength    : bends away from the player (bushes/ferns; trees default 0)
//   pin_top              : vines - anchored at the top, free end at the bottom
// Flex mask = vertex color R when use_vertex_color_mask, else radial distance from the trunk axis.
// Neighbouring plants are desynced by a hash of the plant's world position.
// Rocks: do not use this shader (zero motion). Collision shapes are never affected.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
#include "res://shaders/wind_common.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_texture : filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_factor = 1.0;
uniform float metallic_factor = 1.0;
uniform float normal_scale = 1.0;
uniform float root_height = 0.0;      // world Y of the plant base
uniform float plant_height = 10.0;
uniform float plant_radius = 3.0;
// World position of the trunk axis; y < -90000 -> use the mesh origin.
uniform vec3 plant_origin = vec3(0.0, -100000.0, 0.0);
uniform float wind_scale = 0.1; // legacy "wind_strength" multiplier per plant
uniform float trunk_bend = 0.25;
uniform float branch_sway = 1.0;
uniform float leaf_flutter = 0.35;
uniform float root_lock = 0.08;       // fraction of height that stays perfectly rooted
uniform float interact_strength = 0.0;
uniform bool use_vertex_color_mask = false;
uniform bool pin_top = false;
varying float v_flex;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 origin = plant_origin.y < -90000.0 ? MODEL_MATRIX[3].xyz : plant_origin;
	vec3 rest = VERTEX;
	float H = max(plant_height, 0.1);
	float hn = clamp((rest.y - root_height) / H, 0.0, 1.0);
	float radial = clamp(length(rest.xz - origin.xz) / max(plant_radius, 0.1), 0.0, 1.0);
	float hw;
	float flex;
	if (pin_top) {
		float down = 1.0 - hn;
		hw = down * down * smoothstep(0.0, root_lock, down);
		flex = down;
	} else {
		hw = hn * hn * smoothstep(0.0, max(root_lock, 0.001), hn);
		flex = use_vertex_color_mask ? COLOR.r : smoothstep(0.12, 1.0, radial) * smoothstep(0.0, 0.35, hn);
	}
	v_flex = flex;
	vec2 d = wind_dir2();
	vec3 dw = vec3(d.x, 0.0, d.y);
	vec3 side = vec3(d.y, 0.0, -d.x);
	float s = wind_scalar(origin) * wind_scale;
	float ph = hash12(origin.xz) * 6.2831853;
	float sp = wind_phase;
	float t = wind_time;
	float storm = storm_intensity;

	// Primary: lean + slow sway (amplitude in meters scales with plant height).
	float osc = 0.55 + 0.45 * sin(sp * 0.9 + ph) + 0.15 * sin(sp * 2.13 + ph * 1.7);
	float A = s * trunk_bend * H;
	vec3 off = dw * A * osc * hw;
	off += side * A * 0.18 * sin(sp * 0.71 + ph * 2.3) * hw; // slight elliptical path
	// Correct normals for the primary bend: x += f(y) -> n -= (0, f' * (dir.n), 0).
	float fprime = A * osc * 2.0 * hn / H;
	NORMAL = normalize(NORMAL - vec3(0.0, fprime * dot(dw, NORMAL), 0.0));

	if (wind_detail > 0.5) {
		// Branches: bend with distance from the trunk axis, lagging the trunk.
		float bph = ph + dot(rest.xz - origin.xz, vec2(0.6, 0.45)) + rest.y * 0.35;
		float b = s * branch_sway * max(plant_radius, 0.3) * 0.5 * flex * (pin_top ? 1.0 : hn);
		off += dw * b * (0.6 + 0.4 * sin(sp * 1.35 + bph));
		off.y += b * 0.3 * sin(sp * 1.7 + bph * 1.3);
		// Twigs / leaves: fast flutter along the normal, per-vertex phase, quicker in storms.
		float vph = hash12(rest.xz * 3.1 + rest.y * 1.7) * 6.2831853;
		float ff = (7.0 + 4.0 * storm) * (0.8 + 0.4 * hash12(origin.xz + 3.3));
		float fl = s * leaf_flutter * flex * flex * (0.35 + 0.25 * turbulence + 0.2 * storm);
		float w = sin(t * ff + vph) + 0.4 * sin(t * ff * 1.9 + vph * 2.0);
		off += NORMAL * fl * w * 0.5 + side * fl * 0.3 * cos(t * ff * 0.7 + vph);
		NORMAL = normalize(NORMAL + side * 0.25 * w * min(fl * 4.0, 1.0));
		// Player: push away, more at the flexible top / outer leaves.
		if (interact_strength > 0.0) {
			vec2 push = wind_player_push(rest);
			float pw = interact_strength * (pin_top ? hw : hn) * (0.45 + 0.55 * flex);
			off.xz += push * pw;
			off.y -= length(push) * pw * 0.35;
		}
	}
	// Storm safety: bounded displacement, never more than a fraction of the plant size.
	float maxo = 0.16 * H + 0.25;
	float lo = length(off.xz);
	if (lo > maxo) {
		off.xz *= maxo / lo;
	}
	// Keep the plant length roughly constant (bent tips drop slightly).
	off.y -= 0.5 * dot(off.xz, off.xz) / H * hw;
	VERTEX = rest + off;
}

void fragment() {
	vec4 a = texture(albedo_texture, UV);
	ALBEDO = a.rgb * albedo_tint.rgb;
	vec3 packed = texture(orm_texture, UV).rgb;
	ROUGHNESS = packed.g * roughness_factor;
	METALLIC = packed.b * metallic_factor;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
