shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://materials/terrain_surface_detail.gdshaderinc"

// Imported sediment keeps its own UV atlas. Only added mineral/grain detail is
// world-scaled, so scaling a room floor does not enlarge that fine relief.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool has_roughness = false;
uniform bool has_metallic = false;
uniform bool has_ao = false;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_amount = 1.0;
uniform float metallic_amount = 0.0;
uniform float specular_amount = 0.5;
uniform float ao_light_affect = 0.0;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	vec3 base_color = albedo_tint.rgb;
	if (has_albedo) { base_color *= texture(albedo_tex, UV).rgb; }
	float roughness = roughness_amount;
	if (has_roughness) { roughness *= dot(texture(roughness_tex, UV), roughness_channel); }
	float metallic = metallic_amount;
	if (has_metallic) { metallic *= dot(texture(metallic_tex, UV), metallic_channel); }
	float occlusion = 1.0;
	if (has_ao) { occlusion = dot(texture(ao_tex, UV), ao_channel); }
	vec3 surface_normal = normalize(NORMAL);
	if (has_normal) {
		vec2 xy = texture(normal_tex, UV).rg * 2.0 - 1.0;
		float z = sqrt(max(1.0 - dot(xy, xy), 0.0001));
		surface_normal = normalize(TANGENT * xy.x * normal_strength + BINORMAL * xy.y * normal_strength + NORMAL * z);
	}
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(surface_normal, 0.0)).xyz);
	vec3 slope;
	vec3 variation;
	terrain_surface_detail(world_position, world_normal, length(CAMERA_POSITION_WORLD - world_position), 0.6, 0.25, 0.0, 0.0, slope, variation);
	ALBEDO = base_color * variation.x;
	ROUGHNESS = clamp(roughness + variation.y, 0.05, 1.0);
	METALLIC = clamp(metallic, 0.0, 1.0);
	SPECULAR = specular_amount;
	AO = clamp(occlusion * variation.z, 0.0, 1.0);
	AO_LIGHT_AFFECT = ao_light_affect;
	NORMAL = normalize((VIEW_MATRIX * vec4(terrain_detail_normal(world_normal, slope), 0.0)).xyz);
}
