// Falling water sheet. Mesh: PlaneMesh (FACE_Z) whose UV.y=0 at the lip, 1 at impact.
// Vertex arcs the sheet ballistically (x out = v0 * t, drop = 0.5 g t^2 normalized).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D streak_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_noise : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float fall_height = 6.0;
uniform float throw_distance = 0.8;
uniform float speed = 1.2;
uniform vec3 water_color : source_color = vec3(0.32, 0.50, 0.50);
uniform vec3 foam_color : source_color = vec3(0.88, 0.93, 0.93);
uniform float time_offset = 0.0;
uniform float edge_softness = 0.12;

varying float fall;

void vertex() {
	fall = UV.y;
	// Ballistic profile: horizontal travel ~ sqrt(drop).
	float out_z = throw_distance * sqrt(fall);
	VERTEX.z += out_z;
	VERTEX.x *= 1.0 + fall * 0.15; // sheet spreads slightly as it falls
	VERTEX.x += sin(UV.y * 9.0 + TIME * 3.0) * 0.03 * fall;
}

void fragment() {
	float t = TIME + time_offset;
	// Velocity grows with sqrt(fall): integrate as UV warp so streaks stretch downward.
	float v = sqrt(fall);
	vec2 uv1 = vec2(UV.x * 3.0, v * 2.0 - t * speed);
	vec2 uv2 = vec2(UV.x * 7.0 + 0.37, v * 3.5 - t * speed * 1.35);
	float s1 = texture(streak_noise, vec2(uv1.x, uv1.y * 0.25)).r;
	float s2 = texture(streak_noise, vec2(uv2.x, uv2.y * 0.25)).r;
	float streak = s1 * 0.6 + s2 * 0.6;
	float aer = smoothstep(0.25, 1.0, fall) * 0.7 + smoothstep(0.55, 0.8, streak) * 0.5;
	aer = clamp(aer, 0.0, 1.0);
	vec3 n = texture(normal_noise, uv2 * 0.5).rgb;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 0.8;
	ALBEDO = mix(water_color, foam_color, aer);
	ROUGHNESS = mix(0.08, 0.6, aer);
	SPECULAR = 0.6;
	float edge = smoothstep(0.0, edge_softness, UV.x) * smoothstep(0.0, edge_softness, 1.0 - UV.x);
	float breakup = smoothstep(0.15, 0.55, streak + (1.0 - fall) * 0.5);
	ALPHA = clamp(edge * mix(0.55, 0.95, aer) * breakup * smoothstep(0.0, 0.03, fall + 0.01), 0.0, 1.0);
}
