shader_type spatial;
// Triplanar limestone for procedural cave shells and rocks (Compatibility-safe).
// Vertex colour: R = cavity/fracture darkening, G = wetness, B = Vaelor vein mask.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.32;
uniform float detail_scale = 1.4;
uniform vec3 limestone_light : source_color = vec3(0.50, 0.46, 0.40);
uniform vec3 limestone_dark : source_color = vec3(0.27, 0.245, 0.21);
uniform vec3 stain_color : source_color = vec3(0.13, 0.10, 0.075);
uniform vec3 vaelor_color : source_color = vec3(0.25, 0.85, 0.95);
uniform float vaelor_strength = 2.6;
uniform float albedo_tex_mix = 0.5;
uniform float strata_freq = 0.85;
uniform float normal_depth = 1.1;
uniform float vertex_color_mix = 1.0; // 0 for meshes without authored vertex colour (CSG, primitives)
uniform vec4 default_mask = vec4(0.2, 0.25, 0.0, 1.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void fragment() {
	vec4 vc = mix(default_mask, COLOR, vertex_color_mix);
	vec3 w = pow(abs(wnorm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float n_large = tri(noise_tex, wpos * 0.09, w).r;
	float n_detail = tri(noise_tex, wpos * detail_scale, w).r;
	vec3 tex = tri(albedo_tex, wpos * tex_scale, w).rgb;
	// Limestone bedding: thin darker partings between thicker beds.
	float bed = fract(wpos.y * strata_freq + n_large * 1.4);
	float parting = smoothstep(0.0, 0.06, bed) * smoothstep(0.16, 0.08, bed);
	vec3 base = mix(limestone_dark, limestone_light, clamp(n_large * 1.5 - 0.25, 0.0, 1.0));
	base = mix(base, base * tex * 2.1, albedo_tex_mix);
	base *= 0.78 + n_detail * 0.44;
	base = mix(base, stain_color, parting * 0.55);
	float cavity = vc.r;
	base = mix(base, stain_color * 0.6, clamp(cavity, 0.0, 1.0) * 0.75);
	// Vertical drip/flowstone streaks on walls, calcite highlight on some.
	float streak = smoothstep(0.62, 0.88, texture(noise_tex, vec2((wpos.x + wpos.z) * 0.55, wpos.y * 0.04)).r);
	float wall_mask = 1.0 - w.y;
	base = mix(base, base * 0.6 + stain_color * 0.4, streak * 0.45 * wall_mask);
	float calcite = smoothstep(0.78, 0.92, texture(noise_tex, vec2((wpos.x - wpos.z) * 0.35, wpos.y * 0.03 + 0.5)).r) * wall_mask;
	base = mix(base, vec3(0.62, 0.6, 0.55), calcite * 0.35);
	float wet = clamp(vc.g + streak * 0.35 * wall_mask, 0.0, 1.0);
	ALBEDO = base * mix(1.0, 0.55, wet);
	ROUGHNESS = mix(0.93, 0.28, wet);
	SPECULAR = mix(0.35, 0.6, wet);
	NORMAL_MAP = tri(normal_tex, wpos * detail_scale * 0.45, w).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	// Continuous mineral veins: iso-line of low-frequency noise, anti-aliased with fwidth,
	// kept sparse by a large-scale mask so they read as a few long seams, not speckle.
	float vn = tri(noise_tex, wpos * 0.11, w).r;
	float aa = fwidth(vn) * 1.5 + 0.004;
	float line_v = 1.0 - smoothstep(0.0, aa + 0.012, abs(vn - 0.5));
	float sparse = smoothstep(0.45, 0.6, tri(noise_tex, wpos * 0.035 + vec3(7.0), w).r);
	line_v *= 1.0 - smoothstep(0.015, 0.05, fwidth(vn)); // fade distant aliasing instead of blotches
	float vein = vc.b * line_v * sparse;
	EMISSION = vaelor_color * vein * vaelor_strength;
}
