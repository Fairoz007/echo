// Shared wave function. MUST stay identical to WaterBody.gd::wave_height().
// waves[i] = (dir.x, dir.z, amplitude, wavelength). Phase speed from deep-water
// dispersion w = sqrt(g*k) scaled by wave_speed. Flow advects the pattern.
uniform vec4 waves[4];
uniform int wave_count = 4;
uniform float water_time = 0.0;
uniform vec2 flow_velocity = vec2(0.0);
uniform float wave_speed = 1.0;

float wave_height(vec2 p, out vec2 grad) {
	float h = 0.0;
	grad = vec2(0.0);
	vec2 q = p - flow_velocity * water_time;
	for (int i = 0; i < 4; i++) {
		if (i >= wave_count) break;
		vec4 w = waves[i];
		vec2 d = normalize(w.xy + vec2(1e-5, 0.0));
		float k = 6.2831853 / max(w.w, 0.01);
		float omega = sqrt(9.81 * k) * wave_speed;
		float ph = k * dot(d, q) - omega * water_time + float(i) * 1.7;
		h += w.z * sin(ph);
		grad += w.z * k * cos(ph) * d;
	}
	return h;
}
