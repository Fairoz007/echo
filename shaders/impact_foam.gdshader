// Churning foam disc at a waterfall impact (horizontal quad, UV centered).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 foam_color : source_color = vec3(0.9, 0.94, 0.94);
uniform float churn_speed = 0.35;
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float ang = atan(c.y, c.x);
	vec2 polar = vec2(ang / 6.2831853 * 3.0, r - TIME * churn_speed);
	float n1 = texture(foam_noise, polar).r;
	float n2 = texture(foam_noise, c * 1.7 + vec2(TIME * 0.05, -TIME * 0.07)).r;
	float body = 1.0 - smoothstep(0.2, 1.0, r);
	float f = smoothstep(0.35, 0.7, n1 * 0.6 + n2 * 0.6 + body * 0.5) * body;
	ALBEDO = foam_color;
	ROUGHNESS = 0.7;
	ALPHA = clamp(f * 1.2, 0.0, 0.95);
}
