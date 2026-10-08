shader_type spatial;
// Height-blended cave ground: sediment base, gravel, rock exposure, mud and wet puddles.
// Vertex colour: R = gravel, G = mud/wetness, B = puddle (standing water), A = rock exposure.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D sediment_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sediment_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 sediment_tint : source_color = vec3(0.42, 0.37, 0.30);
uniform vec3 gravel_tint : source_color = vec3(0.36, 0.34, 0.31);
uniform vec3 mud_tint : source_color = vec3(0.16, 0.12, 0.085);
uniform vec3 rock_tint : source_color = vec3(0.46, 0.43, 0.38);
uniform float tex_scale = 0.45;
uniform float vertex_color_mix = 1.0; // 0 for meshes without authored masks
uniform vec4 default_mask = vec4(0.35, 0.15, 0.0, 0.25);
uniform float puddle_enabled = 1.0; // set 0 when the water system supplies its own surface

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 vc = mix(default_mask, COLOR, vertex_color_mix);
	vec2 uv = wpos.xz * tex_scale;
	float n = texture(noise_tex, wpos.xz * 0.11).r;
	float nd = texture(noise_tex, wpos.xz * 1.9).r;
	vec3 sediment = sediment_tint * texture(sediment_tex, uv).rgb * 2.2;
	// Gravel: higher-frequency, higher-contrast speckle using the same source rotated.
	vec3 grav_src = texture(sediment_tex, uv.yx * 3.1 + 0.37).rgb;
	vec3 gravel = gravel_tint * (0.55 + grav_src * 1.2) * (0.7 + nd * 0.6);
	vec3 rock = rock_tint * texture(rock_tex, wpos.xz * 0.3).rgb * 2.0;
	// Height-aware blending: high spots of the noise win the transition.
	float h = n * 0.6 + nd * 0.4;
	float g = smoothstep(0.0, 0.25, vc.r + (h - 0.5) * 0.6);
	float r = smoothstep(0.0, 0.3, vc.a + (h - 0.5) * 0.5);
	float m = smoothstep(0.0, 0.35, vc.g - (h - 0.5) * 0.4);
	vec3 col = mix(sediment, gravel, g);
	col = mix(col, rock, r);
	col = mix(col, mud_tint * (0.8 + nd * 0.4), m);
	float wet = clamp(m * 0.8 + vc.b, 0.0, 1.0);
	float puddle = smoothstep(0.35, 0.6, vc.b - (nd - 0.5) * 0.25) * puddle_enabled;
	col *= mix(1.0, 0.6, wet);
	col = mix(col, vec3(0.025, 0.028, 0.03), puddle * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.45, wet), 0.04, puddle);
	SPECULAR = mix(0.4, 0.75, max(wet, puddle));
	NORMAL_MAP = mix(texture(sediment_normal, uv + vec2(g * 0.31)).rgb, vec3(0.5, 0.5, 1.0), puddle);
	NORMAL_MAP_DEPTH = mix(1.3, 0.0, puddle);
}
