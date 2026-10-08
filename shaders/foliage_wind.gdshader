// PBR foliage with tiered wind response (keeps the original Tripo texture inputs).
//   trunk_bend   : whole-plant lean, weighted by height^2 (trees: tiny, grass: n/a)
//   branch_sway  : grows with distance from the trunk axis (branches/canopy)
//   leaf_flutter : high-frequency jitter at the outer canopy
// Rocks: do not use this shader (zero motion).
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
uniform float root_height = 0.0;
uniform float plant_height = 10.0;
uniform float plant_radius = 3.0;
uniform float wind_scale = 0.1; // legacy "wind_strength" multiplier per plant
uniform float trunk_bend = 0.25;
uniform float branch_sway = 1.0;
uniform float leaf_flutter = 0.35;

void vertex() {
	vec3 origin = NODE_POSITION_WORLD;
	float h = clamp((VERTEX.y - root_height) / max(plant_height, 0.1), 0.0, 1.0);
	float radial = clamp(length(VERTEX.xz - origin.xz) / max(plant_radius, 0.1), 0.0, 1.0);
	vec2 d = normalize(wind_direction + vec2(1e-5, 0.0));
	float gust = wind_gust(origin);
	float s = wind_strength * wind_scale * (1.0 + gust_amount * (gust * 2.0 - 0.6));
	float t = wind_time;
	float phase = dot(origin.xz, vec2(0.37, 0.21));
	float trunk = trunk_bend * h * h * (0.7 + 0.3 * sin(t * 0.6 + phase));
	float branch = branch_sway * radial * h * (0.6 + 0.4 * sin(t * 1.3 + phase + VERTEX.y * 0.4));
	float flutter = leaf_flutter * radial * sin(t * 6.0 + dot(VERTEX, vec3(2.1, 1.7, 2.9)));
	VERTEX.xz += d * s * (trunk + branch);
	VERTEX.xyz += vec3(d.y, 0.5, -d.x) * s * flutter * 0.4;
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
