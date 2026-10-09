// MultiMesh grass: strong height-weighted sway, per-instance phase and tint
// (INSTANCE_CUSTOM.r = phase, .g = tint mix, .b = stiffness). Vertex color.r = blade height 0..1.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
#include "res://shaders/wind_common.gdshaderinc"
uniform vec3 base_color : source_color = vec3(0.13, 0.20, 0.07);
uniform vec3 tip_color : source_color = vec3(0.45, 0.56, 0.22);
uniform vec3 dry_tip_color : source_color = vec3(0.55, 0.50, 0.28);
uniform float sway = 0.45;
varying float hgt;
varying float tint;

void vertex() {
	hgt = COLOR.r;
	tint = INSTANCE_CUSTOM.g;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 d = wind_dir2();
	float ph = INSTANCE_CUSTOM.r * 6.2831853;
	float stiff = mix(0.6, 1.2, INSTANCE_CUSTOM.b);
	float ws = wind_scalar(root);
	float s = sway / stiff * (0.35 * wind_strength + 0.65 * ws + 0.25 * wind_strength * sin(wind_phase * 2.3 + ph));
	float bend = hgt * hgt;
	vec3 offset_w = vec3(d.x, 0.0, d.y) * s * bend;
	if (wind_detail > 0.5) {
		// Blade flutter (faster and wider in storms) and player push-away.
		float ff = 4.0 + 3.0 * storm_intensity;
		offset_w += vec3(d.y, 0.0, -d.x) * (0.06 + 0.05 * turbulence) * sin(wind_time * ff + ph * 3.0) * bend * wind_strength;
		vec2 push = wind_player_push(root);
		offset_w.xz += push * 0.55 * bend / stiff;
	}
	// Storm safety: blades lie over at most ~70% of their height.
	float lo = length(offset_w.xz);
	float maxo = 0.42 * max(length((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.1);
	if (lo > maxo) { offset_w.xz *= maxo / lo; }
	offset_w.y = -0.45 * length(offset_w.xz) * bend; // keep blade length roughly constant
	// world offset -> local (MultiMesh instance has uniform scale)
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_w, 0.0)).xyz;
	// Up-biased normals: grass cards lit like a canopy instead of flat cards (no black backfaces).
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}

void fragment() {
	// Compatibility flips NORMAL on back faces (blades seen back-on render black): light as canopy.
	NORMAL = normalize(mat3(VIEW_MATRIX) * vec3(0.0, 1.0, 0.0));
	vec3 tip = mix(tip_color, dry_tip_color, tint);
	ALBEDO = mix(base_color, tip, smoothstep(0.0, 1.0, hgt));
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.25, 0.3, 0.1) * hgt;
	AO = mix(0.65, 1.0, hgt);
	AO_LIGHT_AFFECT = 0.6;
}
