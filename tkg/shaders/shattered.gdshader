shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// A WORLD IN PIECES, as Jon picked it ("C. Shards ... HOLY SHIT WOW!!! YES"):
// the mockup's `shatter2` (scratchpad `sysmap/planets.js`) on the GPU.
//
// The world is cut into nine pieces -- each piece is the ball clipped to its
// own cell round a seed point -- and the pieces pushed apart round the molten
// heart that is left. Every pixel's line of sight is clipped against each piece
// exactly: where it meets the ball it shows rocky outside, lit by the star;
// where it meets a cut it shows the broken face, molten toward the middle and
// cooling to crust at the rim. The whole of it turns slowly. The core's light
// lies behind the pieces and shows only through the gaps. The rubble round it
// is drawn by `ShatteredView`.

uniform sampler2D ramps : filter_nearest, repeat_disable;
// worked out in cell x cell blocks of game pixels (Jon's B, for the whole map)
uniform int cell = 1;
// THE LIVE CENTRE (the map's smooth zoom, `SystemView`): where the world's true
// centre sits off the box's own (px, under a block either way), so the disc is drawn
// round it while the box stays on the grid; the dither keeps the grid's
uniform vec2 ctr_off = vec2(0.0);
uniform vec3 seeds[9];
uniform int k_count = 9;
uniform float r = 10.0;
uniform int half_size = 24;
uniform float push = 0.5;
uniform float cool = 1.7;
uniform float core_r = 0.24;
uniform float glow = 0.5;
uniform vec3 glow_c = vec3(1.0, 0.45, 0.18);
uniform float spin = 0.05;
uniform float seed = 0.0;
uniform float time = 0.0;
uniform vec3 light = vec3(-0.83, -0.31, 0.47);
uniform float k_light = 1.0;
uniform vec2 star_at = vec2(-9999.0);
uniform float star_r = 0.0;
uniform vec2 centre = vec2(0.0);
// PAINTED (direction B): its steps flat, never dithered between
uniform bool painted = false;

const int R_ROCK = 0;
const int R_GLOW = 6;

float h3(vec3 p) {
	ivec3 q = ivec3(p);
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u) ^ (uint(q.z) * 1440662683u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float n3(vec3 p) {
	vec3 i = floor(p), f = p - i;
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1, 0, 0)), u.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), u.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}
float fbm3(vec3 p, int oct) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < oct; i++) { s += a * n3(p); n += a; p *= 2.03; a *= 0.5; }
	return s / n;
}
vec3 rampc(int ramp, int k) { return texelFetch(ramps, ivec2(clamp(k, 0, 5), ramp), 0).rgb; }
float bayer2(float x, float y) {
	int ix = (int(x + ctr_off.x) + 999) & 1, iy = (int(y + ctr_off.y) + 999) & 1;
	return iy == 0 ? (ix == 0 ? 0.0 : 2.0) : (ix == 0 ? 3.0 : 1.0);
}
vec3 ramp_at(int ramp, float v, float x, float y) { return rampc(ramp, int(floor(v * 6.0 + (painted ? 0.0 : (bayer2(x, y) - 1.5) * 0.22)))); }

// the whole of it turns about the vertical
vec3 turn(vec3 v, float s1, float c1) { return vec3(v.x * c1 + v.z * s1, v.y, -v.x * s1 + v.z * c1); }

void fragment() {
	float S2 = float(2 * half_size + 1);
	vec2 pix = floor(UV * S2) - vec2(float(half_size));
	// each block sampled at its MIDDLE: at its corner the disc sat half a block
	// up and left, and a small world came out lopsided
	if (cell > 1) pix = floor(pix / float(cell)) * float(cell) + 0.5 * float(cell - 1);
	pix -= ctr_off;
	float x = pix.x, y = pix.y;
	float ang = seed + time * spin * 0.6, ca = cos(ang), sa = sin(ang);
	float flick = 0.92 + 0.06 * sin(time * 2.1) + 0.04 * sin(time * 4.7 + 1.0);
	vec3 Db = turn(vec3(0.0, 0.0, -1.0), -sa, ca);
	vec3 Ob = turn(vec3(x / r, y / r, 4.0), -sa, ca);
	float best = 1e9;
	int hit_i = -2, hit_face = -1;
	vec3 hit_p = vec3(0.0);
	for (int i = 0; i < k_count; i++) {
		vec3 si = seeds[i];
		vec3 dir = normalize(si);
		float ph = h3(vec3(float(i), 7.0, floor(seed))) * 6.0;
		vec3 T = dir * push * (1.0 + 0.12 * sin(time * 0.4 + ph));
		vec3 O = Ob - T;
		float b = dot(O, Db), c = dot(O, O) - 1.0, disc = b * b - c;
		if (disc < 0.0) continue;
		float sq = sqrt(disc);
		float t0 = -b - sq, t1 = -b + sq;
		int face = -1;
		for (int j = 0; j < k_count; j++) {
			if (j == i || t0 >= t1) continue;
			vec3 sj = seeds[j];
			vec3 n = sj - si;
			float cc = (dot(sj, sj) - dot(si, si)) * 0.5;
			float on = dot(O, n), dn = dot(Db, n);
			if (abs(dn) < 1e-7) { if (on > cc) t1 = -1.0; continue; }
			float tt = (cc - on) / dn;
			if (dn > 0.0) { if (tt < t1) t1 = tt; } else if (tt > t0) { t0 = tt; face = j; }
		}
		if (t0 >= t1 || t0 >= best) continue;
		best = t0; hit_i = i; hit_face = face; hit_p = O + t0 * Db;
	}
	// the molten heart left in the middle
	{
		float b = dot(Ob, Db), c = dot(Ob, Ob) - core_r * core_r, disc = b * b - c;
		if (disc > 0.0 && -b - sqrt(disc) < best) { best = -b - sqrt(disc); hit_i = -1; hit_p = Ob + best * Db; }
	}
	vec3 col = vec3(0.0);
	bool solid = hit_i > -2;
	if (hit_i == -1) {
		float g = fbm3(vec3(hit_p.x * 8.0 + time * 0.3, hit_p.y * 8.0, hit_p.z * 8.0 - time * 0.2), 3);
		col = ramp_at(R_GLOW, min(0.999, 0.55 + g * 0.45), x, y);
	} else if (hit_i >= 0 && hit_face < 0) {
		// the outside: rock lit by the star
		vec3 nv = turn(hit_p, sa, ca);
		float lam = max(0.0, dot(nv, light));
		float v = 0.3 + fbm3(vec3(hit_p.x * 2.4 + seed, hit_p.y * 2.4, hit_p.z * 2.4), 4) * 0.5;
		col = ramp_at(R_ROCK, min(0.999, v * (0.1 + 0.9 * lam * k_light)), x, y);
	} else if (hit_i >= 0) {
		// the broken face: hottest toward the middle, cooling to crust at the rim
		float rr = length(hit_p), grain = fbm3(vec3(hit_p.x * 6.0 + seed, hit_p.y * 6.0 + time * 0.08, hit_p.z * 6.0), 3);
		if (rr > 0.88) {
			vec3 sj = seeds[hit_face], si = seeds[hit_i];
			vec3 fn = turn(-normalize(sj - si), sa, ca);
			col = ramp_at(R_ROCK, min(0.999, (0.2 + grain * 0.3) * (0.25 + 0.75 * max(0.0, dot(fn, light)))), x, y);
		} else {
			col = ramp_at(R_GLOW, min(0.999, max(0.0, (1.02 - rr * cool) * flick + (grain - 0.5) * 0.5)), x, y);
		}
	}
	// the core's light, behind everything, showing through the gaps
	float d2 = (x * x + y * y) / (r * r);
	float I = glow * flick * (1.5 * exp(-d2 / 0.02) + 0.55 * exp(-d2 / 0.14) + 0.16 * exp(-d2 / 0.7));
	vec3 lc = d2 < 0.015 ? vec3(1.0, 0.97, 0.9) : glow_c;
	float dth = painted ? 0.5 : (bayer2(x, y) + 0.5) / 4.0;
	vec3 q = max(vec3(0.0), floor((1.0 - exp(-1.6 * I * lc)) * 6.0 + dth - 0.5)) / 6.0;
	vec2 at = centre + pix;
	if (distance(at, star_at) < star_r) COLOR = vec4(0.0);
	else if (solid) COLOR = vec4(col, 1.0);
	else COLOR = vec4(q, 0.0);
}
