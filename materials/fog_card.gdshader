shader_type spatial;
// Cheap layered mist card for the Compatibility renderer (stands in for volumetric fog).
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.35, 0.42, 0.48);
uniform float density = 0.08;
uniform vec2 drift = vec2(0.015, 0.004);

void fragment() {
	vec2 uv = UV;
	float n = texture(noise_tex, uv * 1.3 + TIME * drift).r * texture(noise_tex, uv * 0.6 - TIME * drift * 0.7).r;
	float edge = smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x) * smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.6, uv.y);
	float view_fade = clamp((-VERTEX.z - 1.0) / 4.0, 0.0, 1.0);
	ALBEDO = tint * n * edge * density * view_fade * 4.0;
}
