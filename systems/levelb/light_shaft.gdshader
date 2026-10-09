shader_type spatial;
// Soft volumetric light shaft for Level B: additive, fades at the silhouette (view-facing
// falloff) and along its length, with slow drifting noise so it never reads as a flat card.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(0.55, 0.75, 0.85);
uniform float intensity = 0.14;
varying vec3 wpos;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), u.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), u.x), u.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float facing = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float drift = 0.65 + 0.35 * n2(vec2(wpos.x * 0.6 + TIME * 0.15, wpos.y * 0.25 - TIME * 0.08));
	ALBEDO = color * intensity * facing * along * drift;
}