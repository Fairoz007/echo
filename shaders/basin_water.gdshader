shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.035, 0.13, 0.15);
uniform vec3 crest_color : source_color = vec3(0.10, 0.26, 0.27);
uniform vec2 half_extent = vec2(40.0);
uniform float wave_amplitude : hint_range(0.0, 0.08) = 0.025;
varying vec2 surface_coord;
varying float crest;

void vertex() {
	surface_coord = VERTEX.xz;
	float a = dot(surface_coord, vec2(0.62, 0.31)) + TIME * 0.72;
	float b = dot(surface_coord, vec2(-0.38, 0.81)) - TIME * 0.49;
	VERTEX.y += wave_amplitude * (sin(a) + 0.45 * sin(b));
	crest = sin(a) * 0.5 + 0.5;
}

void fragment() {
	float a = dot(surface_coord, vec2(0.62, 0.31)) + TIME * 0.72;
	float b = dot(surface_coord, vec2(-0.38, 0.81)) - TIME * 0.49;
	float fine = dot(surface_coord, vec2(4.4, 2.7)) + TIME * 1.35;
	vec2 slope = wave_amplitude * (cos(a) * vec2(0.62, 0.31) + 0.45 * cos(b) * vec2(-0.38, 0.81));
	slope += 0.014 * cos(fine) * vec2(0.65, 0.4);
	NORMAL_MAP = vec3(-slope.x, slope.y, 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.75;
	float edge_distance = min(half_extent.x - abs(surface_coord.x), half_extent.y - abs(surface_coord.y));
	float edge = (1.0 - smoothstep(0.0, 0.45, edge_distance)) * (0.55 + 0.15 * sin(fine));
	ALBEDO = mix(deep_color, crest_color, crest * 0.35 + edge * 0.35);
	ROUGHNESS = 0.24;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ALPHA = 0.87;
}
