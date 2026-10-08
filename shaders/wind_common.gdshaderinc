// Wind uniforms pushed every frame by systems/nature/WindSystem.gd.
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength = 1.0;
uniform float gust_amount = 0.6;
uniform float gust_frequency = 0.25;
uniform float wind_time = 0.0;

// Travelling gust front: 0..1, moves along the wind direction across the world.
float wind_gust(vec3 wp) {
	vec2 d = normalize(wind_direction + vec2(1e-5, 0.0));
	float front = dot(wp.xz, d) * 0.08 - wind_time * gust_frequency * 6.2831853 * 0.5;
	float g = 0.5 + 0.5 * sin(front) * 0.7 + 0.15 * sin(front * 2.7 + 1.3);
	return clamp(g, 0.0, 1.0);
}
