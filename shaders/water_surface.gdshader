// High-quality water: Gerstner-free sine-sum vertex waves (height matches
// WaterBody.get_surface_height exactly), 2 scrolling normal layers, Fresnel,
// depth absorption, screen refraction, shoreline foam, roughness variation.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

#include "res://shaders/water_waves.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.16, 0.42, 0.40);
uniform vec3 deep_color : source_color = vec3(0.01, 0.06, 0.07);
uniform vec3 absorption = vec3(0.45, 0.16, 0.12); // per-meter extinction (red dies first)
uniform float clarity : hint_range(0.0, 1.0) = 0.8;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.04;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 normal_a_xform = vec4(0.12, 0.0, 0.03, 0.01);  // (scale, unused, scroll.x, scroll.y)
uniform vec4 normal_b_xform = vec4(0.31, 0.0, -0.02, 0.035);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.05;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.08;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.6;
uniform float fresnel_power = 5.0;
uniform vec3 foam_color : source_color = vec3(0.85, 0.9, 0.88);
uniform float foam_width = 0.6;
uniform float foam_amount : hint_range(0.0, 2.0) = 0.7;
uniform float crest_foam : hint_range(0.0, 2.0) = 0.0;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform float edge_fade = 0.15;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

varying vec2 world_xz;
varying float wave_h;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = wp.xz;
	vec2 g;
	float h = wave_height(world_xz, g);
	wave_h = h;
	VERTEX.y += h;
	NORMAL = normalize(vec3(-g.x, 1.0, -g.y));
	TANGENT = normalize(vec3(1.0, g.x, 0.0));
	BINORMAL = normalize(vec3(0.0, g.y, 1.0));
}

float scene_view_z(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return v.z / v.w;
}

void fragment() {
	float t = water_time;
	vec2 uva = world_xz * normal_a_xform.x + normal_a_xform.zw * t + flow_velocity * t * normal_a_xform.x;
	vec2 uvb = world_xz * normal_b_xform.x + normal_b_xform.zw * t + flow_velocity * t * normal_b_xform.x * 1.3;
	vec3 na = texture(normal_a, uva).rgb * 2.0 - 1.0;
	vec3 nb = texture(normal_b, uvb).rgb * 2.0 - 1.0;
	vec3 nm = normalize(vec3(na.xy + nb.xy, na.z * nb.z));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	// Thickness of water along view ray (view-space).
	float surface_z = VERTEX.z;
	float thickness = max(surface_z - scene_view_z(SCREEN_UV, INV_PROJECTION_MATRIX), 0.0);
	vec2 offset = nm.xy * refraction_strength * clamp(thickness, 0.0, 1.0);
	vec2 ruv = SCREEN_UV + offset;
	float r_thick = surface_z - scene_view_z(ruv, INV_PROJECTION_MATRIX);
	if (r_thick < 0.0) { ruv = SCREEN_UV; r_thick = thickness; }
	r_thick = max(r_thick, 0.0);

	vec3 behind = textureLod(screen_tex, ruv, 0.0).rgb;
	// Beer-Lambert: per-channel transmittance; in-scattered colour fills the rest.
	vec3 trans = exp(-absorption * r_thick / max(clarity, 0.05));
	float lum_t = dot(trans, vec3(0.333));
	vec3 scatter = mix(deep_color, shallow_color * 0.55, lum_t);
	vec3 seen = behind * trans + scatter * (1.0 - trans);

	float ndv = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, fresnel_power);
	if (!FRONT_FACING) { fresnel = 0.0; }

	float fn = texture(foam_noise, world_xz * 0.35 + flow_velocity * t * 0.35).r;
	float fn2 = texture(foam_noise, world_xz * 0.9 - vec2(0.02, 0.03) * t).r;
	float shore = 1.0 - smoothstep(0.0, foam_width, thickness);
	float foam = clamp(shore * smoothstep(0.35, 0.75, fn * 0.6 + fn2 * 0.6 + shore * 0.4) * foam_amount, 0.0, 1.0);
	// Crest foam: only where waves are high AND noise breaks up (avoids a regular grid).
	float crest = smoothstep(0.6, 1.0, wave_h * 6.0 + fn * 0.8 - 0.2) * smoothstep(0.55, 0.8, fn2);
	foam += clamp(crest_foam * crest, 0.0, 1.0);
	foam = clamp(foam, 0.0, 1.0);

	EMISSION = seen * (1.0 - fresnel) * (1.0 - foam);
	ALBEDO = mix(deep_color * 0.25, foam_color, foam);
	ROUGHNESS = mix(roughness_base + roughness_variation * fn, 0.8, foam);
	SPECULAR = specular_amount;
	METALLIC = 0.0;
	ALPHA = clamp(smoothstep(0.0, edge_fade, thickness) + foam, 0.0, 1.0);
}
