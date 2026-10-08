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
//
// ITS SURFACE'S MEMORY (`PixelTurn` BLENDED, as `planet.gdshader`'s worlds;
// off unless asked, and then nothing below changes): turned by any fraction of
// a pixel a frame, the rock's grain and the pieces' edges slid across the
// pixel grid and pixels went A, B, A. So, as the other worlds: four points a
// block, the commonest kind (rock, crust, molten face, core, or nothing: the
// gaps) wins and its value is their average; the value eased 0.35 a frame;
// a shade held until its lit value has moved 0.085 past where it last changed,
// let go after 40 frames. The flicker is meant and kept: the core's boil is
// never held (as the other worlds' burning ground), and the molten faces' pulse
// is taken out of what is eased and held and put back on what shows. A shader keeps
// nothing between frames, so `ShatteredView` runs this one twice: into a
// picture a pixel a block that is the memory (`mem_mode` 1, reading itself last
// frame from `mem_prev`), and on screen drawn from it (`mem_mode` 2, `mem_now`).

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
// RADIANT (`planet.gdshader`'s): the rock lit, not shaded -- its own colour as an
// albedo, the star's colour and a soft terminator, the gas's colour in its shade
uniform bool radiant = false;
uniform vec3 star_tint = vec3(1.0);
uniform vec3 night_fill = vec3(0.0);
uniform vec4 r_wk = vec4(1.7, 9.0, 7.0, 1.15);
// THE MEMORY (see the top): 0 none; 1 this pass works it out; 2 drawn from it.
// A block a pixel, `mem_n` a side, the world's middle `mem_half` in. Each
// pixel: R its eased value, G its lit value when its shade was last set (both
// (v + 0.5) / 2), B what it shows -- its kind (low 3 bits: 1 core, 2 rock,
// 3 crust, 4 molten face) and the step of that kind's ramp (above) -- and A
// frames held + 1 (0 for nothing there: a gap).
uniform int mem_mode = 0;
uniform sampler2D mem_prev : filter_nearest, repeat_disable;
uniform sampler2D mem_now : filter_nearest, repeat_disable;
uniform int mem_n = 1;
uniform int mem_half = 0;
// nothing held: a new world, a new size (the zoom), its first frames
uniform bool mem_fresh = true;
uniform float mem_ease = 0.35;
uniform float mem_hyst = 0.085;
uniform int mem_release = 40;

const int R_ROCK = 0;
const int R_GLOW = 6;
// what a line of sight meets
const int K_NONE = 0;
const int K_CORE = 1;
const int K_ROCK = 2;
const int K_CRUST = 3;
const int K_MELT = 4;

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
vec3 r_lit(int ramp, float v, vec3 n, vec3 L, float kl) {
	float va = clamp(v * 0.85 + 0.1, 0.0, 0.999) * 6.0 - 0.5;
	int vi = int(floor(va));
	vec3 alb = pow(mix(rampc(ramp, vi), rampc(ramp, vi + 1), clamp(va - float(vi), 0.0, 1.0)), vec3(2.2));
	float ld = dot(n, L);
	float lamR = (max(ld, 0.0) * 0.85 + 0.15 * smoothstep(-0.12, 0.25, ld)) * kl;
	vec3 c = alb * (star_tint * r_wk.x * lamR + night_fill * r_wk.y * (0.55 + 0.45 * max(n.z, 0.0)));
	// (washed by the glowing cloud in front of it, as the worlds are)
	c = c * 0.75 + night_fill * 16.0 * 0.25;
	return pow(vec3(1.0) - exp(-c * r_wk.w), vec3(1.0 / 2.2));
}
float bayer2(float x, float y) {
	int ix = (int(x + ctr_off.x) + 999) & 1, iy = (int(y + ctr_off.y) + 999) & 1;
	return iy == 0 ? (ix == 0 ? 0.0 : 2.0) : (ix == 0 ? 3.0 : 1.0);
}
// the step of a ramp a value lands on here
int lev_at(float v, float x, float y) { return int(floor(v * 6.0 + (painted ? 0.0 : (bayer2(x, y) - 1.5) * 0.22))); }
vec3 ramp_at(int ramp, float v, float x, float y) { return rampc(ramp, lev_at(v, x, y)); }
int ramp_of(int kind) { return (kind == K_CORE || kind == K_MELT) ? R_GLOW : R_ROCK; }

// the molten heart's flicker, over the whole of it
float flicker() { return 0.92 + 0.06 * sin(time * 2.1) + 0.04 * sin(time * 4.7 + 1.0); }

// the whole of it turns about the vertical
vec3 turn(vec3 v, float s1, float c1) { return vec3(v.x * c1 + v.z * s1, v.y, -v.x * s1 + v.z * c1); }

// WHAT THE LINE OF SIGHT AT (x, y) MEETS: its kind, its ground's value `v` and
// how lit it is `sh` (the shade is `v * sh`; the molten face and the core
// carry all of it in `v`), and the normal the star lights (RADIANT).
void trace(float x, float y, out int kind, out float v, out float sh, out vec3 nl) {
	float ang = seed + time * spin * 0.6, ca = cos(ang), sa = sin(ang);
	float flick = flicker();
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
	kind = K_NONE; v = 0.0; sh = 1.0; nl = vec3(0.0, 0.0, 1.0);
	if (hit_i == -1) {
		float g = fbm3(vec3(hit_p.x * 8.0 + time * 0.3, hit_p.y * 8.0, hit_p.z * 8.0 - time * 0.2), 3);
		kind = K_CORE;
		v = min(0.999, 0.55 + g * 0.45);
	} else if (hit_i >= 0 && hit_face < 0) {
		// the outside: rock lit by the star
		nl = turn(hit_p, sa, ca);
		kind = K_ROCK;
		v = 0.3 + fbm3(vec3(hit_p.x * 2.4 + seed, hit_p.y * 2.4, hit_p.z * 2.4), 4) * 0.5;
		sh = 0.1 + 0.9 * max(0.0, dot(nl, light)) * k_light;
	} else if (hit_i >= 0) {
		// the broken face: hottest toward the middle, cooling to crust at the rim
		float rr = length(hit_p), grain = fbm3(vec3(hit_p.x * 6.0 + seed, hit_p.y * 6.0 + time * 0.08, hit_p.z * 6.0), 3);
		if (rr > 0.88) {
			vec3 sj = seeds[hit_face], si = seeds[hit_i];
			nl = turn(-normalize(sj - si), sa, ca);
			kind = K_CRUST;
			v = 0.2 + grain * 0.3;
			sh = 0.25 + 0.75 * max(0.0, dot(nl, light));
		} else {
			kind = K_MELT;
			v = min(0.999, max(0.0, (1.02 - rr * cool) * flick + (grain - 0.5) * 0.5));
		}
	}
}

// a kind's colour, from its value and shade (or, held, its ramp's step `lv`)
vec3 colour_of(int kind, float v, float sh, vec3 nl, int lv, float x, float y) {
	bool rock = kind == K_ROCK || kind == K_CRUST;
	if (rock && radiant) return r_lit(R_ROCK, v, nl, light, k_light);
	if (lv >= 0) return rampc(ramp_of(kind), lv);
	return ramp_at(ramp_of(kind), min(0.999, v * sh), x, y);
}

// THE MEMORY'S PASS: what is remembered of this block this frame, from the
// four points across it and what was remembered last frame
vec4 mem_state(float x, float y, ivec2 mb) {
	int a_k[4]; float a_v[4]; float a_s[4];
	vec3 nl;
	for (int i = 0; i < 4; i++) {
		float q = 0.25 * float(max(cell, 1));
		trace(x + (i == 0 || i == 2 ? -q : q), y + (i < 2 ? -q : q), a_k[i], a_v[i], a_s[i], nl);
	}
	vec4 P = texture(mem_prev, (vec2(mb) + 0.5) / float(mem_n));
	bool had = !mem_fresh && P.a > 0.0;
	int B = int(round(P.b * 255.0)), pc = int(round(P.a * 255.0)) - 1;
	int pk = had ? (B & 7) : K_NONE, plv = B >> 3;
	// the commonest kind wins; the one shown last frame keeps it while it still
	// covers one point fewer than the winner or more (as the sprites' `MARGIN`):
	// where a gap, the rock and a molten face meet, the points split two, one and
	// one, and the winner swapped every few frames
	int kind = a_k[0], best = 0, pn = 0;
	for (int i = 0; i < 4; i++) {
		int c = 0;
		for (int j = 0; j < 4; j++) if (a_k[j] == a_k[i]) c++;
		if (c > best) { best = c; kind = a_k[i]; }
		if (a_k[i] == pk) pn++;
	}
	if (!mem_fresh && pn > 0 && pn >= best - 1) kind = pk;
	if (kind == K_NONE) return vec4(0.0);
	float v = 0.0, sh = 0.0;
	int n = 0;
	for (int i = 0; i < 4; i++) if (a_k[i] == kind) { v += a_v[i]; sh += a_s[i]; n++; }
	v /= float(n); sh /= float(n);
	// THE MOLTEN FACE'S FLICKER (one beat over the whole of it) kept out of
	// what is eased and held, and put back on the shade it shows: held with it,
	// the faces' pulse lost a third of its changes; eased with it, it lagged
	float fl = kind == K_MELT ? flicker() : 1.0;
	v /= fl;
	// eased, while it is the same kind
	float e = v;
	if (had && pk == kind) e = (P.r * 2.0 - 0.5) + (v - (P.r * 2.0 - 0.5)) * mem_ease;
	float lit = e * sh;
	int lv = clamp(lev_at(min(0.999, max(0.0, lit * fl)), x, y), 0, 5);
	float vref = lit;
	int held = 0;
	// held (the rock, the crust and the molten face; the core's boil is meant):
	// it would change shade, but its lit value has not moved clearly past where
	// its shade was last set, and it has not been held too long. The rock keeps
	// the very shade it showed; the molten face keeps its value, the flicker on it
	float pref = P.g * 2.0 - 0.5;
	if (had && kind != K_CORE && pk == kind && plv != lv && abs(lit - pref) < mem_hyst && pc + 1 < mem_release) {
		lv = kind == K_MELT ? clamp(lev_at(min(0.999, max(0.0, pref * fl)), x, y), 0, 5) : plv;
		vref = pref;
		held = pc + 1;
	}
	return vec4(clamp((e + 0.5) * 0.5, 0.0, 1.0), clamp((vref + 0.5) * 0.5, 0.0, 1.0),
		float(kind | (lv << 3)) / 255.0, float(held + 1) / 255.0);
}

void fragment() {
	float S2 = float(2 * half_size + 1);
	vec2 pix = floor(UV * S2) - vec2(float(half_size));
	// (the block's place in the memory, `mem_mode`)
	ivec2 mb = ivec2((cell > 1 ? floor(pix / float(cell)) : pix) + float(mem_half));
	if (mem_mode == 1) {
		// working out the memory: this pixel is a block of the world
		vec2 mt = floor(UV * float(mem_n));
		mb = ivec2(mt);
		pix = (mt - float(mem_half)) * float(max(cell, 1));
	}
	// each block sampled at its MIDDLE: at its corner the disc sat half a block
	// up and left, and a small world came out lopsided
	if (cell > 1) pix = floor(pix / float(cell)) * float(cell) + 0.5 * float(cell - 1);
	pix -= ctr_off;
	float x = pix.x, y = pix.y;
	if (mem_mode == 1) {
		COLOR = mem_state(x, y, mb);
	} else {
		int kind;
		float v, sh;
		vec3 nl = vec3(0.0, 0.0, 1.0);
		vec3 col = vec3(0.0);
		if (mem_mode == 2) {
			// drawn from the memory: its kind and its step (RADIANT's rock lit from the
			// eased value, its normal from what the line of sight meets now)
			vec4 P = texture(mem_now, (vec2(mb) + 0.5) / float(mem_n));
			kind = P.a > 0.0 ? (int(round(P.b * 255.0)) & 7) : K_NONE;
			if (kind != K_NONE) {
				int lv = int(round(P.b * 255.0)) >> 3;
				if (radiant && (kind == K_ROCK || kind == K_CRUST)) {
					int lk;
					float lvv, lsh;
					trace(x, y, lk, lvv, lsh, nl);
					if (lk != K_ROCK && lk != K_CRUST) nl = normalize(vec3(x / r, y / r, sqrt(max(0.0, 1.0 - (x * x + y * y) / (r * r)))));
				}
				col = colour_of(kind, P.r * 2.0 - 0.5, 1.0, nl, lv, x, y);
			}
		} else {
			trace(x, y, kind, v, sh, nl);
			if (kind != K_NONE) col = colour_of(kind, v, sh, nl, -1, x, y);
		}
		// the core's light, behind everything, showing through the gaps
		float flick = flicker();
		float d2 = (x * x + y * y) / (r * r);
		float I = glow * flick * (1.5 * exp(-d2 / 0.02) + 0.55 * exp(-d2 / 0.14) + 0.16 * exp(-d2 / 0.7));
		vec3 lc = d2 < 0.015 ? vec3(1.0, 0.97, 0.9) : glow_c;
		float dth = painted ? 0.5 : (bayer2(x, y) + 0.5) / 4.0;
		vec3 q = max(vec3(0.0), floor((1.0 - exp(-1.6 * I * lc)) * 6.0 + dth - 0.5)) / 6.0;
		vec2 at = centre + pix;
		if (distance(at, star_at) < star_r) COLOR = vec4(0.0);
		else if (kind != K_NONE) COLOR = vec4(col, 1.0);
		else COLOR = vec4(q, 0.0);
	}
}
