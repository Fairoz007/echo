// Wind uniforms pushed every frame by systems/nature/WindSystem.gd.
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength = 1.0;
uniform float gust_amount = 0.6;
uniform float gust_frequency = 0.25;
uniform float wind_time = 0.0;
// Integrated sway phase (speeds up with strength without phase jumps).
uniform float wind_phase = 0.0;
uniform float turbulence = 0.2;
uniform float storm_intensity = 0.0;
// 0 = primary sway only (ULTRA LOW), 1 = full, 2 = full + turbulence noise.
uniform float wind_detail = 1.0;
// Player interaction (WindSystem reads the "player" group node). Far away by default.
uniform vec3 player_position = vec3(0.0, -100000.0, 0.0);
uniform vec3 player_trail = vec3(0.0, -100000.0, 0.0);
uniform vec3 player_velocity = vec3(0.0);
uniform float interact_radius = 1.2;
uniform bool vegetation_interaction = true;

vec2 wind_dir2() {
	return normalize(wind_direction + vec2(1e-5, 0.0));
}

// Travelling gust front: 0..1, moves along the wind direction across the world.
float wind_gust(vec3 wp) {
	vec2 d = wind_dir2();
	float front = dot(wp.xz, d) * 0.08 - wind_time * gust_frequency * 6.2831853 * 0.5;
	float g = 0.5 + 0.5 * sin(front) * 0.7 + 0.15 * sin(front * 2.7 + 1.3);
	return clamp(g, 0.0, 1.0);
}

// Cheap 3-octave sine noise (-1..1) for turbulence, varies in space and time.
float wind_noise(vec3 wp, float t) {
	float n = sin(dot(wp.xz, vec2(0.71, 0.53)) + t * 1.7);
	n += 0.5 * sin(dot(wp.xz, vec2(-1.37, 1.11)) + t * 3.1 + 1.7);
	n += 0.25 * sin(dot(wp, vec3(2.3, 1.9, -2.7)) + t * 5.3 + 4.1);
	return n / 1.75;
}

// Effective wind magnitude at a point: base * gust * turbulence, storm-safe (bounded).
float wind_scalar(vec3 wp) {
	float g = wind_gust(wp);
	float s = wind_strength * (1.0 + gust_amount * (g * 2.0 - 0.6));
	if (wind_detail > 1.5) {
		s *= 1.0 + 0.35 * turbulence * wind_noise(wp * 0.35, wind_time);
	}
	return clamp(s, 0.0, 3.5);
}

// Horizontal push away from the player (and the lagged trail point), 0..1 length.
// Smooth falloff over interact_radius; the trail point makes bent foliage recover gradually.
vec2 wind_player_push(vec3 wp) {
	if (wind_detail < 0.5 || !vegetation_interaction) {
		return vec2(0.0);
	}
	vec2 acc = vec2(0.0);
	vec3 dv = wp - player_position;
	float dist = length(dv.xz);
	float fy = 1.0 - smoothstep(1.6, 2.4, abs(dv.y - 0.4));
	float f = (1.0 - smoothstep(0.0, interact_radius, dist)) * fy;
	acc += dv.xz / max(dist, 0.08) * f;
	// Moving through foliage also drags it along the velocity a little.
	acc += player_velocity.xz * 0.06 * f;
	vec3 dt = wp - player_trail;
	float dist2 = length(dt.xz);
	float f2 = (1.0 - smoothstep(0.0, interact_radius * 0.9, dist2)) * (1.0 - smoothstep(1.6, 2.4, abs(dt.y - 0.4)));
	acc += dt.xz / max(dist2, 0.08) * f2 * 0.7;
	float l = length(acc);
	return l > 1.0 ? acc / l : acc;
}
