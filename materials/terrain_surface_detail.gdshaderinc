// Shared world-metre surface detail. No geometry changes or additional texture reads.
global uniform float terrain_detail;

float terrain_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Value noise with its analytic gradient: XYZ = d(value)/d(p), W = value.
// Analytic slopes avoid the extra texture/noise evaluations of finite differences.
vec4 terrain_noise_gradient(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	vec3 du = 6.0 * f * (1.0 - f);
	float a = terrain_hash(cell);
	float b = terrain_hash(cell + vec3(1.0, 0.0, 0.0));
	float c = terrain_hash(cell + vec3(0.0, 1.0, 0.0));
	float d = terrain_hash(cell + vec3(1.0, 1.0, 0.0));
	float e = terrain_hash(cell + vec3(0.0, 0.0, 1.0));
	float f1 = terrain_hash(cell + vec3(1.0, 0.0, 1.0));
	float g = terrain_hash(cell + vec3(0.0, 1.0, 1.0));
	float h = terrain_hash(cell + vec3(1.0, 1.0, 1.0));
	float z0 = mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
	float z1 = mix(mix(e, f1, u.x), mix(g, h, u.x), u.y);
	float dx = mix(mix(b - a, d - c, u.y), mix(f1 - e, h - g, u.y), u.z);
	float dy = mix(mix(c - a, d - b, u.x), mix(g - e, h - f1, u.x), u.z);
	return vec4(vec3(dx, dy, z1 - z0) * du, mix(z0, z1, u.z));
}

float terrain_band_fade(float footprint, float frequency, float camera_distance, float range_end) {
	// Suppress a band before its cells become smaller than a few pixels.
	return (1.0 - smoothstep(0.12, 0.45, footprint * frequency))
		* (1.0 - smoothstep(range_end * 0.45, range_end, camera_distance));
}

// Outputs: world-space height slope; (albedo multiplier, roughness delta, cavity AO).
// Frequencies correspond to weathering, centimetre gravel and millimetre soil grain.
void terrain_surface_detail(vec3 p, vec3 n, float camera_distance, float gravel,
		float rock, float organic, float wetness, out vec3 slope, out vec3 variation) {
	float quality = clamp(terrain_detail, 0.0, 1.0);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float coarse_fade = terrain_band_fade(footprint, 3.2, camera_distance, 70.0);
	float pebble_fade = terrain_band_fade(footprint, 12.0, camera_distance, 32.0);
	float grain_fade = terrain_band_fade(footprint, 85.0, camera_distance, 10.0);
	if (quality <= 0.0 || max(coarse_fade, max(pebble_fade, grain_fade)) < 0.0001) {
		slope = vec3(0.0);
		variation = vec3(1.0, 0.0, 1.0);
		return;
	}
	vec4 weather = terrain_noise_gradient(p * 3.2 + vec3(4.1, 9.2, 1.7));
	vec4 pebbles = terrain_noise_gradient(p * 12.0 + vec3(11.3, 2.7, 5.4));
	vec4 grain = terrain_noise_gradient(p * 85.0 + vec3(2.2, 7.3, 13.1));
	// Flatten the gaps between rounded gravel crowns; differentiate the shaping too.
	float crown_t = clamp((pebbles.w - 0.28) / 0.5, 0.0, 1.0);
	float crown = crown_t * crown_t * (3.0 - 2.0 * crown_t);
	float crown_derivative = 6.0 * crown_t * (1.0 - crown_t) / 0.5;
	float pebble_strength = mix(0.0025, 0.011, clamp(gravel, 0.0, 1.0));
	float grain_strength = mix(0.0011, 0.0004, clamp(rock + organic * 0.5, 0.0, 1.0));
	slope = weather.xyz * 3.2 * mix(0.006, 0.027, rock) * coarse_fade;
	slope += pebbles.xyz * crown_derivative * 12.0 * pebble_strength * pebble_fade;
	slope += grain.xyz * 85.0 * grain_strength * grain_fade;
	// Project a height gradient onto the actual surface: no axis seams or UV tangents.
	slope -= n * dot(n, slope);
	slope *= quality * mix(1.0, 0.3, wetness) * mix(1.0, 0.7, organic);
	float weather_tone = (weather.w - 0.5) * coarse_fade;
	float pebble_tone = (crown - 0.5) * pebble_fade * gravel;
	float grain_tone = (grain.w - 0.5) * grain_fade;
	variation.x = 1.0 + quality * (weather_tone * 0.18 + pebble_tone * 0.2 + grain_tone * 0.1);
	variation.y = quality * (weather_tone * 0.08 - pebble_tone * 0.1 + grain_tone * 0.04);
	variation.z = 1.0 - quality * (1.0 - crown) * pebble_fade * gravel * 0.14;
}

vec3 terrain_detail_normal(vec3 n, vec3 slope) {
	return normalize(n - slope);
}
