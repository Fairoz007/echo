shader_type spatial;
// Level B blended terrain. Vertex COLOR: r = path/soil mask, g = rock mask, b = wetness/mud, a = moss/leaf litter.
// Grass / soil / litter are procedural (no tiling texture repeats), the Tripo sediment and
// boulder textures only add high-frequency detail, so the ground never reads as a stamped tile.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.16, 0.24, 0.08);
uniform vec3 grass_b : source_color = vec3(0.26, 0.31, 0.11);
uniform vec3 soil_a : source_color = vec3(0.27, 0.20, 0.13);
uniform vec3 soil_b : source_color = vec3(0.36, 0.28, 0.19);
uniform vec3 litter : source_color = vec3(0.30, 0.22, 0.12);
uniform vec3 rock_tint : source_color = vec3(0.50, 0.47, 0.41);
uniform vec3 mud : source_color = vec3(0.12, 0.10, 0.07);
uniform float detail_scale = 0.32;
uniform float rock_scale = 0.12;
uniform float slope_rock_start = 0.30;
uniform float wet_global = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z);
	return texture(t, p.zy * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}

void fragment() {
	float n1 = fbm(wpos.xz * 0.045);
	float n2 = fbm(wpos.xz * 0.35 + 17.0);
	float n3 = fbm(wpos.xz * 1.7 + 3.0);
	vec3 det = texture(detail_tex, wpos.xz * detail_scale).rgb;
	float dl = clamp(dot(det, vec3(0.3333)) * 1.6 - 0.35, 0.0, 1.2);
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.3, 0.7, n1)) * (0.78 + 0.32 * n3);
	vec3 soil = mix(soil_a, soil_b, n2) * (0.65 + 0.45 * dl);
	float pm = smoothstep(0.38, 0.62, COLOR.r + (n2 - 0.5) * 0.55 + (n3 - 0.5) * 0.15);
	vec3 col = mix(grass, soil, pm);
	float lit = smoothstep(0.52, 0.72, n1 + COLOR.a * 0.4) * (1.0 - pm);
	col = mix(col, litter * (0.7 + 0.5 * n3), lit * 0.65);
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float rm = clamp(smoothstep(slope_rock_start, slope_rock_start + 0.22, slope + (n2 - 0.5) * 0.2) + COLOR.g, 0.0, 1.0);
	float rt = dot(triplanar(rock_tex, wpos, wnrm, rock_scale), vec3(0.333));
	// Sedimentary strata: horizontal bands warped by noise, cellular breakup on top.
	float strata = vnoise(vec2(wpos.y * 1.1 + n1 * 3.0, (wpos.x + wpos.z) * 0.04));
	float tone = clamp(strata * 0.7 + rt * 0.3, 0.0, 1.0);
	vec3 rc = mix(rock_tint * 0.32, rock_tint * 0.72, tone) * (0.85 + 0.3 * n3);
	rc = mix(rc, grass * 0.8, smoothstep(0.55, 0.8, n2) * wnrm.y * 0.6);
	col = mix(col, rc, rm);
	float wet = clamp(COLOR.b + wet_global, 0.0, 1.0);
	col = mix(col, col * 0.55, wet);
	col = mix(col, mud, wet * pm * 0.5);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.93, 0.85, rm), 0.35, wet);
	SPECULAR = 0.35;
	NORMAL_MAP = texture(detail_nrm, wpos.xz * detail_scale).rgb;
	NORMAL_MAP_DEPTH = mix(0.5, 1.1, max(pm, rm));
}
