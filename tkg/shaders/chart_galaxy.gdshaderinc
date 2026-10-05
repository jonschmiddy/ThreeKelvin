// THE GALAXY'S OWN ARITHMETIC, shared by every pass of the star chart's sky
// (`ChartSky.gd`): the bake, the per-frame field, the stars, the hole and the
// palette. The mockup Jon picked (round three, 2x2) is the reference for every
// number in here; the hash is the sector map's, bit for bit.

const float TILT = 0.38;
const float SIN_I = 0.92487837;
const float TAU_G = 6.28318531;
const vec3 VOID_C = vec3(7.0, 10.0, 18.0);

// The sector map's hash: two 32-bit multiplies, two folds, out in [0, 1).
float g_hash(int x, int y) {
	uint h = (uint(x) * 374761393u) ^ (uint(y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h) / 4294967296.0;
}

float g_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	int ix = int(i.x), iy = int(i.y);
	float a = g_hash(ix, iy), b = g_hash(ix + 1, iy);
	float c = g_hash(ix, iy + 1), d = g_hash(ix + 1, iy + 1);
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

// Octaves may be fractional: the last one fades in, so a zoom that adds
// detail adds it smoothly rather than in a step.
float g_fbm(vec2 p, float o) {
	float a = 0.5, s = 0.0, n = 0.0;
	int whole = int(floor(o));
	for (int i = 0; i < 9; i++) {
		if (i >= whole) {
			break;
		}
		s += a * g_noise(p);
		n += a;
		p *= 2.03;
		a *= 0.5;
	}
	float fr = o - float(whole);
	if (fr > 0.001 && whole < 9) {
		s += a * fr * g_noise(p);
		n += a * fr;
	}
	return s / n;
}

float g_sm(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float g_lum(vec3 c) {
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
}

float g_tone1(float x) {
	return x <= 0.0 ? 0.0 : 1.0 - exp(-min(x, 10.0));
}

// Light to the screen: half of it keeping the hue, half per channel, so a
// bright arm whitens without the core turning grey.
vec3 g_tone(vec3 c) {
	float l = g_lum(c);
	float s = l > 1e-6 ? g_tone1(l) / l : 0.0;
	vec3 h = min(c * s, vec3(1.0));
	vec3 t = h * 0.6 + vec3(g_tone1(c.r), g_tone1(c.g), g_tone1(c.b)) * 0.4;
	// to the screen's 0-255, over the void
	return (VOID_C + (255.0 - VOID_C) * t) / 255.0;
}

float g_bayer(ivec2 q) {
	int i = (q.y & 3) * 4 + (q.x & 3);
	int b[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(b[i]);
}
