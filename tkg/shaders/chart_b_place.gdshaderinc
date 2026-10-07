// THE PAINTED STAR CHART, the place pass: a G-buffer per 2x2 block (`ChartSky`,
// style PAINTED). Direction B of the Oct 5 showcase (`showcase/B/chart/place.glsl`):
// it decides WHAT each block is and how lit; the paint pass (`chart_b_paint`)
// paints it from the curated palette.
//   out = (material id / 255, light level 0..1 within that material's ramp,
//          shape id / 255, (light-direction index 0..31) * 2 + edge flag, / 255)
// Everything is anchored in the galaxy's plane (or the sky's own layers), and
// every pattern is indexed by the dither index anchored to the galaxy's centre,
// so it moves with the picture.
// The black hole is C's (`legacy_hole.gdshaderinc`), as drawn: its shape and
// perspective unchanged, its bands painted on the hole ramp (the same colours).
// C's life, drawn by hand: gas streams along the arms, knots breathe in held
// poses and bloom, a supernova flares in four drawn frames and its light echo
// steps out in rings, clouds have weather -- a lightning bolt sprite held for a
// beat and its afterglow, glimmers that step along a remnant's filaments, light
// shafts that step round a reflection cloud's star. Nothing changes for a single
// frame. The poses are worked out on the CPU (`ChartSky._feed_b_events`).

#include "res://shaders/chart_b_common.gdshaderinc"
#include "res://shaders/legacy_hole.gdshaderinc"
#include "res://shaders/chart_bg.gdshaderinc"

uniform sampler2D u_stars : filter_nearest, repeat_disable;   // sparkle sprites: r level, g colour class / 4, b tier / 3, a present
uniform bool u_stars_on = true;
uniform sampler2D u_puffA : filter_nearest, repeat_disable;
uniform sampler2D u_puffB : filter_nearest, repeat_disable;
uniform vec4 u_puffP;        // cells across, cell size, origin x, origin y (gu)
uniform float u_Y[96];       // OKLab lightness of every ramp entry
uniform int u_mstart[24];
uniform int u_mlen[24];
uniform vec2 u_vp_size = vec2(330.0, 220.0);
uniform vec2 u_vp_origin = vec2(-2.0);
uniform vec2 u_cpix = vec2(327.0, 214.0);
uniform vec2 u_res = vec2(655.0, 429.0);
uniform vec2 u_block0 = vec2(0.0);
uniform float u_zoom = 0.42;
uniform float u_time = 0.0;
uniform float u_wxOn = 1.0;
// events, as held poses (ChartSky._feed_b_events)
uniform vec4 u_sn = vec4(0.0);     // supernova: view x, y, drawn frame (0 none, 1-4), 0
uniform vec4 u_echo = vec4(0.0);   // light echo: plane x, y, ring radius (gu, stepped), strength step (0-3)
uniform vec4 u_lt[12];             // lightning per cloud: pose (0 none, 1 bolt, 2 afterglow), round-frame x, y (gu), bolt seed
uniform float u_glim = 0.0;        // the glimmers' stepped angle
uniform float u_shaft = 0.0;       // the shafts' stepped angle
uniform float u_flow = 0.0;        // the currents' clock (halved under reduced motion)

#define M_SKY 0
#define M_ARM 1
#define M_KNOT 2
#define M_BULGE 3
#define M_DUST 4
#define M_BILLOW 5
#define M_HA 6
#define M_O3 7
#define M_REFL 8
#define M_PILLAR 9
#define M_HALO 10
#define M_DARK 11
#define M_HOLE 12
#define M_STAR 13
#define M_STARW 14
#define M_STARP 16
#define M_BALL 17
#define M_BOLT 18

#if LOW
const int OCT = 1;
#else
const int OCT = 3;
#endif

// the block this fragment paints, and its dither index (anchored to the galaxy)
struct Px { ivec2 blk; ivec2 dq; };

vec2 gpan() { return (u_res * 0.5 - u_cpix) / u_zoom; }
vec2 scr(vec2 v) { return u_cpix + v * u_zoom; }
ivec2 blockOf(vec2 s) { return ivec2(floor((s - u_vp_origin) * 0.5)); }
float blockView() { return 2.0 / u_zoom; }

struct Cand { int m; float lv; int sid; float aux; float y; };
float rampY(int m, float lv) {
	int n = u_mlen[m];
	int b = clamp(int(floor(lv * float(n))), 0, n - 1);
	return u_Y[u_mstart[m] + b];
}
Cand cand(int m, float lv, int sid, float aux) {
	lv = clamp(lv, 0.0, 0.999);
	return Cand(m, lv, sid, aux, rampY(m, lv));
}
vec4 outC(Cand c) { return vec4(float(c.m) / 255.0, c.lv, float(c.sid) / 255.0, c.aux); }
float auxOf(vec2 L, bool edge) {
	float a = atan(L.y, L.x) / TAU_B;
	int ai = int(floor(fract(a) * 32.0 + 0.5)) & 31;
	return float(ai * 2 + (edge ? 1 : 0)) / 255.0;
}
// pattern transparency: show the front layer on this block at coverage a (0, 25, 50, 75, 100 %)
bool pat(Px P, float a) {
	if (a >= 0.875) {
		return true;
	}
	if (a < 0.125) {
		return false;
	}
	float q = floor(a * 4.0 + 0.5) / 4.0;
	return kitBayer4(P.dq) < q;
}
vec2 dirTo(vec2 from, vec2 to) {
	vec2 d = to - from;
	return dot(d, d) > 1e-6 ? normalize(d) : vec2(0.0, -1.0);
}

// a star field anchored in the plane; each star lands in exactly one block
vec4 planeStar(vec2 g, vec2 v, float cell, float prob, int seed) {
	vec4 r = vec4(0.0);
	float bv = blockView();
	ivec2 c0 = ivec2(floor(g / cell));
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = c0 + ivec2(i, j);
			vec3 h = kitHash3(c + ivec2(seed * 7919, seed * 3571));
			if (h.z > prob) {
				continue;
			}
			vec2 d = (toView((vec2(c) + h.xy) * cell, 0.0) - v) / bv;
			if (d.x >= -0.5 && d.x < 0.5 && d.y >= -0.5 && d.y < 0.5) {
				r = vec4(1.0, kitHash3(c + ivec2(seed * 131 + 17, seed * 977 + 5)));
			}
		}
	}
	return r;
}
// a sparkle sprite centred on view point c: 0 none, else a level for the star ramp
float spriteAt(Px P, vec2 c, int tier) {
	ivec2 d = P.blk - blockOf(scr(c));
	int ax = abs(d.x), ay = abs(d.y);
	if (ax == 0 && ay == 0) {
		return 0.95;
	}
	if (tier >= 2 && ax + ay == 1) {
		return 0.62;
	}
	if (tier >= 3 && ((ax == 2 && ay == 0) || (ax == 0 && ay == 2))) {
		return 0.4;
	}
	if (tier >= 3 && ax == 1 && ay == 1) {
		return 0.28;
	}
	return 0.0;
}

// ------------------------------------------------------------------ the hole (C's)
// 0: not the hole; 1: its disc (hc, cov set); 2: the shadow, round, in front of everything
int holeAt(vec2 v, out Cand hc, out float cov, out bool shad) {
	hc = cand(M_SKY, 0.0, 0, 0.0);
	cov = 0.0;
	shad = false;
	float shadow = u_g2.w * u_k;
	vec2 S = lh_to_s(v, vec2(0.0), shadow);
	if (length(S) > lh_dims.x * 0.97) {
		return 0;
	}
	float pxr = lh_px_rs(shadow * u_zoom);
	float clumps = smoothstep(2.6, 4.0, u_zoom);
	vec3 hot = lh_hot(u_time, u_wxOn);
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		vec2 o = (vec2(float(j & 1), float(j >> 1)) - 0.5) * pxr;
		acc += lh_sample(S + o, u_time, clumps, hot);
	}
	acc *= 0.25;
	// the shadow is behind the disc: the disc's near side crosses it, as in C
	shad = acc.z > 0.5;
	if (acc.y > 0.004) {
		float heat = acc.x / acc.y;
		// the band C's hole would paint (`lh_colour`), as a step of the hole ramp
		int idx = heat > 1.22 ? 7 : clamp(int(floor(heat * 6.0)) + 1, 1, 6);
		// (C's darkest band only ever showed blended into what is behind; drawn
		// solid it was a dark rim round the disc, so it is left out)
		if (idx > 1) {
			hc = cand(M_HOLE, (float(idx) + 0.5) / 8.0, 0, 0.0);
			cov = acc.y;
			return 1;
		}
	}
	return shad ? 2 : 0;
}

// ------------------------------------------------------------------ billows
struct Puff { float h; vec3 n; vec3 P; float R; float M; float warm; float id; float top; };
void billows(vec2 g0, vec2 dg, float tt, out Puff p1) {
	p1.h = -1e9;
	p1.id = 0.0;
	p1.n = vec3(0.0, 0.0, 1.0);
	p1.P = vec3(0.0);
	p1.R = 0.0;
	p1.M = 0.0;
	p1.warm = 0.0;
	p1.top = 0.0;
	float cs = u_puffP.y;
	vec2 org = u_puffP.zw;
	int N = int(u_puffP.x);
	const float HM = 0.05;
	vec2 g1 = g0 + dg * HM;
	vec2 lo = min(g0, g1) - cs * 1.15, hi = max(g0, g1) + cs * 1.15;
	ivec2 c0 = max(ivec2(floor((lo - org) / cs)), ivec2(0)), c1 = min(ivec2(floor((hi - org) / cs)), ivec2(N - 1));
	for (int jj = 0; jj < 14; jj++) {
		int j = c0.y + jj;
		if (j > c1.y) {
			break;
		}
		for (int ii = 0; ii < 14; ii++) {
			int i = c0.x + ii;
			if (i > c1.x) {
				break;
			}
			vec4 A = texelFetch(u_puffA, ivec2(i, j), 0);
			if (A.z <= 0.0) {
				continue;
			}
			vec4 B = texelFetch(u_puffB, ivec2(i, j), 0);
			vec2 ctr = org + (vec2(float(i), float(j)) + A.xy) * cs;
			// a slow churn, in held poses: each heap swells a step and back
			float pose = floor(0.5 + 1.5 * (0.5 + 0.5 * sin(tt * 0.05 + A.x * 40.0 + A.y * 17.0))) / 3.0;
			float R = A.z * (0.93 + 0.07 * pose);
			float cR = B.x, ch = A.w;
			vec2 o = g0 - ctr;
			float iR2 = 1.0 / (R * R), ic2 = 1.0 / (cR * cR);
			float qa = dot(dg, dg) * iR2 + ic2;
			float qb = 2.0 * dot(o, dg) * iR2 - 2.0 * ch * ic2;
			float qc = dot(o, o) * iR2 + ch * ch * ic2 - 1.0;
			float disc = qb * qb - 4.0 * qa * qc;
			if (disc < 0.0) {
				continue;
			}
			float hh = (-qb + sqrt(disc)) / (2.0 * qa);
			if (hh < 0.0 || hh <= p1.h) {
				continue;
			}
			p1.h = hh;
			p1.P = vec3(g0 + dg * hh, hh);
			p1.n = normalize(vec3((p1.P.xy - ctr) * iR2, (hh - ch) * ic2));
			p1.R = R;
			p1.M = B.y;
			p1.warm = B.z;
			p1.id = B.w;
			p1.top = 0.003 + 0.036 * B.y;
		}
	}
}
float massTab(vec2 g) {
	ivec2 c = ivec2(floor((g - u_puffP.zw) / u_puffP.y));
	int N = int(u_puffP.x);
	if (c.x < 0 || c.y < 0 || c.x >= N || c.y >= N) {
		return 0.0;
	}
	return texelFetch(u_puffB, c, 0).y;
}
Cand shadePuff(Puff p, vec2 dg, out float alpha) {
	vec2 toCore = -normalize(p.P.xy);
	float rr = length(p.P.xy);
	float Ic = min(1.0, 2.2 / (1.0 + sq(rr / 0.2)));
	bool warm = p.warm > 0.5;
	vec3 L = warm ? normalize(vec3(toCore, 0.3)) : normalize(vec3(toCore * 0.35, 0.94));
	float nl = dot(p.n, L);
	float wrap = clamp(nl * 0.6 + 0.4, 0.0, 1.0);
	float top = smoothstep(0.0, p.top, p.h);
	float s = warm ? 0.36 * top + 0.4 * max(nl, 0.0) + 0.24 * wrap : 0.55 * top + 0.45 * wrap;
	float lv = warm ? 0.36 + 0.7 * s * (0.6 + 0.4 * Ic) : 0.1 + 0.62 * s + 0.12 * step(0.92, s);
	vec2 lv2 = kitRot(u_phi) * L.xy;
	vec2 Ls = normalize(vec2(lv2.x, lv2.y * KIT_TILT - L.z * KIT_TILT_COS));
	vec3 V = normalize(vec3(dg, 1.0));
	bool edge = abs(dot(p.n, V)) < 0.45;
	float big = p.R * u_k * u_zoom / 2.0;
	int sid = big >= 3.5 ? int(p.id * 255.0 + 0.5) : 0;
	Cand c = cand(warm ? M_BILLOW : M_ARM, lv, sid, auxOf(Ls, edge));
	float a = mix(0.25, 1.0, smoothstep(0.12, 0.5, p.h / max(p.top, 1e-3)));
	int band = int(floor(c.lv * float(u_mlen[c.m])));
	if (band <= (warm ? 2 : 1)) {
		a = min(a, 0.5);
	}
	alpha = a;
	return c;
}

// ------------------------------------------------------------------ clouds
vec2 clusterOf(int i) { return u_lb[i * 3 + int(u_ck[i].w + 0.5)].xy; }
float seedOf(int i) { return float(i) * 13.17 + u_g3.w; }
vec2 warpOf(vec2 q, float bq, float seed) { return vec2(fbmL(q + seed, bq, 2), fbmL(q + seed + 5.3, bq, 2)); }
float wxGate() { return u_wxOn * smoothstep(2.4, 3.2, u_zoom); }

float bubbleAt(vec2 v) {
	float bb = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= u_ncl) {
			break;
		}
		if (int(u_ck[i].x + 0.5) != 3) {
			continue;
		}
		float rr = length(cloudFrame(v, i)) / u_cl[i].w;
		bb = max(bb, smoothstep(0.93, 0.86, rr));
	}
	return bb;
}
float cloudLight(vec2 v, int i) {
	vec2 d = cloudFrame(v, i);
	float R = u_cl[i].z;
	float rr = length(d - clusterOf(i) * 0.5) / R;
	return smoothstep(2.0, 0.9, rr + 0.25 * kitSnoise2(d / R * 2.0 + seedOf(i))) / (1.0 + sq(rr / 0.8));
}

// THE BOLT AS A PIXEL ARTIST DRAWS IT (Jon: a crisp zigzag, not a smooth
// curve): from its point straight down the screen in four strokes, each a
// 45-degree jog of whole blocks to one side and then a straight drop, the jogs
// turning back and forth -- one block wide, every block whole. How far block
// b is from it, in blocks (0 on it).
float boltBlocks(ivec2 b, int i) {
	vec4 lt = u_lt[i];
	float rb = u_cl[i].z * u_k * u_zoom * 0.5;     // the cloud's radius in blocks
	ivec2 a = blockOf(scr(cloudToView(i, lt.yz)));
	int row = b.y - a.y, dx = b.x - a.x;
	int sgn = kitHash3(ivec2(int(lt.w), i + 31)).x < 0.5 ? -1 : 1;
	int x = 0, y = 0;
	float best = 1e9;
	for (int s = 0; s < 4; s++) {
		vec3 h = kitHash3(ivec2(int(lt.w), s * 7 + i));
		int len = max(3, int(round((0.05 + 0.06 * h.y) * rb)));
		int jog = clamp(int(round((0.3 + 0.4 * h.x) * float(len))), 1, len - 1);
		int dir = (s % 2 == 0) ? sgn : -sgn;
		if (row >= y && row < y + len) {
			best = min(best, abs(float(dx - (x + dir * min(row - y, jog)))));
		}
		x += dir * jog;
		y += len;
	}
	if (row < 0) {
		best = length(vec2(float(dx), float(row)));
	} else if (row >= y) {
		best = length(vec2(float(dx - x), float(row - y + 1)));
	}
	return best;
}

bool emissionAt(Px P, vec2 v, int i, float blk, float bubble, out Cand c) {
	c = cand(M_SKY, 0.0, 0, 0.0);
	float R = u_cl[i].z;
	vec2 d = cloudFrame(v, i);
	float bnd = cloudBound(i);
	float dl = length(d);
	if (dl > bnd) {
		return false;
	}
	float bR = blk / R, seed = seedOf(i);
	vec2 q = d / R;
	vec2 dw0 = d + R * 0.32 * warpOf(q * 1.6, bR * 1.6, seed);
	float F = lobeField(dw0, i) * smoothstep(bnd, bnd * 0.72, dl);
	vec2 cc = clusterOf(i);
	vec2 e = (d - cc) / R;
	float rc = length(e), ang = atan(e.y, e.x);
	vec2 ca = vec2(cos(ang), sin(ang));
	float s = spriteAt(P, cloudToView(i, cc), 3);
	if (s > 0.0) {
		c = cand(M_STAR, s, 0, 0.0);
		return true;
	}
	for (int m = 0; m < 5; m++) {
		vec3 hm = kitHash3(ivec2(i * 7 + m, 991));
		vec2 o = (hm.xy - 0.5) * R * 0.16;
		float sm = spriteAt(P, cloudToView(i, cc + o), hm.z < 0.3 ? 2 : 1);
		if (sm > 0.0) {
			c = cand(M_STAR, sm * (0.7 + 0.3 * hm.z), 0, 0.0);
			return true;
		}
	}
	// the lightning bolt: one block wide, held for a beat (never a flash), its
	// point the white of the ramp and the strokes below it its violet
	vec4 lt = u_lt[i];
	float gate = wxGate();
	float bb = 1e9;
	if (lt.x > 0.5 && gate > 0.5) {
		bb = boltBlocks(P.blk, i);
	}
	if (lt.x > 0.5 && gate > 0.5 && lt.x < 1.5 && bb < 0.5) {
		c = cand(M_BOLT, P.blk.y - blockOf(scr(cloudToView(i, lt.yz))).y < 3 ? 0.9 : 0.5, 0, 0.0);
		return true;
	}
	if (F < 0.12) {
		return false;
	}
	float tex = fbmL(q * 5.0 + seed * 2.0, bR * 5.0, OCT);
	float cav = 0.15 + 0.05 * kitSnoise2(ca * 1.3 + seed) + 0.03 * kitSnoise2(ca * 3.1 + seed * 2.3) + 0.025 * tex;
	float inCav = smoothstep(cav + 0.03, cav - 0.03, rc);
	float wall = exp(-sq((rc - cav - 0.035) / 0.05));
	float ill = 1.0 / (1.0 + sq(rc / 0.32));
	vec2 toL = rc > 1e-3 ? -e / rc : vec2(0.0);
	float Mm = lobeField(dw0, i) * (0.5 + 0.75 * (0.5 + 0.5 * fbmL(q * 2.8 + seed * 1.3, bR * 2.8, 2)));
	vec2 d2 = d + toL * R * 0.05;
	vec2 dw2 = d2 + R * 0.32 * warpOf(d2 / R * 1.6, bR * 1.6, seed);
	float Mm2 = lobeField(dw2, i) * (0.5 + 0.75 * (0.5 + 0.5 * fbmL(d2 / R * 2.8 + seed * 1.3, bR * 2.8, 2)));
	float emb = clamp((Mm - Mm2) * 4.0, -1.0, 1.0);
	float dens = Mm * (1.0 - bubble);
	float ha = dens * (1.0 - 0.85 * inCav) * (0.3 + 0.95 * ill) + 0.7 * wall * min(F, 1.0) * (1.0 - bubble);
	ha += 0.32 * emb * min(Mm, 1.0) * (0.45 + 0.55 * ill) + 0.12 * tex;
	vec2 wq = q * 3.2 + 0.6 * warpOf(q * 2.0, bR * 2.0, seed + 3.1) + seed * 1.7;
	float fil = 1.0 - abs(fbmL(wq, bR * 3.2, OCT + 1));
	ha += 0.3 * smoothstep(0.8, 0.96, fil) * min(dens, 1.0) * (0.5 + 0.5 * ill) * (1.0 - inCav);
	float vein = 1.0 - abs(fbmL(q * 4.6 - seed * 1.3, bR * 4.6, OCT));
	ha -= 0.28 * smoothstep(0.88, 0.98, vein) * (1.0 - inCav) * smoothstep(0.3, 0.6, dens);
	// the bolt's afterglow: the gas round it a band brighter, held, then gone
	if (lt.x > 0.5 && gate > 0.5) {
		float bg = bb / max(u_cl[i].z * u_k * u_zoom * 0.5, 1.0);
		ha += lt.x < 1.5 ? 0.5 * step(bg, 0.09) + 0.3 * step(bg, 0.2) : 0.35 * step(bg, 0.12);
	}
	if (F > 0.2 && bubble < 0.5) {
		vec2 es = kitRot(u_phi) * e;
		es.y *= 0.46341;
		float bS = blk / R;
		for (int p = 0; p < 4; p++) {
			vec3 hp = kitHash3(ivec2(i * 13 + p, 4049));
			float a0 = -0.5 * PI_B + (p == 0 ? -0.5 : (p == 1 ? -0.14 : (p == 2 ? 0.18 : 0.52))) + (hp.x - 0.5) * 0.18;
			vec2 ax = vec2(cos(a0), sin(a0));
			float tip = cav * 0.46341 * (1.0 + 0.5 * hp.y) + ((p == 1 || p == 2) ? 0.0 : 0.035);
			float len = ((p == 1 || p == 2) ? 0.22 : 0.14) + 0.07 * hp.z;
			float al = dot(es, ax), ac = dot(es, vec2(-ax.y, ax.x));
			if (al < tip - 0.01 || al > tip + len) {
				continue;
			}
			float t01 = (al - tip) / len;
			float w = (0.026 + 0.014 * hp.z) * (0.62 + 0.45 * t01) * (1.0 + 0.15 * kitSnoise2(vec2(al * 9.0, float(p) * 3.7 + seed)));
			ac += 0.2 * w * kitSnoise2(vec2(al * 10.0, float(p) + seed));
			float hc0 = tip + w;
			float inside = al >= hc0 ? w - abs(ac) : w - length(vec2(al - hc0, ac));
			if (inside < 0.0) {
				continue;
			}
			float eb = bS * 1.2;
			bool head = al < hc0 + w * 1.5;
			if (inside < eb && head && (al < hc0 || abs(ac) < w * 0.75)) {
				c = cand(M_O3, 0.85, 0, 0.0);
				return true;
			}
			if (inside < eb * 1.9 && head) {
				c = cand(M_HA, 0.84, 0, 0.0);
				return true;
			}
			if (inside < eb && t01 < 0.75 && ac * dot(vec2(-ax.y, ax.x), -normalize(es)) > 0.0) {
				c = cand(M_HA, 0.6, 0, 0.0);
				return true;
			}
			if (t01 > 0.78 && !pat(P, 1.0 - smoothstep(0.78, 1.0, t01))) {
				continue;
			}
			float side = clamp(ac / max(w, 1e-4), -1.0, 1.0) * sign(dot(vec2(-ax.y, ax.x), -es));
			float pl = 0.34 + 0.3 * (1.0 - t01) + 0.24 * side + 0.06 * tex;
			c = cand(M_PILLAR, pl, 200, auxOf(vec2(0.0, -1.0), false));
			return true;
		}
	}
	float a = max(smoothstep(0.12, 0.2, dens), inCav);
	if (!pat(P, a)) {
		return false;
	}
	if (inCav > 0.5) {
		float lo = 0.36 + 0.5 * smoothstep(cav, 0.0, rc + 0.07 * fbmL(q * 6.0 + seed * 3.0, bR * 6.0, OCT)) + 0.14 * tex;
		c = cand(M_O3, lo, 0, 0.0);
		return true;
	}
	c = cand(M_HA, 0.1 + 0.85 * (1.0 - exp(-max(ha, 0.0) / 0.9)), 0, 0.0);
	return true;
}

bool reflectionAt(Px P, vec2 v, int i, float blk, float bubble, Cand under, out Cand c) {
	c = under;
	float R = u_cl[i].z;
	vec2 d = cloudFrame(v, i);
	float bnd = cloudBound(i);
	float dl = length(d);
	if (dl > bnd) {
		return false;
	}
	float bR = blk / R, seed = seedOf(i);
	vec2 q = d / R;
	vec2 dw = d + R * 0.25 * warpOf(q * 1.8, bR * 1.8, seed);
	float F = lobeField(dw, i) * smoothstep(bnd, bnd * 0.72, dl);
	float tex = fbmL(q * 6.0 - seed, bR * 6.0, OCT);
	vec2 cc = clusterOf(i);
	float rs = length(d - cc) / R;
	float lit = 0.3 + 1.0 / (1.0 + sq(rs / 0.2));
	float ln = 1.0 - abs(fbmL(q * vec2(1.3, 2.8) + seed * 0.7, bR * 2.8, 2));
	float lanes = smoothstep(0.82, 0.95, ln);
	// shafts of light from its star, stepping round it a notch every two seconds
	vec2 rel = d - cc;
	float an = atan(rel.y, rel.x) - u_shaft;
	float shaft = step(0.68, kitVnoise2(vec2(cos(an), sin(an)) * 2.6 + seed * 3.0)) * wxGate() * smoothstep(0.06, 0.25, rs);
	float hz = F * lit * (1.0 + 0.25 * tex) * (1.0 - 0.5 * lanes) * (1.0 - 0.78 * bubble) * (1.0 + 0.6 * shaft);
	float s = spriteAt(P, cloudToView(i, cc), 3);
	if (s > 0.0) {
		c = cand(M_STAR, s, 0, 0.0);
		return true;
	}
	if (hz < 0.16) {
		return false;
	}
	float a = smoothstep(0.16, 0.26, hz);
	if (!pat(P, a)) {
		return false;
	}
	Cand h = cand(M_REFL, 0.1 + 0.8 * clamp(hz / 1.5, 0.0, 1.0), 0, 0.0);
	if (h.y <= under.y + 0.01) {
		if (under.m == M_ARM && a > 0.6 && under.lv < 0.64) {
			c = cand(M_ARM, under.lv + 1.0 / 6.0, 0, 0.0);
			return true;
		}
		return false;
	}
	c = h;
	return true;
}

float shellPx(float reach, vec2 cs2) {
	vec2 e = kitRot(u_phi) * cs2;
	return reach * u_k * u_zoom * length(vec2(e.x, 0.46341 * e.y));
}

bool remnantAt(vec2 v, int i, float blk, Cand under, out Cand c) {
	c = under;
	float reach = u_cl[i].w;
	vec2 d = cloudFrame(v, i);
	float rr = length(d) / reach;
	if (rr < 0.7 || rr > 1.3) {
		return false;
	}
	float seed = seedOf(i);
	float an = atan(d.y, d.x);
	vec2 cs2 = vec2(cos(an), sin(an));
	float pxs = shellPx(reach, cs2);
	float Rth = 1.0 + 0.09 * kitSnoise2(cs2 * 1.3 + seed) + 0.035 * kitSnoise2(cs2 * 3.4 + seed * 1.7);
	float best = 1e9;
	int bj = -1;
	float kn = 0.0;
	for (int j = 0; j < 3; j++) {
		float fj = float(j);
		float rj = Rth + (fj - 1.6) * 0.055 + 0.022 * sin(an * (3.0 + 2.0 * fj) + seed + fj * 2.1 + 2.0 * kitSnoise2(cs2 * 1.6 + vec2(fj * 3.3, seed)));
		float th = max(1.0, 0.014 * pxs) * (0.8 + 0.4 * (0.5 + 0.5 * kitSnoise2(cs2 * 2.6 + vec2(fj * 5.1, seed))));
		float gap = kitSnoise2(cs2 * 2.0 + vec2(fj * 5.3 - seed, fj * 2.1));
		if (gap < -0.4) {
			continue;
		}
		th *= smoothstep(-0.4, -0.15, gap);
		float dpx = abs(rr - rj) * pxs;
		if (dpx < th && dpx / th < best) {
			best = dpx / th;
			bj = j;
			kn = kitSnoise2(cs2 * 7.0 + vec2(fj * 11.0, seed));
		}
	}
	if (bj >= 0) {
		bool outer = bj == 2;
		float lv = 0.6 + 0.16 * step(best, 0.5) + (kn > 0.4 ? 0.22 : 0.0);
		// shock glimmers: three windows of the shell a band brighter, stepping
		// round it a notch every two seconds
		float gl = 0.0;
		for (int w = 0; w < 3; w++) {
			float th0 = u_glim + float(w) * 2.094 + seed;
			gl = max(gl, step(abs(mod(an - th0 + PI_B, TAU_B) - PI_B), 0.22));
		}
		lv += 0.2 * gl * wxGate();
		c = cand(outer ? M_HA : M_O3, lv, 202, 0.0);
		return true;
	}
	float dg = (rr - Rth) * pxs;
	float open = kitSnoise2(cs2 * 2.0 + vec2(-seed, 0.0));
	// the shell thins to a point where it opens, never a cut-off end
	float gw = max(2.0, 0.075 * pxs) * smoothstep(-0.55, -0.25, open);
	float gl2 = kitSnoise2(cs2 * 5.0 + vec2(rr * 6.0, seed * 0.7));
	if (gw > 0.5 && dg < gw * 0.7 && dg > -gw * 2.2) {
		if (dg > -gw * 0.45) {
			c = cand(M_HA, 0.4 + 0.14 * gl2, 0, 0.0);
			return true;
		}
		c = cand(M_O3, 0.34 + 0.16 * gl2, 0, 0.0);
		return true;
	}
	return false;
}

bool planetaryAt(Px P, vec2 v, int i, float blk, out Cand c) {
	c = cand(M_SKY, 0.0, 0, 0.0);
	float reach = u_cl[i].w;
	vec2 d = cloudFrame(v, i);
	if (dot(d, d) > sq(reach * 1.8)) {
		return false;
	}
	int shape = int(u_ck[i].z + 0.5);
	vec2 e = d;
	if (shape == 1) {
		e.x /= 1.3;
	}
	float rPN = reach * 0.5;
	float rr = length(e) / rPN;
	float an = atan(e.y, e.x);
	vec2 cs2 = vec2(cos(an), sin(an));
	float pxs = shellPx(rPN, cs2);
	float dpx = (rr - 1.0) * pxs;
	float s = spriteAt(P, cloudToView(i, vec2(0.0)), 3);
	if (s > 0.0) {
		c = cand(M_STAR, s, 0, 0.0);
		return true;
	}
	// the bands keep B's 2-2-2 block widths on a small shell and grow with a
	// near one (zoomed in, a 4-px ring round an empty middle reads as a wire)
	float wb = max(2.0, 0.035 * pxs);
	if (dpx > 1.0 && dpx <= 1.0 + wb) {
		c = cand(M_HA, 0.72, 203, 0.0);
		return true;
	}
	if (dpx > 1.0 - 2.0 * wb && dpx <= 1.0) {
		c = cand(M_O3, dpx > 1.0 - wb ? 0.92 : 0.66, 203, 0.0);
		return true;
	}
	float wf = max(2.0, 0.06 * pxs) + max(0.0, 0.22 * pxs - 20.0);
	if (dpx > 1.0 - 2.0 * wb - wf && dpx <= 1.0 - 2.0 * wb) {
		// the shell's inner glow, dithered thinner toward the middle
		float u = (1.0 - 2.0 * wb - dpx) / wf;
		if (u < 0.5 || pat(P, 1.0 - u)) {
			c = cand(M_O3, u < 0.5 ? 0.3 : 0.18, 0, 0.0);
			return true;
		}
	}
	if (shape == 3 && abs(cs2.y) < 0.18 && rr > 1.25 && rr < 1.5) {
		c = cand(M_HA, 0.6, 0, 0.0);
		return true;
	}
	if (shape == 2 && abs(cs2.x) < 0.45 && rr < 1.6 && pat(P, 0.5)) {
		c = cand(M_O3, 0.3, 0, 0.0);
		return true;
	}
	return false;
}

float darkDens(vec2 d, int i, float bR) {
	float R = u_cl[i].z;
	vec2 q = d / R;
	float sd = seedOf(i);
	vec2 dw = d + R * 0.35 * vec2(fbmL(q * 1.5 + sd, bR * 1.5, OCT + 3), fbmL(q * 1.5 + sd + 5.3, bR * 1.5, OCT + 3));
	return lobeField(dw, i) * (1.0 + 0.6 * fbmL(q * 2.4 + seedOf(i), bR * 2.4, OCT + 3));
}
bool darkAt(vec2 v, int i, float blk, Cand under, out Cand c) {
	c = under;
	float R = u_cl[i].z;
	vec2 d = cloudFrame(v, i);
	float bnd = cloudBound(i);
	float dl = length(d);
	if (dl > bnd) {
		return false;
	}
	float bR = blk / R;
	float fade = smoothstep(bnd, bnd * 0.72, dl);
	float rg = length(vec2(v.x, v.y / KIT_TILT)) / u_k;
	fade *= smoothstep(0.03, 0.075, rg);
	float dens = darkDens(d, i, bR) * fade;
	if (dens < 0.55) {
		return false;
	}
	vec2 vc = (toView(vec2(0.0), 0.0) - toView(u_cl[i].xy, 0.0)) / u_k;
	vc.y /= 0.46341;
	vec2 dc = normalize(kitRot(-u_phi) * vc);
	bool rim = darkDens(d + dc * blk * 1.4, i, bR) * fade < 0.55;
	bool warmBack = under.m == M_BULGE || under.m == M_BILLOW || under.m == M_BALL || under.m == M_HOLE;
	// distant lightning inside it: its body lit a band from within, held
	vec4 lt = u_lt[i];
	bool lit = lt.x > 0.5 && wxGate() > 0.5 && length(d - lt.yz) < 0.25 * R;
	if (rim) {
		if (under.m == M_SKY && under.y < 0.3) {
			return false;
		}
		if (warmBack) {
			c = cand(M_BULGE, 0.62 + 0.2 * smoothstep(0.5, 0.85, under.y), 0, 0.0);
		} else {
			c = cand(M_ARM, max(under.lv, 0.5) + 1.0 / 6.0, 0, 0.0);
		}
		return true;
	}
	float tex = fbmL(d / R * 6.0, bR * 6.0, OCT);
	float emb = clamp((dens - darkDens(d + dc * R * 0.07, i, bR)) * 3.0, -1.0, 1.0);
	if (lit) {
		c = cand(M_BILLOW, 0.4 + 0.1 * tex, 201, auxOf(vec2(0.0, -1.0), true));
		return true;
	}
	if (warmBack) {
		c = cand(M_DARK, 0.62 - 0.4 * smoothstep(0.65, 1.4, dens) + 0.08 * tex + 0.12 * emb, 201, auxOf(vec2(0.0, -1.0), true));
		return true;
	}
	c = cand(M_HALO, 0.36 - 0.3 * smoothstep(0.6, 1.5, dens) + 0.08 * tex + 0.12 * emb, 201, auxOf(vec2(0.0, -1.0), true));
	return true;
}

// ------------------------------------------------------------------ the sky
// the sky behind, at infinity (`chart_bg.gdshaderinc`), painted: far galaxies as
// little sprites (a warm core, blue arms), three depths of stars sliding by
// depth as you pan. NO FAR NEBULAE, as the showcase's prototype had none: drawn
// as a dithered navy tint with navy-and-plum wisps they read close in as dark
// hooks and blobs with no light, and Jon did not "understand these nebula
// shapes". Shown three ways on Oct 6 (the clouds as glowing gas, as dust lit
// from behind, and the prototype's sky with no far nebulae), he chose the
// prototype's: "C is the best."
// THE FAR SKY, PAINTED FULL BUT QUIET (Jon: the galaxies "kinda too simple and
// space looks empty"). Little galaxies at two depths, each a 2-4 tone sprite of
// one of four kinds -- a spiral's warm core and blue arms, a barred spiral, an
// edge-on disc with its bulge, a round or oval elliptical in banded peach --
// with a sparkle at its heart; and the stars in tiers, the near bright ones a
// plus and the rarest a four-point sparkle. All of it slides by its depth as
// you pan (`chart_bg`'s `bgAt`) and is marked (sid 251) so the paint pass's
// cleanups leave its single blocks alone.
const int SID_FAR = 251;

// a little galaxy of a tier at sp, or none (found: c.m != M_SKY)
Cand farGalaxy(vec2 sp, float f, float cellPx, float prob, vec2 sizeR, int salt) {
	vec2 q = bgAt(sp, f);
	ivec2 c0 = ivec2(floor(q / cellPx));
	Cand c = cand(M_SKY, 0.0, 0, 0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 cc = c0 + ivec2(i, j);
			vec3 h = kitHash3(cc + ivec2(salt * 131, salt * 17 + 5));
			if (h.z > prob) {
				continue;
			}
			vec3 g = kitHash3(cc + ivec2(salt * 7 + 77, 919));
			// its middle on the block grid, so it stands crisp
			vec2 ctr = (floor(((vec2(cc) + 0.2 + 0.6 * h.xy) * cellPx) / 2.0) + 0.5) * 2.0;
			float size = mix(sizeR.x, sizeR.y, g.x * g.x);
			vec2 d = q - ctr;
			if (dot(d, d) > 4.0 * size * size) {
				continue;
			}
			if (dot(d, d) < 1.0) {
				// the sparkle at its heart
				return cand(M_STARW, 0.75 + 0.2 * h.x, SID_FAR, 0.0);
			}
			int kind = int(g.y * 4.0);
			float an = floor(g.z * 8.0) * 0.3927;
			vec2 e = vec2(cos(an) * d.x + sin(an) * d.y, -sin(an) * d.x + cos(an) * d.y);
			float tilt = 0.35 + 0.55 * fract(g.z * 13.7);
			if (kind == 3) {
				// an elliptical: an oval of banded peach on a plum glow
				float r = length(vec2(e.x, e.y / (0.55 + 0.4 * fract(g.x * 7.1)))) / size;
				if (r < 0.35) {
					return cand(M_BULGE, 0.8, SID_FAR, 0.0);
				}
				if (r < 0.7) {
					return cand(M_BALL, 0.7, SID_FAR, 0.0);
				}
				if (r < 1.05) {
					return cand(M_BALL, 0.5, SID_FAR, 0.0);
				}
				if (r < 1.35) {
					return cand(M_HALO, 0.7, SID_FAR, 0.0);
				}
				continue;
			}
			if (kind == 2) {
				// edge on: a thin blue disc, its bulge warm across the middle
				float r = length(vec2(e.x, e.y / 0.16)) / size;
				if (r < 1.0) {
					float rb = length(vec2(e.x, e.y / 0.5)) / size;
					if (rb < 0.3) {
						return cand(M_BULGE, 0.75, SID_FAR, 0.0);
					}
					return cand(M_ARM, r < 0.6 ? 0.55 : 0.36, SID_FAR, 0.0);
				}
				continue;
			}
			// a spiral, barred or not, seen tilted
			vec2 t = vec2(e.x, e.y / tilt);
			float r = length(t) / size;
			if (r > 1.2) {
				continue;
			}
			bool bar = kind == 1;
			if (r < 0.25 || (bar && abs(t.x) < 0.55 * size && abs(t.y) < 0.14 * size)) {
				return cand(M_BULGE, r < 0.15 ? 0.85 : 0.62, SID_FAR, 0.0);
			}
			float th = atan(t.y, t.x);
			float arms = 0.5 + 0.5 * cos(2.0 * (th - 2.4 * log(max(r, 0.08))) + g.x * 9.0);
			if (arms > 0.55 && r < 1.0 && (!bar || r > 0.45)) {
				return cand(M_ARM, r < 0.6 ? 0.55 : 0.36, SID_FAR, 0.0);
			}
			if (r < 0.75) {
				return cand(M_HALO, 0.7, SID_FAR, 0.0);
			}
		}
	}
	return c;
}

// a near star bright enough to draw as a sprite, at sp (its block centre)
bool brightStar(vec2 sp, float above) {
	vec4 s = bgStar(sp, 2);
	return s.x > 0.5 && s.y > above;
}

Cand skyAt(Px P, float Ehalo) {
	vec2 sp = u_vp_origin + (vec2(P.blk) + 0.5) * 2.0 - 0.5 * u_res;
	float hl = Ehalo;
	Cand c = cand(M_SKY, hl < 0.0019 ? 0.0 : (hl < 0.0042 ? 0.45 : 0.8), 0, 0.0);
	// the little galaxies, near over far
	Cand gn = farGalaxy(sp, 0.07, 150.0, 0.55, vec2(6.0, 15.0), 3);
	if (gn.m != M_SKY) {
		return gn;
	}
	Cand gf = farGalaxy(sp, 0.035, 70.0, 0.45, vec2(2.5, 5.5), 11);
	if (gf.m != M_SKY) {
		return gf;
	}
	if (hl < 0.006) {
		vec4 s2 = bgStar(sp, 2);
		if (s2.x > 0.5) {
			return cand(s2.z > 0.7 ? M_STAR : (s2.z < 0.3 ? M_STARW : M_ARM), 0.3 + 0.5 * s2.y * s2.y, SID_FAR, 0.0);
		}
		// THE NEAR STARS' SPRITES: a plus round the bright ones, and round the
		// brightest a four-point sparkle, arms two blocks long
		for (int k = 0; k < 4; k++) {
			vec2 o = k == 0 ? vec2(2.0, 0.0) : (k == 1 ? vec2(-2.0, 0.0) : (k == 2 ? vec2(0.0, 2.0) : vec2(0.0, -2.0)));
			if (brightStar(sp + o, 0.72)) {
				return cand(M_STAR, 0.3, SID_FAR, 0.0);
			}
			if (brightStar(sp + 2.0 * o, 0.9)) {
				return cand(M_STAR, 0.05, SID_FAR, 0.0);
			}
		}
		vec4 s1 = bgStar(sp, 1);
		if (s1.x > 0.5) {
			return cand(s1.z > 0.75 ? M_STARW : M_ARM, s1.z > 0.75 ? 0.05 : 0.17 + 0.2 * s1.y, SID_FAR, 0.0);
		}
		vec4 s0 = bgStar(sp, 0);
		if (s0.x > 0.5 && s0.y > 0.4) {
			return cand(M_ARM, 0.17, SID_FAR, 0.0);
		}
	}
	return c;
}

// the currents: the clumps of gas and stars stream along the arms (a flat
// rotation curve less the arms' pattern speed, two phases so nothing stretches)
float flowOm(float r) {
	const float v0 = 0.0021;
	return -(v0 / max(r, 0.06) - v0 / 0.55);
}
float flowFbm(vec2 g, float scale, vec2 off, float blk, int oct) {
	float om = flowOm(length(g));
	float tt = u_flow + 20.0 * kitVnoise2(g * 2.5 + 3.3);
	vec3 fp = kitFlowPhase(tt, 20.0);
	vec2 pa = kitRot(om * fp.x * 20.0) * g, pb = kitRot(2.1 + om * fp.y * 20.0) * g;
#if LOW
	return fbmL(pa * scale + off, blk * scale, oct);
#else
	float a = fbmL(pa * scale + off, blk * scale, oct), b = fbmL(pb * scale + off, blk * scale, oct);
	float w = fp.z, nrm = inversesqrt((1.0 - w) * (1.0 - w) + w * w);
	return (a * (1.0 - w) + b * w) * nrm;
#endif
}

// ------------------------------------------------------------------ an elliptical's form
// A ROUND GALAXY PAINTED AS A LIT BALL, not as rings of flat bands (the way B
// would hand-paint one): its bands pushed toward the light on the upper left
// and away from it on the lower right, as a sphere's are, and its band edges
// gathered into a few big mottled lobes. What it adds to the ball's level,
// strongest in its body and gone at its centre's cusp and its rim.
float ballForm(vec2 v, float k, float bs, float blk) {
	vec2 eb = vec2(v.x, v.y / u_g2.z) / (k * bs);
	float re = length(eb) / 1.1;
	vec3 nb = vec3(eb / 1.1, sqrt(max(1.0 - re * re, 0.0)));
	float sh = dot(nb, vec3(-0.5735, -0.6257, 0.5292));
	float lob = fbmL(eb * 2.6 + u_g3.w * 7.0, blk / bs * 2.6, 2);
	return (0.2 * sh + 0.1 * lob) * smoothstep(1.25, 0.3, re) * smoothstep(0.02, 0.12, re);
}

// ------------------------------------------------------------------ the scene behind the hole
Cand scene(Px P, vec2 v, ivec2 sblk, bool lensed) {
	float k = u_k;
	float blk = blockView() / k;
	vec2 q0 = vec2(v.x, v.y / KIT_TILT) / k;
	vec2 g = kitRot(-u_phi) * q0;
	vec2 dg = kitRot(-u_phi) * vec2(0.0, 2.43418);
	float r = length(g);
	bool ellip = u_g3.x > 0.5;
#if LOW
	bool low = true;
#else
	bool low = false;
#endif
	float tt = u_time * (u_g4.z > 0.5 ? 0.5 : 1.0);

	float ar = 0.0, dp = 0.0, wp = 1.0, al = 0.0, prof = 0.0;
	if (!ellip && u_g1.y > 0.0) {
		armGeom(g, ar, dp, wp, al);
		prof = armProfile(dp, wp) * u_g1.y;
		if (floor((al - ar * 11.0) / 23.7 + 0.5) > 0.5) {
			prof *= u_g6.w;
		}
	}
	float seg = ellip ? 1.0 : 0.6 + 0.4 * kitSnoise2(vec2(al * 0.42, 3.1));
	if (u_g8.z > 0.0) {
		// chaos: whole stretches of arm missing, others bright
		seg *= mix(1.0, 0.25 + 0.95 * smoothstep(-0.35, 0.45, kitSnoise2(g * 3.4 + 1.9)), clamp(u_g8.z * 2.2, 0.0, 1.0));
	}
	if (!ellip && u_g7.w > 0.0 && u_g1.y > 0.0) {
		bool armB = floor((al - ar * 11.0) / 23.7 + 0.5) > 0.5;
		float rc = armB ? u_g7.y : u_g7.x;
		seg *= 1.0 - u_g7.w + u_g7.w * 1.6 * exp(-sq((ar - rc) / u_g7.z));
	}
	float lane = 0.0, laneS = 0.0, lip = 0.0;
	if (!ellip && u_g1.z > 0.0 && u_g1.y > 0.0) {
		float lw = (0.0075 + 0.008 * r) * (0.7 + 0.6 * kitVnoise2(vec2(al * 0.9, 3.0)));
		float lc = (0.86 + 0.2 * kitSnoise2(vec2(al * 0.5, 7.0))) * wp + 0.3 * lw;
		float brk = smoothstep(0.3, 0.46, kitVnoise2(vec2(al * 1.4, 11.0)));
		float dd = abs(dp - lc) / lw;
		float fe = flowFbm(g, 60.0, vec2(0.0), blk, 3);
		float win = brk * u_g1.z * smoothstep(0.03, 0.065, r) * smoothstep(0.72, 0.5, r);
		// no lanes inside a bar: there every ridge is the bar's straight line, and the
		// lane rule would lay the whole bar zone down as one dust plate
		if (u_g0.z > 0.0) {
			win *= smoothstep(u_g0.z * 0.95, u_g0.z * 1.15, r);
		}
		lane = (1.0 - smoothstep(0.75, 1.15, dd - 0.22 * fe * step(dp, lc))) * win;
		laneS = (1.0 - smoothstep(0.75, 1.15, dd)) * win;
		lip = step(lc, dp) * smoothstep(1.0, 1.25, dd) * smoothstep(2.4, 1.8, dd) * win;
	}
	float Ed, EdS, warmD;
	if (!ellip) {
		float env = 0.42 * exp(-r / 0.28) + 0.022 * exp(-r / 0.75);
		float taper = smoothstep(1.2, 0.78, r + 0.10 * fbmL(g * 4.0, blk * 4.0, low ? 2 : 5) - 0.12 * prof);
		float clump = flowFbm(g, 11.0, vec2(5.0), blk, low ? 2 : 4);
		float fine = low ? 0.0 : flowFbm(g, 46.0, vec2(9.0), blk, 3);
		float inner = 0.25 + 0.75 * smoothstep(0.04, 0.24, r);
		float Sx = prof * smoothstep(0.26, 0.07, r) * smoothstep(0.0, 0.025, r);
		float clumpS = fbmL(g * 11.0 + 5.0, blk * 11.0, 2);
		Ed = env * (0.28 + 1.9 * prof * seg) * (1.0 + 0.3 * clump + 0.22 * fine) * taper * inner;
		Ed += u_g5.x * Sx * (1.0 + 0.15 * clumpS);
		EdS = env * (0.28 + 1.9 * prof * seg) * (1.0 + 0.3 * clumpS) * taper * inner + u_g5.x * Sx * (1.0 + 0.15 * clumpS);
		if (u_g0.z > 0.0) {
			float dperp = abs(dot(g, vec2(-sin(u_g1.x), cos(u_g1.x))));
			// a ridge of old light, widening and fading toward its ends (C's bar), never a beam
			float dpar = abs(dot(g, vec2(cos(u_g1.x), sin(u_g1.x)))) / max(u_g0.z, 0.05);
			float barL = 0.4 * exp(-sq(dperp / (0.028 + 0.03 * dpar))) * smoothstep(1.05, 0.3, dpar) * (1.0 + 0.3 * clumpS);
			Ed += barL;
			EdS += barL;
		}
		// a tidal stream flung off one side (the game's own: -0.9 to 0.8 rad as it
		// runs from 0.55 to 2.05 gu out)
		if (u_g8.w > 0.5 && r > 0.45 && r < 2.2) {
			float t = clamp((r - 0.55) / 1.5, 0.0, 1.0);
			float dth = (mod(atan(g.y, g.x) - (-0.9 + t * 1.7) + PI_B, TAU_B) - PI_B) / (0.5 * (0.10 + t * 0.30));
			float tl = 0.012 * exp(-dth * dth * 1.6) * (1.0 - 0.7 * t) * (1.0 + 0.4 * fbmL(g * 6.0, blk * 6.0, 2));
			Ed += tl;
			EdS += tl;
		}
		warmD = smoothstep(max(u_g4.w, u_g0.z * 0.7), 0.04, r);
	} else {
		Ed = 0.0;
		EdS = 0.0;
		warmD = 1.0;
	}

	float R = u_g2.y;
	float rho = length(vec2(v.x, v.y / u_g2.z)) / k;
	rho *= 1.0 + 0.07 * fbmL(g * 9.0 + 2.0, blk * 9.0, 2);
	// the ball: a broad warm glow and a small cusp, its size and brightness the kind's
	float bs = u_g8.x / 0.30;
	float rb = rho / bs;
	float Ib = ellip ? u_g8.y * (0.6 * pow(1.0 + sq(rb / 0.13), -1.2) * smoothstep(1.3, 0.75, rb) + 0.45 * exp(-sq(rb / 0.012))) * (1.0 + 0.16 * fbmL(g * 26.0 + 3.0, blk * 26.0, 4))
		: u_g5.y * pow(1.0 + sq(rho / (u_g5.z * R)), -1.05) * exp(-sq(rho / (u_g5.w * R)));
	float hR = u_g3.z;
	float rp = length(vec2(v.x, v.y / 0.5)) / k;
	float clearZ = smoothstep(1.5, 5.0, u_zoom);
	float adapt = 120.0 * clearZ * sqrt(clearZ);
	float clearK = clearZ * exp(-sq(rho / (1.6 * u_g4.x)));
	float holeL = 1.0 / (1.0 + sq(rp / (0.9 * hR)));
	float sw = 0.5 + 0.5 * sin(2.0 * atan(g.y, g.x) + 6.0 * log(max(r, 1e-3)) + tt * TAU_B / 120.0 + 0.55 * fbmL(g * 40.0, blk * 40.0, 2));
	float ff = 0.5 - 0.5 * clamp(q0.y / (0.9 * R), -1.0, 1.0);
	float T = 1.0 - 0.8 * lane;
	float Ew = Ib * (ff + (1.0 - ff) * T) + Ed * warmD * T;
	float streams = clearK * holeL * (0.003 + 0.075 * sw * sw * sw);
	float Ec = Ed * (1.0 - warmD) * T;
	float TS = 1.0 - 0.8 * laneS;
	float EwS = Ib * (ff + (1.0 - ff) * TS) + EdS * warmD * TS, EcS = EdS * (1.0 - warmD) * TS;

	float Ep = 0.0;
	float bub = u_ncl > 0 ? bubbleAt(v) : 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= u_ncl) {
			break;
		}
		int kd = int(u_ck[i].x + 0.5);
		if (kd > 1) {
			continue;
		}
		float cl = cloudLight(v, i);
		if (kd == 0) {
			Ep = max(Ep, cl * Ed * 2.4 * (1.0 - 0.75 * bub));
		} else {
			Ec += cl * Ed * 1.1;
			EcS += cl * EdS * 1.1;
		}
	}
	float shade = 0.0;
	if (!ellip && !low && r > 0.06) {
		float Mh = massTab(g), Mi = massTab(g - normalize(g) * 0.024);
		shade = smoothstep(0.12, 0.4, Mi - 0.7 * Mh);
	}

	Cand sc;
	float Ehalo = (ellip ? 0.0085 * u_g8.y * bs : 0.0068) * exp(-max(r - (ellip ? 0.55 * bs : 0.74), 0.0) / 0.26) * (1.0 + 0.4 * fbmL(g * 3.0, blk * 3.0, low ? 2 : 5));
	Ew += streams;
	float Et = Ew + Ec + Ep;
	bool galaxy = Et > 0.0062;
	float EwA = mix(Ew, EwS, clearZ);
	float EL = Et / (1.0 + EwA * adapt) + streams;
	bool warmSide = false;
	if (!galaxy) {
		sc = skyAt(P, Ehalo + Et * 0.5);
		// AN ELLIPTICAL'S SOFT HALO, as a pixel artist paints one: the ball's
		// outermost violet stepped out into the sky in an ordered dither, thick
		// at its edge and thinning to nothing, never a hard rim
		if (ellip && sc.m == M_SKY && pat(P, 0.75 * smoothstep(0.0012, 0.0062, Et))) {
			sc = cand(M_BALL, 0.2, 0, 0.0);
		}
	} else {
		float wf = (EwS + streams) / max(EwS + streams + EcS + Ep, 1e-6);
		warmSide = wf > 0.5;
		if (warmSide && !ellip) {
			// a dim warm fringe goes over to the cool side: the bulge's bottom band
			// never lies as a flat maroon plate with a hard rim (a barred kind's
			// whole bar zone is warm and dim)
			float ELw0 = (mix(Ew, EwS, clearZ) + 0.35 * (Ec + Ep)) / (1.0 + EwA * adapt) + streams;
			float lv0 = clamp(1.0 + log2(ELw0) / 7.0, 0.0, 0.999);
			warmSide = wf > 0.5 + 0.38 * smoothstep(0.42, 0.2, lv0);
		}
		if (warmSide) {
			int m = (ellip && Et < 0.06) ? M_BALL : M_BULGE;
			float ELw = (mix(Ew, EwS, clearZ) + 0.35 * (Ec + Ep)) / (1.0 + EwA * adapt) + streams;
			float lvb = (m == M_BALL) ? clamp((log2(ELw) + 7.4) / 3.6, 0.0, 0.83) : clamp(1.0 + log2(ELw) / 7.0, 0.0, 0.999);
			if (ellip) {
				lvb = clamp(lvb + ballForm(v, k, bs, blk), 0.0, m == M_BALL ? 0.83 : 0.999);
			}
			sc = cand(m, lvb - 0.1 * shade, 0, 0.0);
		} else {
			float ELc = (Ec + Ep + 0.35 * Ew) / (1.0 + EwA * adapt);
			float la = 1.08 + log2(ELc) / 6.2 - 0.12 * shade - 0.34 * bub;
			bool pink = Ep > 0.7 * Ec;
			sc = cand(pink ? M_KNOT : M_ARM, pink ? 0.96 + log2(ELc) / 5.0 - 0.12 * shade : la, 0, 0.0);
			if (!pink && la < 1.0 / 6.0) {
				sc = cand(M_SKY, 0.8, 0, 0.0);
			}
		}
		// the hand-over band where warm meets cool: a band, so only out where the
		// bulge's own light is fading (a broad-armed kind evens warm and cool over
		// the whole bar zone, and it would lie there as one plate), its edges dithered
		if (!ellip && wf > 0.5 - u_g6.x && wf < 0.5 + u_g6.y && Ep < 0.5 * Ec + 0.01 && warmD < 0.36) {
			float ELd = (Ew + Ec) / (1.0 + EwA * adapt) + streams;
			float ld = u_g6.z + log2(ELd) / 6.0 - 0.1 * shade;
			if (ld > 0.34 && pat(P, smoothstep(0.34, 0.42, ld) * smoothstep(0.36, 0.2, warmD))) {
				sc = cand(M_BILLOW, ld, 0, 0.0);
			}
		}
		if (!ellip && Et < 0.012 && !warmSide) {
			float a = smoothstep(0.0062, 0.012, Et);
			if (!pat(P, a * 0.9 + 0.1)) {
				sc = skyAt(P, Ehalo + Et * 0.5);
			}
		}
	}

	bool laneLit = galaxy && EL > 0.03;
	bool laneShown = lane > 0.5 && Ib * ff < 0.09 && laneLit;
	if (laneShown) {
		if (warmSide) {
			sc = cand(M_DUST, 0.3 + 0.5 * smoothstep(0.5, 1.0, lane), 250, auxOf(dirTo(v, vec2(0.0)), true));
		} else {
			sc = cand(M_HALO, 0.25 + 0.45 * (1.0 - smoothstep(0.5, 1.0, lane)), 250, auxOf(dirTo(v, vec2(0.0)), true));
		}
	} else if (lip > 0.5 && galaxy && !warmSide && sc.m == M_ARM) {
		sc = cand(M_ARM, sc.lv + 1.0 / 6.0, 0, 0.0);
	}
	// the supernova's light echo: a ring stepping out through the gas and dust,
	// one block wide, lit in the flare's colours a step at a time
	if (u_echo.w > 0.5 && galaxy) {
		float de = abs(length(g - u_echo.xy) - u_echo.z);
		if (de < blk * 0.9 && (sc.m == M_ARM || sc.m == M_DUST || sc.m == M_HALO || sc.m == M_BILLOW || sc.m == M_KNOT)) {
			sc = cand(M_BILLOW, 0.5 + 0.16 * u_echo.w, 0, 0.0);
		}
	}
	// knots: pink star-forming clumps and blue young clusters along the arms'
	// bright band; each breathes in three held poses, and now and then one blooms
	if (!ellip && galaxy && !laneShown && u_g1.y > 0.0) {
		const float ks = 0.03;
		ivec2 kc0 = low ? ivec2(floor(g / ks - 0.5)) : ivec2(floor(g / ks));
		int k0 = low ? 0 : -1;
		for (int j = k0; j <= 1; j++) {
			for (int i = k0; i <= 1; i++) {
				ivec2 c = kc0 + ivec2(i, j);
				vec3 h = kitHash3(c + ivec2(5113, 911));
				vec2 ctr = (vec2(c) + 0.15 + 0.7 * h.xy) * ks;
				float rr = length(ctr);
				if (rr < 0.1 || rr > 0.95) {
					continue;
				}
				float A = armAt(ctr);
				if (h.z > 0.2 * A * A * A) {
					continue;
				}
				float typ = fract(h.z * 37.0), sz = fract(h.z * 91.0);
				bool blue = typ < 0.35;
				vec2 kv = toView(ctr, 0.0);
				// breathing: three held poses on a 20-60 s cycle
				float per = 20.0 + 40.0 * fract(h.x * 13.0);
				float br = 0.5 + 0.5 * sin(TAU_B * u_time / per + h.y * 40.0);
				float pose = floor(br * 2.999) - 1.0;                 // -1, 0, +1
				// a bloom: every 8 s a few knots swell two poses for a while
				float bloom = 0.0;
				if (u_wxOn > 0.5) {
					float n0 = floor(u_time / 8.0);
					for (int s = 0; s < 3; s++) {
						float n = n0 - float(s);
						if (kitHash1(c + ivec2(int(n) * 7 + 17, 3301)) < 0.012) {
							float tau = u_time - 8.0 * n;
							bloom = max(bloom, tau < 3.0 ? 1.0 : (tau < 7.0 ? 2.0 : (tau < 17.0 ? 1.0 : 0.0)));
						}
					}
				}
				if (sz > 0.86) {
					float s = spriteAt(P, kv, (u_zoom > 0.75 || bloom > 1.5) ? 2 : 1);
					if (s > 0.0) {
						sc = cand(blue ? M_STAR : M_STARP, s, 0, 0.0);
						continue;
					}
				}
				float rk0 = (0.0018 + 0.0048 * sz * sz) * k * u_zoom * (1.0 + 0.12 * pose + 0.3 * bloom);
				float rk = clamp(rk0, 1.0, 7.0);
				vec2 dv = (v - kv) * u_zoom;
				float dd = length(dv) / rk;
				float open = smoothstep(3.0, 6.0, rk0);
				dd += open * 0.3 * kitSnoise2(dv / rk * 1.6 + h.xy * 50.0);
				if (dd < 1.0) {
					float core = 1.0 - dd;
					if (open > 0.5 && dd > 0.55 && !pat(P, 0.5)) {
						continue;
					}
					float lift = 0.08 * pose + 0.12 * bloom;
					Cand kn = cand(blue ? M_STAR : M_KNOT, (blue ? 0.2 + 0.55 * core * (1.0 - 0.5 * open) : 0.3 + 0.75 * pow(core, 0.8) * (1.0 - 0.35 * open)) + lift, 0, 0.0);
					if (open > 0.5) {
						vec4 ms = planeStar(g, v, 0.0016, 0.45 * KIT_TILT, 41);
						if (ms.x > 0.5) {
							kn = cand(blue ? M_STAR : M_STARP, 0.55 + 0.4 * ms.y, 0, 0.0);
						}
					}
					if (kn.y > sc.y - 0.1) {
						sc = kn;
					}
				}
			}
		}
	}
	if (clearZ > 0.02 && warmSide && !laneShown) {
		vec4 cs = planeStar(g, v, 0.0032, clamp(Ib * 1.6, 0.0, 0.85) * clearZ * KIT_TILT, 21);
		if (cs.x > 0.5) {
			Cand st = cand(cs.y < 0.7 ? M_STARW : M_STAR + 2, 0.3 + 0.55 * cs.w, 0, 0.0);
			if (st.y > sc.y + 0.04) {
				sc = st;
			}
		}
	}
	if (u_zoom > 1.6 && galaxy && !warmSide && !laneShown && !ellip) {
		float zf = smoothstep(1.6, 3.5, u_zoom);
		vec4 ds = planeStar(g, v, 0.006, clamp(EdS * 4.0, 0.0, 0.5) * zf * KIT_TILT, 33);
		if (ds.x > 0.5) {
			Cand st = cand(M_STAR, 0.1 + 0.45 * ds.w * ds.w, 0, 0.0);
			if (st.y > sc.y + 0.03) {
				sc = st;
			}
		}
	}
	if (!ellip && sc.m == M_SKY && u_zoom > 1.4) {
		float dh = clamp((Ehalo + Et) * 5.0, 0.0, 0.05) * smoothstep(1.4, 3.2, u_zoom);
		vec4 h4 = planeStar(g, v, 0.0045, dh, 57);
		if (h4.x > 0.5) {
			sc = cand(h4.y < 0.22 ? M_STARW : M_STAR, h4.y < 0.22 ? 0.1 + 0.2 * h4.z : 0.06 + 0.4 * h4.z * h4.z, 0, 0.0);
		}
	}
	bool solid = false;
	if (u_ncl > 0) {
		for (int i = 0; i < 12; i++) {
			if (i >= u_ncl) {
				break;
			}
			int kd = int(u_ck[i].x + 0.5);
			Cand cc;
			if (kd == 0 && emissionAt(P, v, i, blk, bub, cc)) {
				sc = cc;
				solid = solid || cc.m == M_PILLAR;
			}
			if (kd == 1 && reflectionAt(P, v, i, blk, bub, sc, cc)) {
				sc = cc;
			}
		}
		for (int i = 0; i < 12; i++) {
			if (i >= u_ncl) {
				break;
			}
			int kd = int(u_ck[i].x + 0.5);
			Cand cc;
			if (kd == 3 && remnantAt(v, i, blk, sc, cc)) {
				sc = cc;
			}
			if (kd == 2 && planetaryAt(P, v, i, blk, cc)) {
				sc = cc;
			}
			if (kd == 4 && darkAt(v, i, blk, sc, cc)) {
				sc = cc;
				solid = true;
			}
		}
	}
	bool billowFront = false;
	// (the billows stand at every zoom: the showcase let them go above zoom 4,
	// and the gas that vanished as you zoomed in read as detail lost, Jon)
	if (!ellip && !low && u_g1.w >= 0.2) {
		Puff p;
		billows(g, dg, tt, p);
		if (p.id > 0.0 && p.h > -1e8) {
			float a;
			Cand pc = shadePuff(p, dg, a);
			if (pat(P, a)) {
				sc = pc;
				billowFront = true;
			}
		}
	}
	// stars: the sparkle sprites, unless something solid stands in front
	if (u_stars_on && sblk.x >= 0 && sblk.y >= 0 && sblk.x < int(u_vp_size.x) && sblk.y < int(u_vp_size.y)) {
		vec4 sb = texelFetch(u_stars, sblk, 0);
		if (sb.a > 0.5 && !billowFront && !solid) {
			int cls = clamp(int(sb.g * 4.0 + 0.5), 0, 3);
			float lv = sb.r;
			if (laneShown) {
				lv *= 0.55;
			}
			Cand st = cand(M_STAR + cls, lv, 0, 0.0);
			if (lv > 0.05 && st.y > sc.y + 0.04) {
				sc = st;
			}
		}
	}
	return sc;
}

// the supernova, in four drawn frames: a spark, the full four-point star with
// its long arms and glints, then shorter and dimmer, then a plus fading out
Cand supernovaSprite(Px P, Cand sc) {
	int f = int(u_sn.z + 0.5);
	if (f <= 0) {
		return sc;
	}
	ivec2 d = P.blk - blockOf(scr(u_sn.xy));
	int ax = abs(d.x), ay = abs(d.y);
	int arm = f == 1 ? 1 : (f == 2 ? 4 : (f == 3 ? 3 : 1));
	float lv = -1.0;
	if (ax == 0 && ay == 0) {
		lv = f == 4 ? 0.62 : 0.97;
	} else if ((ax == 0 || ay == 0) && ax + ay <= arm) {
		lv = (f == 4 ? 0.4 : 0.9) - 0.16 * float(ax + ay - 1);
	} else if (f == 2 && ax == 1 && ay == 1) {
		lv = 0.6;
	} else if (f == 2 && ax == 2 && ay == 2) {
		lv = 0.3;
	}
	if (lv > 0.0) {
		return cand(M_STARW, lv, 0, 0.0);
	}
	return sc;
}

void fragment() {
	ivec2 blk = ivec2(floor(UV * u_vp_size));
	vec2 s = u_vp_origin + (vec2(blk) + 0.5) * 2.0;
	vec2 v = (s - u_cpix) / u_zoom;
	Px P = Px(blk, blk + ivec2(u_block0));
	Cand hc;
	float cov;
	bool shad;
	int hs = holeAt(v, hc, cov, shad);
	Cand sc;
	if (hs == 2 || (shad && pat(P, cov))) {
		sc = hs == 2 ? cand(M_SKY, 0.0, 0, 0.0) : hc;
	} else {
		float shadow = u_g2.w * u_k;
		vec2 S = lh_to_s(v, vec2(0.0), shadow);
		bool lensed = length(S) <= lh_dims.x * 0.97;
		// what lies behind the hole is lensed (C's bend), and squeezed dark near the shadow
		vec2 vbg = lensed ? v * lh_behind(S) : v;
		sc = scene(P, vbg, lensed ? blockOf(scr(vbg)) : blk, lensed);
		if (lensed) {
			// near the shadow the sky behind is squeezed into a thin ring: C darkens
			// it; here the squeeze would draw the banded bulge as a stack of
			// one-block rings, so where the lens packs more than two blocks of sky
			// into one it is the dark ring C draws, in the void's own steps
			float b = max(length(S), 1e-3);
			float e = 0.02;
			float rad = abs(lh_behind(S * ((b + e) / b)) * (b + e) - lh_behind(S) * b) / e;
			float sqz = max(rad, 1.0 / max(lh_behind(S), 1e-3));
			if (lh_squeeze(S) < 0.4) {
				sc = cand(M_SKY, lh_squeeze(S) < 0.15 ? 0.0 : 0.45, 0, 0.0);
			} else if (sqz > 2.5 && sc.m != M_SKY && sc.m < M_STAR) {
				// packed tight: one flat low band (C's dim smear), never a stack of rings
				sc = cand(sc.m, min(sc.lv, 1.5 / float(u_mlen[sc.m])), 0, 0.0);
			}
		}
		// the disc over it, its thin fringes as patterns, never alpha
		if (hs == 1 && pat(P, cov)) {
			sc = hc;
		}
		sc = supernovaSprite(P, sc);
	}
	COLOR = outC(sc);
}
