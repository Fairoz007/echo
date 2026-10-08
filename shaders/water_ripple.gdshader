// Expanding ring ripple quad; `age` 0..1 driven by vfx/Splash.gd.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float age = 0.0;
uniform float intensity = 1.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring_r = mix(0.1, 0.95, sqrt(age));
	float ring = exp(-pow((r - ring_r) / 0.05, 2.0));
	float inner = exp(-pow((r - ring_r * 0.6) / 0.04, 2.0)) * 0.5;
	ALBEDO = vec3(0.7, 0.8, 0.8) * (ring + inner) * (1.0 - age) * 0.35 * intensity;
}
