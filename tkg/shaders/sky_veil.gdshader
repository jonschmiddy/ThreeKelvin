shader_type canvas_item;
render_mode unshaded, blend_add;

// A VEIL OF NEARER GAS, in front of the far nebula and sliding faster than it
// when the map pans (Jon: "can we have more layers for the background
// parallax"): faint wisps in the system's own two nebula colours, worked out
// in 2x2 blocks and added over the sky before the palette pass sets them to the
// system's colours. Faint on purpose: it is depth, not a second nebula.

uniform vec2 off = vec2(0.0);
uniform vec3 pal0 = vec3(0.15, 0.6, 0.72);
uniform vec3 pal1 = vec3(0.82, 0.24, 0.55);
uniform float sd = 0.0;
uniform float strength = 0.07;

float hash2(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i), b = hash2(i + vec2(1.0, 0.0)), c = hash2(i + vec2(0.0, 1.0)), d = hash2(i + vec2(1.0, 1.0));
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}
float fbm2(vec2 p, int o) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < o; i++) { s += a * noise2(p); n += a; p *= 2.03; a *= 0.5; }
	return s / n;
}
float smooth_k(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = floor((px - off) / 2.0) * 2.0;
	float w = fbm2(vec2(b.x * 0.0042 + sd, b.y * 0.0065 - sd * 0.7), 4);
	float wisp = smooth_k(0.56, 0.78, w);
	float strand = 1.0 - abs(2.0 * fbm2(vec2(b.x * 0.012 - sd, b.y * 0.017 + sd), 3) - 1.0);
	float I = wisp * (0.45 + 0.55 * strand * strand) * strength;
	vec3 c = mix(pal0, pal1, fbm2(vec2(b.x * 0.0021 - sd, b.y * 0.003 + sd), 2)) * I;
	COLOR = vec4(c, 1.0);
}
