// THE PAINTED STAR CHART, shared by its bake and its place pass (`ChartSky`,
// style PAINTED): direction B of the Oct 5 showcase (`showcase/B/chart/common.glsl`),
// "a pixel artist's hand". The galaxy's own rolled numbers, the game's arm model
// (`MapGen.shape_angle`) and the named clouds.

#include "res://shaders/chart_kit.gdshaderinc"

uniform float u_k = 622.25;
uniform float u_phi = 0.0;
uniform vec4 u_g0;          // arms, twist, bar, spread
uniform vec4 u_g1;          // spin, arm strength, lane strength, gas
uniform vec4 u_g2;          // dust, bulge_r, bulge roundness on screen, hole shadow radius (gu)
uniform vec4 u_g3;          // ball 0/1, ball roundness, hole disc radius (gu), seed
uniform vec4 u_g4;          // core clear radius (gu), LOW path 0/1, calm 0/1, warm radius (gu)
uniform vec4 u_g5;          // bulge look: S strength, ball peak, ball core (x bulge_r), ball cut (x bulge_r)
uniform vec4 u_g6;          // warm-to-cool hand-over: width below, width above, level offset, the second arm's light
uniform vec4 u_g7;          // arm strokes: arm A bright radius, arm B bright radius, width, strength
uniform vec4 u_g8;          // ball size (re gu), ball brightness, chaos, tail 0/1
uniform int u_ncl = 0;
uniform vec4 u_cl[12];      // cloud: x, y, radius, reach (plane, gu)
uniform vec4 u_ck[12];      // cloud: kind (0 emission 1 reflection 2 planetary 3 remnant 4 dark), hollow, shape, lighting lobe
uniform vec4 u_lb[36];      // lobes: dx, dy, r (the cloud's round frame, gu)

const float PI_B = 3.14159265;
const float TAU_B = 6.2831853;
float sq(float x) { return x * x; }

// noise whose octaves fade in only once they span 3-6 blocks: band edges move,
// silhouettes stay clean, and nothing finer than a block ever shimmers
float fbmL(vec2 p, float blk, int oct) {
	float s = 0.0, a = 0.5, n = 0.0, f = 1.0;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		float w = smoothstep(3.0, 6.0, 1.0 / (f * blk));
		s += a * w * kitSnoise2(p * f + vec2(float(i) * 17.31, float(i) * -9.7));
		n += a;
		f *= 2.07;
		a *= 0.5;
	}
	return s / n;
}

// galaxy plane (gu), height h (gu) -> view px
vec2 toView(vec2 g, float h) {
	vec2 r = kitRot(u_phi) * g;
	return vec2(r.x, r.y * KIT_TILT - h * KIT_TILT_COS) * u_k;
}

// The arm model: ridge angle k 2pi/n + spin + ((r - bar)/(1 - bar)) twist,
// straight inside the bar. dp: offset across the nearest ridge, gu, + toward
// the core (the arm's inner edge).
void armGeom(vec2 p, out float r, out float dp, out float wp, out float along) {
	float n = max(u_g0.x, 1.0), tw = u_g0.y, bar = u_g0.z, sp = u_g0.w;
	r = length(p);
	float th = atan(p.y, p.x);
	// chaos: the ridge wanders (an irregular's arms are scattered and broken)
	th += u_g8.z * 1.6 * kitSnoise2(p * 2.2 + 7.3);
	bool inBar = r < bar;
	float psi = u_g1.x + (inBar ? 0.0 : (r - bar) / (1.0 - bar) * tw);
	float ph = (th - psi) * n / TAU_B;
	float f = fract(ph + 0.5) - 0.5;
	float ai = floor(ph + 0.5);
	// the bar hands over to the arms across its outer 40%: a hard switch at the
	// bar's end lays the bar zone down as a plate with a rim
	float ib = bar > 0.0 ? smoothstep(bar * 0.6, bar, r) : 1.0;
	float pitchS = mix(1.0, inversesqrt(1.0 + sq(tw * max(r, 1e-3) / (1.0 - bar))), ib);
	dp = f * TAU_B / n * r * pitchS;
	float Wr = 0.5 * (0.55 + 0.9 * r) * sp * mix(0.22, 1.0, ib) * (1.0 + 1.2 * u_g8.z);
	wp = max(Wr * r * pitchS, 0.005);
	along = r * 11.0 + mod(ai, n) * 23.7;
}
// brightness across the arm: a sharp inner (core-facing) edge where the light
// catches, a long soft outer side
float armProfile(float dp, float wp) {
	float u = dp / wp;
	return u > 0.3 ? exp(-sq((u - 0.3) / 0.5)) : exp(-sq((u - 0.3) / 1.2));
}
float armAt(vec2 p) {
	if (u_g3.x > 0.5 || u_g1.y <= 0.0) {
		return 0.0;
	}
	float r, dp, wp, al;
	armGeom(p, r, dp, wp, al);
	return armProfile(dp, wp) * u_g1.y;
}

// the arms' gas piles up in heaps: where billows rise
float massAt(vec2 c, float A, float r) {
	float m = smoothstep(-0.12, 0.5, kitSnoise2(c * 7.0 + vec2(3.7, u_g3.w * 11.0)) + 0.3 * kitSnoise2(c * 17.0 + 1.3));
	return A * m * smoothstep(0.07, 0.14, r) * smoothstep(0.86, 0.5, r);
}

// clear of the named clouds (they carry their own gas: billows stay out of them)
float cloudFree(vec2 g) {
	float f = 1.0;
	for (int i = 0; i < 12; i++) {
		if (i >= u_ncl) {
			break;
		}
		float d = length(g - u_cl[i].xy) / max(u_cl[i].z, u_cl[i].w);
		f = min(f, smoothstep(0.9, 1.5, d));
	}
	return f;
}

// clouds in their own round frame (the chart draws a cloud flattened to 0.463)
vec2 cloudFrame(vec2 v, int i) {
	vec2 cv = toView(u_cl[i].xy, 0.0);
	vec2 d = (v - cv) / u_k;
	d.y /= 0.46341;
	return kitRot(-u_phi) * d;
}
vec2 cloudToView(int i, vec2 d) {
	vec2 e = kitRot(u_phi) * d;
	e.y *= 0.46341;
	return toView(u_cl[i].xy, 0.0) + e * u_k;
}
float cloudBound(int i) {
	float b = u_cl[i].z;
	for (int j = 0; j < 3; j++) {
		vec4 L = u_lb[i * 3 + j];
		if (L.z <= 0.0) {
			continue;
		}
		b = max(b, length(L.xy) + 1.25 * L.z);
	}
	return b + 0.4 * u_cl[i].z;
}
float lobeField(vec2 d, int i) {
	float s = 0.0;
	for (int j = 0; j < 3; j++) {
		vec4 L = u_lb[i * 3 + j];
		if (L.z <= 0.0) {
			continue;
		}
		vec2 e = (d - L.xy) / L.z;
		s += exp(-2.4 * dot(e, e));
	}
	return s;
}
