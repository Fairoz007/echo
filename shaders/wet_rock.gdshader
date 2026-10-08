// Wet rock: triplanar procedural (or textured) rock with darkened albedo, low
// roughness, and animated running-water sheen on steep faces. Assign to rocks
// next to waterfalls/streams. `wetness` 0 = dry, 1 = soaked.
shader_type spatial;
render_mode world_vertex_coords;
uniform sampler2D rock_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
uniform vec3 rock_color : source_color = vec3(0.32, 0.30, 0.27);
uniform float tri_scale = 0.35;
uniform float wetness : hint_range(0.0, 1.0) = 0.85;
uniform float flow_speed = 0.6;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = VERTEX; wn = NORMAL; }
vec3 tri(sampler2D s, vec3 p, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0)); b /= dot(b, vec3(1.0));
	return texture(s, p.yz).rgb * b.x + texture(s, p.xz).rgb * b.y + texture(s, p.xy).rgb * b.z;
}
void fragment() {
	vec3 base;
	if (use_albedo_texture) base = tri(albedo_texture, wp * tri_scale, wn);
	else {
		float n = tri(rock_noise, wp * tri_scale, wn).r;
		float n2 = tri(rock_noise, wp * tri_scale * 4.0, wn).r;
		base = rock_color * (0.8 + 0.3 * n) * (0.9 + 0.2 * n2);
	}
	float steep = 1.0 - abs(wn.y);
	float sheen = texture(rock_noise, vec2(wp.x + wp.z, wp.y * 0.5 + TIME * flow_speed) * 0.8).r;
	float film = wetness * mix(0.6, 1.0, smoothstep(0.4, 0.7, sheen) * steep);
	ALBEDO = base * mix(1.0, 0.45, wetness);
	ROUGHNESS = mix(0.85, 0.12, film);
	SPECULAR = mix(0.4, 0.7, wetness);
}
