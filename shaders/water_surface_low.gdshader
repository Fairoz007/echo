// Low-end water: no screen/depth textures, single normal layer, wave_count clamped
// by WaterBody (2 waves). Alpha-blended tint with Fresnel.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

#include "res://shaders/water_waves.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.16, 0.42, 0.40);
uniform vec3 deep_color : source_color = vec3(0.01, 0.06, 0.07);
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 normal_a_xform = vec4(0.12, 0.0, 0.03, 0.01);
uniform float normal_strength = 0.6;
uniform float roughness_base = 0.05;
uniform float specular_amount = 0.6;
uniform float fresnel_power = 5.0;
uniform float base_alpha = 0.82;

varying vec2 world_xz;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = wp.xz;
	vec2 g;
	VERTEX.y += wave_height(world_xz, g);
	NORMAL = normalize(vec3(-g.x, 1.0, -g.y));
}

void fragment() {
	float t = water_time;
	vec2 uva = world_xz * normal_a_xform.x + normal_a_xform.zw * t + flow_velocity * t * normal_a_xform.x;
	NORMAL_MAP = texture(normal_a, uva).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	float ndv = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, fresnel_power);
	ALBEDO = mix(deep_color, shallow_color, 0.35);
	ROUGHNESS = roughness_base;
	SPECULAR = specular_amount;
	ALPHA = mix(base_alpha, 1.0, fresnel);
}
