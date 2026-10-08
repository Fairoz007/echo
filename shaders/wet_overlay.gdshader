// material_overlay applied by WaterBody to "wettable" meshes after draining.
// Multiplies the lit result darker between the old water line and current one,
// receding downward as the surface dries (with drip streaks).
shader_type spatial;
render_mode blend_mul, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform float wet_top = 0.0;
uniform float water_line = -1000.0;
uniform float dry_start_time = 0.0;
uniform float dry_duration = 25.0;
uniform float now = 0.0;
uniform vec4 wet_bounds = vec4(-1e6, -1e6, 1e6, 1e6); // xmin, zmin, xmax, zmax (world)
uniform float darkness : hint_range(0.0, 1.0) = 0.6;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float f = clamp((now - dry_start_time) / max(dry_duration, 0.01), 0.0, 1.0);
	float top = mix(wet_top, water_line, f * f);
	// Drip streaks: columns that stay wet a little longer below the receding top.
	float col = floor((wpos.x + wpos.z) * 6.0);
	float streak = hash(col) * 0.35 * (1.0 - f);
	float wet = 1.0 - smoothstep(top - 0.06, top + 0.02 + streak, wpos.y);
	wet *= 1.0 - f * 0.6;
	vec2 inb = step(wet_bounds.xy, wpos.xz) * step(wpos.xz, wet_bounds.zw);
	wet *= inb.x * inb.y;
	ALBEDO = vec3(1.0 - darkness * wet);
}
