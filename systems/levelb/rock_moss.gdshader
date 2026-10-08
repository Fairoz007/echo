shader_type spatial;
// Re-grades a Tripo rock (its own UV atlas texture) with world-space tint breakup and
// moss on upward faces, so repeated instances of the same rock never read as copies.
// Optional wet band below `wet_line` (world Y) for drained water levels.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform vec3 tint : source_color = vec3(0.62, 0.61, 0.56);
uniform vec3 tint_b : source_color = vec3(0.45, 0.43, 0.38);
uniform vec3 moss : source_color = vec3(0.17, 0.24, 0.08);
uniform float moss_amount = 0.55;
uniform float desaturate = 0.6;
uniform float wetness = 0.0;
uniform float wet_line = -1000.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 a = texture(rock_tex, UV).rgb;
	float l = dot(a, vec3(0.333));
	a = mix(a, vec3(l), desaturate);
	float big = vnoise(wpos.xz * 0.04 + wpos.y * 0.025);
	float mid = vnoise(wpos.xy * 0.35 + wpos.zx * 0.27);
	vec3 base = a * mix(tint, tint_b, big) * 1.35 * (0.85 + 0.3 * mid);
	float up = smoothstep(0.35, 0.85, wnrm.y + (mid - 0.5) * 0.6);
	float streak = smoothstep(0.55, 0.8, vnoise(vec2(wpos.x * 0.6 + wpos.z * 0.6, wpos.y * 0.05)));
	float m = clamp(up * moss_amount * (0.6 + big) + streak * moss_amount * 0.25, 0.0, 1.0);
	vec3 col = mix(base, moss * (0.7 + 0.6 * mid), m);
	// Darker grime in crevices (low-luminance areas of the source texture).
	col *= mix(0.6, 1.0, smoothstep(0.15, 0.55, l));
	float wet = clamp(wetness + step(wpos.y, wet_line) * 0.85, 0.0, 1.0);
	col *= mix(1.0, 0.5, wet);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.88, 0.95, m), 0.22, wet);
	SPECULAR = 0.4;
	if (has_normal) {
		NORMAL_MAP = texture(rock_nrm, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	}
}
