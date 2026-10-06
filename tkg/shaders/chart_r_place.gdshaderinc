// THE RADIANT STAR CHART, the place pass (`ChartRadiant`, style RADIANT): one
// fragment per 2x2 block, linear HDR out. Direction A of the Oct 5 showcase,
// "Light through gas" (`showcase/A/chart/place.glsl`): the galaxy as a lit
// volume. Per block one view ray crosses the tilted galaxy (orthographic, the
// plane's tilt 0.38), front to back: the front half of the slab -> the disc
// plane (stars, dust, knots: exact at h = 0) -> the back half. The bulge is
// integrated analytically and split at the plane, so the near side's dust
// lanes cross it in silhouette. Billows, the god-ray haze and the named clouds
// are marched as media: they glow, they scatter the light of the core, the
// arms and the clouds, and dust in them reddens and stops light.
//
// SIMPLIFIED's black hole (`legacy_hole.gdshaderinc`, its shape and
// perspective) is drawn over a lensed copy of the volume behind it, and its
// disc is a lamp that lights the core's gas orange.
//
// SIMPLIFIED's animations, as light: the gas streams through the arms (two
// cross-fading phases), the knots breathe and bloom as lamps on the arms'
// fronts, a supernova is a flash of light the gas round it scatters and its
// echo a ring of light sweeping through the dust, and lightning in a cloud
// lights the gas round the stroke from within. All pure functions of the clock.
//
// LOW (GRAPHICS LOW): no billow volume (one lit sheet over the arms), the
// clouds in 6 steps, one flow phase. Units are the showcase's: view px at zoom 1
// with u_k = 622.25 px a galaxy unit; `ChartSky` hands over an effective zoom.

#include "res://shaders/chart_r_common.gdshaderinc"
#include "res://shaders/legacy_hole.gdshaderinc"
#include "res://shaders/chart_bg.gdshaderinc"

uniform sampler2D u_discA : filter_linear_mipmap, repeat_disable;
uniform sampler2D u_discB : filter_linear_mipmap, repeat_disable;
uniform sampler2D u_hor : filter_linear, repeat_enable;
uniform sampler2D u_stars : filter_nearest, repeat_disable;
uniform sampler2D u_knotMap : filter_nearest, repeat_disable;
uniform bool u_stars_on = true;
uniform vec2 u_vp_size = vec2(330.0, 220.0);
uniform vec2 u_vp_origin = vec2(-2.0);
uniform vec2 u_cpix = vec2(327.0, 214.0);
uniform vec2 u_res = vec2(655.0, 429.0);
uniform vec2 u_block0 = vec2(0.0);
uniform float u_zoom = 0.42;
uniform float u_k = 622.25;
uniform float u_time = 0.0;
uniform float u_phi = 0.0;
uniform float u_ext = 1.3;
uniform float u_rmax = 1.3;
uniform float u_H0 = 0.11;
uniform float u_drift = 1.0;
uniform float u_wxOn = 1.0;
uniform float u_exp = 1.0;
uniform float u_burn = 3.0;
uniform bool u_tone_out = false;
uniform vec3 u_bCore = vec3(1.0, 0.6, 0.26);
uniform vec3 u_bInner = vec3(1.0, 0.82, 0.55);
uniform vec3 u_bOuter = vec3(0.95, 0.45, 0.17);
uniform vec3 u_youngCol = vec3(0.38, 0.53, 0.96);
uniform vec3 u_oldIn = vec3(1.0, 0.82, 0.6);
uniform vec3 u_oldOut = vec3(0.45, 0.56, 1.0);
uniform vec3 u_amb = vec3(0.02, 0.016, 0.04);
uniform vec4 u_bulge = vec4(0.04, 0.13, 0.83, 0.02);   // inner scale, outer scale, c/R, cavity scale (gu)
uniform vec4 u_bulgeI = vec4(1.5, 1.0, 0.3, 1.6);      // inner peak, outer peak, cavity peak, core light on the gas
uniform vec4 u_halo = vec4(0.026, 0.5, 0.62, 0.0);     // intensity, scale (gu), screen roundness, warmth
uniform vec4 u_discK = vec4(0.5, 1.35, 1.2, 1.0);      // old gain, young gain, H-alpha gain, dust gain
uniform vec4 u_gasK = vec4(34.0, 0.18, 0.6, 0.2);      // billow sigma, haze density, arm light gain, billow H-alpha glow
uniform vec4 u_nebK = vec4(13.0, 15.0, 7.0, 16.0);     // emission gain, reflection gain, remnant gain, dark sigma
uniform float u_steps = 22.0;
uniform float u_jitAmp = 0.5;
uniform float u_bdet = 0.35;
uniform float u_gr = 0.45;
uniform float u_kb = 0.985;
// the hole: its shadow's radius (gu) and its disc's light on the gas
uniform float u_holeR = 0.0186;
uniform vec3 u_holeLight = vec3(0.9, 0.42, 0.14);
// clouds
uniform int u_nCl = 0;
uniform vec4 u_clA[8];     // plane x, y, bounding radius, kind (0 emission, 1 reflection, 2 planetary, 3 remnant, 4 dark)
uniform vec4 u_clB[8];     // half height, shell radius, hollow, seed
uniform vec4 u_clC[8];     // ionising star / main lobe offset x, y, shape, main radius
uniform vec4 u_lobe[24];   // dx, dy (plane), r, 0 (three per cloud)
// events
uniform int u_nkn = 0;
uniform vec4 u_kn[64];     // knots: plane x, y (gu), size (gu), amplitude (breathing)
uniform vec4 u_sn = vec4(0.0);     // supernova: plane x, y, flare gain (0 = none), age
uniform vec4 u_echo = vec4(0.0);   // light echo: plane x, y, ring radius (gu), strength
uniform vec4 u_lt[8];      // lightning per cloud: envelope, plane offset x, y from the cloud (gu), radius (gu)

const vec3 HA = vec3(1.0, 0.2, 0.3);
const vec3 OIII = vec3(0.2, 0.95, 0.85);
const vec3 REFL = vec3(0.32, 0.52, 1.0);
const vec3 DUSTA = vec3(1.0, 0.62, 0.42);
const vec3 GASA = vec3(0.85, 0.80, 0.95);
const vec3 RED = vec3(0.62, 0.80, 1.0);
const vec3 FLARE = vec3(1.0, 0.79, 0.43);
const vec3 LIGHTNING = vec3(0.69, 0.63, 1.0);
const vec3 REMR = vec3(1.0, 0.16, 0.13);
const int MAXEV = 12;

// what a ray carries with it (the showcase's globals; Godot keeps none)
struct Ray {
	mat2 RG;      // view-aligned -> galaxy frame
	vec3 CAM;     // toward the camera, galaxy frame
	float FP;     // one block, in gu
	float WHI;    // the fine noise octave's weight (fades in with zoom, so nothing aliases)
	float WHI2;
	float TM;     // the gas's slow rise (time)
	vec2 DXY;     // the ray's sideways travel per unit of height, galaxy frame
	float KB;     // the eye's adaptation deep in
	int REMM;     // the remnants this ray passes through (bits)
	vec3 FL;      // the currents: phase a, phase b (0..1), b's weight
	float LA;     // how hard the hole's lens packs the picture here (log2): coarser noise
};
struct Evs {
	float h[12];
	vec3 c[12];
	float a[12];
	int n;
	int done;
};

vec2 scr(vec2 v) { return u_cpix + v * u_zoom; }
ivec2 blockOf(vec2 s) { return ivec2(floor((s - u_vp_origin) * 0.5)); }
vec2 gpan() { return (u_res * 0.5 - u_cpix) / u_zoom; }
float wxGate() { return u_wxOn * smoothstep(2.4, 3.2, u_zoom); }
float hgN(float c, float g) { float g2 = g * g; return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5); }
vec4 discA(vec2 p) { return max(abs(p.x), abs(p.y)) < u_ext * 0.995 ? texture(u_discA, kitMapUV(p, u_ext)) : vec4(0.0); }
vec4 discB(vec2 p) { return max(abs(p.x), abs(p.y)) < u_ext * 0.995 ? texture(u_discB, kitMapUV(p, u_ext)) : vec4(0.0); }

void addEvA(inout Evs EV, float h, vec3 c, float a) {
	if (EV.n < MAXEV && (max(c.r, max(c.g, c.b)) > 1e-4 || a > 1e-3)) {
		EV.h[EV.n] = h;
		EV.c[EV.n] = c;
		EV.a[EV.n] = a;
		EV.n++;
	}
}

// ------------------------------------------------------------------ bulge (analytic, exact split)
// emissivity (1 + s^2/a^2)^-2.5 on an oblate spheroid; the line integral has a
// closed form, so the bulge is a smooth gradient with no march noise. Returns
// (in front of hs, behind hs), the two adding to 1 through the centre.
vec2 bulgeComp(vec2 q0, float a, float q, float hs) {
	float ah = 5.92524 + 1.0 / (q * q);
	float be = 4.86836 * q0.y;
	float hstar = -be / (2.0 * ah);
	float smin2 = max(dot(q0, q0) - be * be / (4.0 * ah), 0.0);
	float m = 1.0 + smin2 / (a * a);
	float x0 = sqrt(ah) / a * (hs - hstar);
	float F = x0 * (2.0 * x0 * x0 + 3.0 * m) / (3.0 * m * m * pow(m + x0 * x0, 1.5));
	float half_ = 2.0 / (3.0 * m * m);
	return vec2(half_ - F, half_ + F) * 0.75;
}

// ------------------------------------------------------------------ light arriving at a point
// the core: a ball of light, shadowed by billow tops through the horizon map
vec3 coreLight(vec3 pg, out float vis) {
	float d3 = length(pg);
	float rr = length(pg.xy);
	vis = 1.0;
	if (rr > 0.05) {
		float th = atan(pg.y, pg.x);
		float hs = texture(u_hor, vec2(th / R_TAU + 0.5, min(rr / u_rmax, 0.999))).r;
		float sl = abs(pg.z) / rr;
		float soft = 0.05 / rr + 0.012;
		vis = smoothstep(hs - soft, hs + 0.5 * soft, sl);
	}
	vec3 c = mix(u_bInner, u_bOuter, smoothstep(0.05, 0.35, d3));
	return c * u_bulgeI.w / (1.0 + d3 * d3 / 0.012);
}
// the arms' own young stars (a broad blur of the disc map)
vec3 armLight(vec3 pg) {
	vec4 a = textureLod(u_discA, kitMapUV(pg.xy, u_ext), 4.5);
	return (a.r * u_oldOut * 0.35 + a.g * 1.6 * u_youngCol) * u_gasK.z / (1.0 + abs(pg.z) / 0.03);
}
// the clouds' own lamps, the hole's disc, the knots on the arms, a supernova,
// a stroke of lightning: every light that moves or comes and goes
vec3 lampLight(vec3 pg) {
	vec3 L = vec3(0.0);
	for (int k = 0; k < 8; k++) {
		if (k >= u_nCl) {
			break;
		}
		vec4 A = u_clA[k];
		int kind = int(A.w + 0.5);
		if (kind > 1) {
			continue;
		}
		vec3 c = vec3(A.xy + u_clC[k].xy, 0.0);
		vec3 dd = pg - c;
		float R = u_clC[k].w;
		vec3 col = kind == 0 ? vec3(0.9, 0.55, 0.75) * 0.8 : REFL * 0.5;
		L += col / (1.0 + dot(dd, dd) / (R * R * 0.5));
	}
	// the hole's disc, a lamp at the centre
	L += u_holeLight / (1.0 + dot(pg, pg) / 0.0014);
	// a supernova lights the gas and dust round it, fading with its flare
	if (u_sn.z > 0.0) {
		vec3 ds = pg - vec3(u_sn.xy, 0.0);
		L += FLARE * u_sn.z * 3.0 / (1.0 + dot(ds, ds) / 0.0009);
	}
	return L;
}

// ------------------------------------------------------------------ billows
// the gas rises slowly through its own noise and streams through the arms
// (`Ray.FL`, the currents' two phases): it boils and drifts, it never slides
float billowDens(in Ray R, vec3 pg, vec4 dB, float detail) {
	float G = dB.r, Hc = dB.g * (pg.z < 0.0 ? 0.5 : 1.0);
	float ah = abs(pg.z);
	if (G < 0.012 || ah > Hc * 1.5 + 0.004) {
		return 0.0;
	}
	vec3 off = pg.z < 0.0 ? vec3(0.37, 0.71, 0.13) : vec3(0.0);
	// currents: the gas turns at a flat rotation curve's rate less the arms' pattern speed
	float rr = length(pg.xy);
	float om = -(0.0021 / max(rr, 0.06) - 0.0021 / 0.55);
	// (the turn over a phase is small, under a sixth of a radian: turned to first
	// order, no sine or cosine a sample)
	vec2 perp = vec2(-pg.y, pg.x);
	vec2 pa = pg.xy + perp * (om * R.FL.x * 20.0);
	vec3 np = vec3(pa, ah - R.TM) * 9.0 + off;
	vec4 a = nz(np);
	float n = a.r + detail * R.WHI * u_bdet * a.g;
#if LOW == 0
	if (R.FL.z > 0.001 && detail > 0.5) {
		// (phase b also sits a fixed 2.1 rad round, so its noise is not phase a's)
		vec2 pb0 = pg.xy + perp * (om * R.FL.y * 20.0);
		vec2 pb = vec2(-0.5048461 * pb0.x - 0.8632094 * pb0.y, 0.8632094 * pb0.x - 0.5048461 * pb0.y);
		vec4 b = nz(vec3(pb, ah - R.TM) * 9.0 + off);
		float nb = b.r + detail * R.WHI * u_bdet * b.g;
		float w = R.FL.z;
		n = mix(n, nb, w);
		n /= sqrt((1.0 - w) * (1.0 - w) + w * w) * 0.6 + 0.4;
	}
	if (detail > 0.5 && R.WHI2 > 0.0) {
		n += R.WHI2 * 0.3 * nz(np * 4.07 + vec3(0.5, 0.2, 0.7)).g;
	}
#endif
	float top = 1.0 - ah / max(Hc, 1e-3);
	return min(G, 1.6) * smoothstep(0.04, 0.14, G) * smoothstep(0.0, 0.22, n * 0.6 + top * 0.35 - 0.2) * smoothstep(0.104, 0.08, ah);
}

// ------------------------------------------------------------------ clouds
float lobeField(int k, vec3 lp, float flt, float sharp) {
	float f = 0.0;
	for (int j = 0; j < 3; j++) {
		vec4 L = u_lobe[k * 3 + j];
		if (L.z <= 0.0) {
			continue;
		}
		vec3 dl = lp - vec3(L.xy, 0.0);
		dl.z /= flt;
		f += exp(-dot(dl, dl) / (L.z * L.z) * sharp);
	}
	return f;
}
float darkDens(in Ray R, int k, vec2 qx, float Rr, float seed, float wf, vec2 tg) {
	float f = lobeField(k, vec3(qx * Rr, 0.0), 0.29, 2.4);
	if (f < 0.03) {
		return 0.0;
	}
	vec2 qs = vec2(dot(qx, tg) * 0.55, dot(qx, vec2(tg.y, -tg.x)) * 1.5);
	vec3 np = vec3(qs * 1.4 + vec2(seed, 0.3 * seed), 5.0 + R.TM * 1.2);
	vec4 w0 = nz(np * vec3(0.5, 0.5, 1.0) + 0.13);
	vec4 a = nz(np + 0.5 * vec3(w0.a, w0.r, 0.0));
	return smoothstep(0.22, 0.8, f * (0.7 + 1.1 * (a.r + wf * a.g)));
}
// a remnant's blast has cleared its bubble: billows and an emission cloud's gas thin inside it
float remClear(in Ray R, vec3 pg) {
	float c = 1.0;
	if (R.REMM == 0) {
		return c;
	}
	for (int k = 0; k < 8; k++) {
		if (k >= u_nCl) {
			break;
		}
		if ((R.REMM & (1 << k)) == 0) {
			continue;
		}
		vec3 lp = pg - vec3(u_clA[k].xy, 0.0);
		float d = length(vec3(lp.xy, lp.z / 0.42)) / u_clB[k].y;
		c = min(c, mix(0.15, 1.0, smoothstep(0.72, 1.0, d)));
	}
	return c;
}
// one sample of cloud k: emission and in-scatter into EV, extinction into sig
void cloudSample(in Ray R, int k, vec3 pg, inout vec3 EV, inout vec3 sig, vec3 Lin, vec2 dk) {
	vec4 A = u_clA[k], B = u_clB[k], Cc = u_clC[k];
	int kind = int(A.w + 0.5);
	vec3 lp = pg - vec3(A.xy, 0.0);
	float Rr = Cc.w;
	float seed = B.w;
	if (kind == 0) {
		// EMISSION: billowing rose H-alpha round a cavity glowing OIII teal round its
		// ionising cluster, rimmed by a bright ionisation front
		float f = lobeField(k, lp, 0.29, 2.6);
		if (f < 0.02) {
			return;
		}
		float det = clamp((Rr / R.FP - 70.0) / 70.0, 0.0, 1.0);
		vec2 qx = (lp.xy - lp.z * R.DXY) / Rr;
		float hz = lp.z / (0.29 * Rr);
		vec3 np = vec3(qx * 1.15, hz * 0.35) + vec3(seed, seed * 0.7, R.TM * 2.0);
		vec4 w0 = nz(np * vec3(0.45, 0.45, 1.0) + 0.31);
		vec4 a = nz(np + 0.55 * vec3(w0.a, w0.r, 0.0));
		float n = a.r + 0.4 * a.g * det;
		vec3 rel = lp - vec3(Cc.xy, 0.0);
		float dc = length(vec3(rel.xy, rel.z / 0.29)) / Rr;
		float dcn = dc + 0.1 * a.r;
		float cav = 0.55 + 0.45 * smoothstep(0.14, 0.4, dcn);
		float dens = smoothstep(0.15, 0.95, f * (0.62 + 1.15 * n)) * cav;
		dens *= remClear(R, pg);
		float tz = smoothstep(0.22, 0.44, dcn);
		vec3 col = mix(OIII * 1.5, HA, tz);
		float flux = 1.0 / (1.0 + pow(dc / 0.55, 2.0));
		float front = exp(-pow((dcn - 0.4) / 0.06, 2.0));
		// (the globules from the same fetch's ridged channel: a third fetch a sample
		// was a tenth of the frame at the core)
		float dl = smoothstep(0.62, 0.8, a.b) * smoothstep(0.3, 0.6, dc);
		float em = dens * dens * (0.45 + 1.4 * flux) + 0.55 * front * dens;
		EV += col * em * u_nebK.x * (1.0 - 0.7 * dl);
		// what lights it from outside, the lightning inside it among that light
		EV += dens * GASA * Lin * 0.05;
		// lightning inside it: the stroke's light scatters through the gas round it
		vec4 lt = u_lt[k];
		if (lt.x > 0.0) {
			vec3 dl = lp - vec3(lt.yz, 0.0);
			EV += dens * GASA * LIGHTNING * lt.x * wxGate() * 6.0 / (1.0 + dot(dl, dl) / (lt.w * lt.w));
		}
		sig += vec3(dens * 1.6) + RED * dl * dens * 16.0;
	} else if (kind == 1) {
		// REFLECTION: dust lit blue by the star inside it; its light shafts turn slowly
		float f = lobeField(k, lp, 0.29, 2.4);
		if (f < 0.02) {
			return;
		}
		float det = clamp((Rr / R.FP - 70.0) / 70.0, 0.0, 1.0);
		vec2 qx = (lp.xy - lp.z * R.DXY) / Rr;
		vec3 np = vec3(qx * 1.35, lp.z / (0.29 * Rr) * 0.3) + vec3(seed, 2.0, R.TM * 1.5);
		vec4 w0 = nz(np * vec3(0.5, 0.5, 1.0) + 0.7);
		vec4 a = nz(np + 0.5 * vec3(w0.r, w0.a, 0.0));
		float n = a.r + 0.25 * a.g * det;
		float dens = f * (0.62 + 0.38 * smoothstep(-0.5, 0.7, n));
		vec3 rel = lp - vec3(Cc.xy, 0.0);
		float ds = length(vec3(rel.xy, rel.z / 0.5)) / Rr;
		float cosT = dot(rel / max(length(rel), 1e-5), R.CAM);
		float I = 1.0 / (1.0 + pow(ds / 0.24, 2.0));
		// light shafts round the star, turning slowly (SIMPLIFIED's weather)
		float an = atan(rel.y, rel.x) - 0.01 * u_time;
		float sh = smoothstep(0.5, 0.85, nz(vec3(cos(an), sin(an), 0.3) * 0.6 + vec3(seed * 0.2, 0.4, 0.1)).r * 0.5 + 0.5);
		I *= 1.0 + 0.8 * sh * wxGate() * smoothstep(0.06, 0.25, ds);
		if (R.REMM != 0) {
			dens *= mix(remClear(R, pg), 1.0, smoothstep(0.08, 0.5, I));
		}
		EV += dens * REFL * (I * hgN(cosT, 0.55) * u_nebK.y * (0.8 + 0.4 * smoothstep(0.0, 0.8, n)) + 0.5 * kitLum(Lin) + 0.02);
		sig += vec3(dens * 0.9) * RED;
	} else {
		// DARK: opaque dust, its silhouette read where the ray meets its mid-plane; only
		// the edge facing the core catches the light. Lightning lights it from within.
		vec2 qx = (lp.xy - lp.z * R.DXY) / Rr;
		float f = lobeField(k, vec3(qx * Rr, 0.0), 0.29, 2.4);
		if (f < 0.03) {
			return;
		}
		float hz = lp.z / (0.29 * Rr);
		float env = exp(-hz * hz * 1.6);
		float wf = 0.12 * clamp(Rr / R.FP / 40.0, 0.0, 1.0);
		// (the silhouette is the ray's, the same at every sample: worked out once)
		float dens = dk.x, d2 = dk.y;
		float vv;
		vec3 Lsun = coreLight(pg, vv) + Lin * 0.4;
		float rim = clamp((dens - d2) * 2.5, 0.0, 1.0) * (1.0 - smoothstep(0.5, 0.9, dens));
		EV += env * (rim * DUSTA * (Lsun * 4.5 + vec3(0.04)) + dens * vec3(0.010, 0.006, 0.007));
		vec4 lt = u_lt[k];
		if (lt.x > 0.0) {
			vec3 dl = pg - vec3(A.xy + lt.yz, 0.0);
			EV += env * mix(LIGHTNING, DUSTA, 0.3) * lt.x * wxGate() * smoothstep(0.1, 0.6, dens) * exp(-dot(dl, dl) / (lt.w * lt.w)) * 0.4;
		}
		sig += mix(RED, vec3(1.0), 0.3) * dens * dens * env * u_nebK.w;
	}
}

// ------------------------------------------------------------------ shells: remnants and planetaries
// A shell is thin, so each layer is drawn where the ray crosses it (front wall
// and back wall), weighted by the exact path through a shell of thickness t:
// crisp filaments at any zoom, hollow middles and bright limbs by themselves.
float shellPath(float bi2, float Rs, float t) {
	float r2 = Rs * Rs - bi2;
	if (r2 <= 0.0) {
		return 0.0;
	}
	float ri = Rs - t;
	return (sqrt(r2) - sqrt(max(ri * ri - bi2, 0.0))) / t;
}
vec3 remnantEmit(in Ray R, vec3 n, float seed, float lay, float det, float glim) {
	vec3 sv = vec3(seed * 0.13, 0.31 + lay * 0.37, 0.17 + lay * 0.53);
	float s1 = nz(n * 1.05 + sv + vec3(0.0, 0.0, R.TM)).b;
	float s2 = nz(n * 2.3 + sv * 1.7 + 0.4).b;
	float strands = smoothstep(0.6, 0.9, s1) + 0.55 * det * smoothstep(0.7, 0.92, s2);
	float gaps = smoothstep(-0.3, 0.25, nz(n * 0.5 + sv * 0.5 + 0.7).a);
	float knots = smoothstep(0.9, 0.98, s1) * det;
	float I = (mix(0.3, 0.1, det) + mix(0.25, 1.0, det) * strands + 1.2 * knots) * gaps * (1.0 + 1.5 * glim);
	vec3 c = lay < 0.5 ? mix(REMR, vec3(1.0, 0.5, 0.6), 0.2 + 0.35 * knots) : mix(OIII, vec3(0.62, 1.0, 0.9), 0.2 + 0.35 * knots);
	return c * I;
}
float limbW(float pf) { return min(pf, 3.2) * mix(0.1, 0.75, smoothstep(1.1, 3.8, pf)); }
// EMISSION pillars: dark tapered columns on the cavity wall, pointing at the
// ionising cluster, their tips lit. One occluding event per emission cloud.
void pillarSheet(in Ray R, inout Evs EV, int k, vec3 P0, vec3 Dv) {
	vec4 A = u_clA[k], B = u_clB[k], Cc = u_clC[k];
	float Rr = Cc.w, seed = B.w;
	float hp = B.x * 0.45;
	vec3 p = P0 + hp * Dv;
	vec2 qc = p.xy - (A.xy + Cc.xy);
	float rho = length(qc) / Rr;
	if (rho < 0.3 || rho > 1.25) {
		return;
	}
	float f = lobeField(k, vec3(p.xy - A.xy, 0.0), 0.29, 2.6);
	if (f < 0.55) {
		return;
	}
	float m = 0.0, lit = 0.0;
	float tg = kitHash1(ivec2(int(seed * 53.0), 11 + k)) * R_TAU;
	for (int i = 0; i < 3; i++) {
		vec3 hs = kitHash3(ivec2(int(seed * 97.0) + i * 17, 31 + k * 7));
		float ti = tg + (float(i) - 1.0) * 0.32 + 0.1 * hs.x;
		vec2 e = vec2(cos(ti), sin(ti));
		float tipR = (0.32 + 0.22 * hs.y) * Rr;
		float L = (0.24 + 0.26 * hs.z) * Rr;
		float w0 = (0.026 + 0.03 * hs.z) * Rr;
		vec2 d = qc - e * tipR;
		float sl = clamp(dot(d, e) / L, 0.0, 1.0);
		vec2 cp = d - e * sl * L;
		float wob = nz(vec3(sl * 2.2 + hs.x * 5.0, hs.y * 3.0, 0.37 + R.TM)).r;
		float w = w0 * (0.55 + 0.45 * sl) * (1.0 + 0.4 * wob);
		float sdf = length(cp) - w;
		if (sdf > 3.0 * R.FP) {
			continue;
		}
		float mi = smoothstep(0.7 * R.FP, -0.7 * R.FP, sdf) * clamp(w / (1.5 * R.FP), 0.0, 1.0) * (1.0 - smoothstep(0.3, 1.0, sl));
		float skin = smoothstep(-(1.8 * R.FP + 0.12 * w), 0.0, sdf);
		float facing = clamp(-dot(normalize(cp + 1e-7), e) * 0.7 + 0.3, 0.0, 1.0);
		lit = max(lit, mi * skin * (1.0 - smoothstep(0.0, 0.3, sl)) * facing);
		m = max(m, mi);
	}
	if (m <= 0.0) {
		return;
	}
	float fade = smoothstep(0.55, 1.0, f);
	float flux = 1.0 / (1.0 + pow(rho / 0.55, 2.0));
	vec3 skinC = mix(HA, vec3(1.0, 0.72, 0.62), 0.45) * (0.6 + 1.6 * flux);
	addEvA(EV, hp, skinC * lit * fade * u_nebK.x * 0.16, m * fade * 0.9);
}
// the crossings of cloud k's shell(s) with this ray, as events; a remnant's
// shock glimmers run round it (SIMPLIFIED's weather)
void shellHits(in Ray R, inout Evs EV, int k, vec3 P0, vec3 Dv) {
	vec4 A = u_clA[k], B = u_clB[k], Cc = u_clC[k];
	int kind = int(A.w + 0.5);
	float seed = B.w;
	bool pn = kind == 2;
	float Rs = B.y * (pn ? 0.62 : 1.0);
	float sz = pn ? 0.55 : 0.42;
	vec3 o = P0 - vec3(A.xy, 0.0), d = Dv;
	if (pn) {
		mat2 Rr = kitRot(seed * 0.9);
		o.xy = Rr * o.xy;
		d.xy = Rr * d.xy;
		int shape = int(Cc.z + 0.5);
		float sx = shape == 1 ? 1.0 / 0.7 : 1.0;
		o.x *= sx;
		d.x *= sx;
	}
	o.z /= sz;
	d.z /= sz;
	float a = dot(d, d), b = dot(o, d), oo = dot(o, o);
	float bi2 = oo - b * b / a;
	float det = clamp((Rs / R.FP - 22.0) / 70.0, 0.0, 1.0);
	for (int lay = 0; lay < 2; lay++) {
		float R0 = pn ? Rs * (lay == 0 ? 1.0 : 0.84) : Rs * (lay == 0 ? 1.0 : 0.9);
		// (never thinner than two and a half blocks: thinner, the limb's sharp path
		// spike moved through the blocks as the zoom did, and flickered)
		float t = max(pn ? R0 * (lay == 0 ? 0.05 : 0.16) : R0 * 0.07, 2.6 * R.FP);
		if (bi2 > R0 * R0 * 1.45) {
			continue;
		}
		for (int side = 0; side < 2; side++) {
			float sgn = side == 0 ? 1.0 : -1.0;
			float Rx = R0;
			if (!pn) {
				float disc0 = b * b - a * (oo - R0 * R0 * 1.44);
				float h0 = (-b + sgn * sqrt(max(disc0, 0.0))) / a;
				vec3 n0 = normalize(o + h0 * d);
				vec4 sh = nz(n0 * 0.55 + vec3(seed * 0.1, 0.2, 0.6));
				Rx = R0 * (1.0 + 0.13 * sh.r + 0.05 * sh.a);
			}
			float disc = b * b - a * (oo - Rx * Rx);
			if (disc <= 0.0) {
				continue;
			}
			float h = (-b + sgn * sqrt(disc)) / a;
			vec3 n = (o + h * d) / Rx;
			float pf = shellPath(bi2, Rx, t);
			if (pf <= 0.0) {
				continue;
			}
			vec3 c;
			if (pn) {
				float v = 0.8 + 0.3 * nz(n * 0.8 + vec3(seed * 0.3, 0.1, 0.4)).r;
				c = (lay == 0 ? mix(HA, vec3(1.0, 0.55, 0.5), 0.3) * 1.3 : mix(OIII, vec3(0.7, 1.0, 0.95), 0.25) * 1.1) * v;
				c *= lay == 0 ? limbW(pf) * 0.03 : pf * mix(0.22, 1.0, smoothstep(1.1, 2.8, pf)) * 0.03;
			} else {
				float an = atan(n.y, n.x);
				float glim = 0.0;
				for (int j = 0; j < 3; j++) {
					float th0 = 0.05 * u_time + float(j) * 2.094 + seed;
					float dd = mod(an - th0 + R_PI, R_TAU) - R_PI;
					glim += 0.6 * exp(-dd * dd / 0.0225);
				}
				c = remnantEmit(R, n, seed, float(lay), det, glim * wxGate()) * (lay == 0 ? 1.0 : 0.62);
				c *= limbW(pf) * 0.075 * mix(0.4, 1.0, det);
			}
			addEvA(EV, h, c * u_nebK.z, 0.0);
		}
	}
	if (pn) {
		float fill = shellPath(bi2, Rs * 0.84, Rs * 0.84);
		addEvA(EV, -b / a, OIII * 0.008 * fill * u_nebK.z, 0.0);
		if (int(Cc.z + 0.5) == 3) {
			for (int s = 0; s < 2; s++) {
				vec3 q = vec3((s == 0 ? 1.0 : -1.0) * Rs * 1.45, 0.0, 0.0);
				vec3 w = o - q;
				float hb = -dot(w, d) / a;
				vec3 cl = w + hb * d;
				addEvA(EV, hb, HA * 1.6 * exp(-dot(cl, cl) / (Rs * Rs * 0.02)) * u_nebK.z, 0.0);
			}
		}
	}
}

// ------------------------------------------------------------------ the sky behind
// the sky behind, at infinity (`chart_bg.gdshaderinc`): far nebulae, far
// galaxies, three depths of stars sliding by depth as you pan
vec3 sky(vec2 v) {
	return bgLight((v - gpan()) * u_zoom, 1.0);
}

// ------------------------------------------------------------------ the disc plane (h = 0)
// the thin disc: old and young starlight, the knots (breathing lamps), the dust
// lane (which reddens and stops what lies behind), the supernova's echo in the
// dust, the bulge's front half before it and its back half after it, and the
// data's stars inside the dust
void planeEvent(in Ray R, vec2 pP, ivec2 sb, vec3 bF, vec3 bB, inout vec3 C, inout vec3 T) {
	float rP = length(pP);
	vec4 dA = discA(pP);
	if (R.REMM != 0) {
		float rc = remClear(R, vec3(pP, 0.0));
		dA.gba *= vec3(rc);
	}
	float cav = smoothstep(1.2, 4.0, rP / max(u_holeR, 1e-4));
	float dz = smoothstep(0.0005, 0.00028, R.FP);
	float det = dz > 0.0 ? nz(vec3(pP * 34.0, 0.37)).g * dz : 0.0;
	vec3 oldC = mix(u_oldIn, u_oldOut, smoothstep(0.08, 0.36, rP));
	float tail = 0.05 * exp(-rP / 0.6) * smoothstep(0.85, 1.15, rP) * (1.0 - smoothstep(1.15, 1.85, rP));
	vec3 Ed = u_discK.x * (dA.r * R.KB + tail) * oldC * cav + u_discK.y * dA.g * u_youngCol * (1.0 + 0.6 * det) + u_discK.z * dA.b * HA * (1.0 + 0.8 * det);
	// the knots: pink gathered light on the arms' fronts, each breathing, now and then blooming
	float px = 1.0 / (u_zoom * u_k);
	int ki = u_nkn > 0 && max(abs(pP.x), abs(pP.y)) < u_ext * 0.995 ? int(texture(u_knotMap, kitMapUV(pP, u_ext)).r * 255.0 + 0.5) - 1 : -1;
	if (ki >= 0) {
		vec4 kn = u_kn[ki];
		vec2 dk = pP - kn.xy;
		float s = max(kn.z, 1.4 * px);
		float q = length(dk) / s;
		Ed += kn.w * u_discK.z * (HA * (exp(-q * q * 1.6) + exp(-q * 1.2) * 0.3) + vec3(0.8, 0.9, 1.0) * exp(-q * q * 6.0) * 0.6) * 0.5;
	}
	float tau = dA.a * 2.63158 * u_discK.w * max(1.0 + 0.9 * det, 0.0);
	vec3 att = exp(-tau * RED);
	float vis;
	vec3 Lc = coreLight(vec3(pP, 0.004), vis) * vis;
	vec3 La = armLight(vec3(pP, 0.0));
	vec3 Lx = lampLight(vec3(pP, 0.0));
	C += T * Ed * 0.5 * (1.0 + att);
	// dust edges catch the light: warm lanes, and the lamps' light (a supernova's)
	C += T * (1.0 - att) * DUSTA * (Lc * 0.18 + La * 0.2 + Lx * 0.25);
	// the supernova's light echo: a ring of its light sweeping out through the dust and gas
	if (u_echo.w > 0.0) {
		float de = (length(pP - u_echo.xy) - u_echo.z) / max(0.0025, 1.5 * px);
		float ring = exp(-de * de);
		C += T * FLARE * u_echo.w * ring * (0.04 + 1.6 * (1.0 - att.b) + 0.6 * dA.g);
	}
	// the core's own gas: thin spirals falling into the hole, lit orange by its disc
	vec4 dBp = discB(pP);
	if (dBp.a > 0.003) {
		float cg = dBp.a;
		vec3 gl = (u_holeLight / (1.0 + rP * rP / 0.0014) * 3.5 + Lc * 0.15) * DUSTA * cg;
		C += T * gl;
		att *= exp(-cg * 0.9 * RED);
	}
#if LOW
	{
		// LOW: the billows' light as one sheet over the arms
		vec4 dB = discB(pP);
		float col = dB.r * dB.g * 9.0 * (0.7 + 0.5 * nz(vec3(pP * 9.0, 0.2)).r);
		C += T * col * (GASA * (Lc * 0.5 + La + Lx * 0.4) * 0.5 + HA * 0.02 + u_amb);
	}
#endif
	// the bulge in front of the plane, the near lanes across it in silhouette
	C += T * bF * mix(vec3(1.0), att, 0.45);
	// the data's stars, inside the dust
	vec3 st = vec3(0.0);
	if (u_stars_on && sb.x >= 0 && sb.y >= 0 && sb.x < int(u_vp_size.x) && sb.y < int(u_vp_size.y)) {
		st += texelFetch(u_stars, sb, 0).rgb;
	}
	// deep in, the nucleus resolves into stars, and the arms into their own stars
	// as you zoom (the showcase's A): fixed in the plane, as many as the arm's own
	// light, each keeping its place so nothing pops
	vec2 qs = kitRot(u_phi) * pP;
	vec2 qv = vec2(qs.x, qs.y * KIT_TILT) * u_k;
	float blkv = 2.0 / u_zoom;
	float nzf = smoothstep(2.2, 4.5, u_zoom) * (1.0 - smoothstep(0.07, 0.18, rP));
	if (nzf > 0.0) {
		vec4 ns = kitStar(qv, blkv, 3.2, 0.42, 77);
		if (ns.x > 0.5) {
			st += kitStarTint(0.25 + 0.5 * ns.z) * (0.2 + 1.5 * pow(ns.y, 3.0)) * nzf;
		}
	}
	float rzf = smoothstep(1.5, 3.0, u_zoom) * smoothstep(0.07, 0.16, rP);
	if (rzf > 0.0) {
		float prob = clamp(dA.g * 0.9 + dA.r * 0.2, 0.0, 0.32);
		vec4 rs = kitStar(qv, blkv, 2.4, prob, 191);
		if (rs.x > 0.5) {
			float yng = dA.g / max(dA.g + dA.r * 0.35, 1e-4);
			st += mix(kitStarTint(0.2 + 0.4 * rs.z), kitStarTint(0.72 + 0.28 * rs.z), yng) * (0.015 + 0.8 * pow(rs.y, 3.0)) * rzf;
		}
	}
	// (thinned where the hole's lens packs the sky: a star read through the lens
	// jumps from block to block as the zoom moves, most of the hole's flicker)
	C += T * st * sqrt(att) * (1.0 - smoothstep(0.15, 0.8, R.LA));
	T *= att;
	C += T * bB;
}

// ------------------------------------------------------------------ the volume
vec3 radiance(vec2 v, ivec2 sb, ivec2 dq, float la) {
	Ray R;
	R.RG = kitRot(-u_phi);
	R.CAM = vec3(R.RG * vec2(0.0, KIT_TILT_COS), KIT_TILT);
	R.FP = 2.0 / (u_k * u_zoom) * exp2(la);
	// (each fine octave only once its cells span three blocks or more: the
	// showcase's let them in at about one, and as the zoom moved they flickered)
	R.WHI = smoothstep(0.0016, 0.0009, R.FP);
	R.WHI2 = smoothstep(0.0004, 0.00022, R.FP);
	R.TM = u_time * 0.0016 * u_drift;
	R.DXY = R.RG * vec2(0.0, KIT_RAY_DY);
	R.LA = la;
	vec3 fp = kitFlowPhase(u_time * u_drift, 20.0);
#if LOW
	fp.z = 0.0;
#endif
	R.FL = fp;
	vec2 q0 = vec2(v.x, v.y / KIT_TILT) / u_k;
	vec2 pP = R.RG * q0;
	vec3 C = vec3(0.0), T = vec3(1.0);

	// ---- clouds this ray passes through: h intervals of their bounding ellipsoids
	float cin[8], cout_[8];
	vec2 dks[8];
	int hits = 0;
	vec3 P0 = vec3(pP, 0.0);
	vec3 Dv = vec3(R.DXY, 1.0);
	Evs EV;
	EV.n = 0;
	EV.done = 0;
	R.REMM = 0;
	for (int k = 0; k < 8; k++) {
		cin[k] = -1e9;
		cout_[k] = 1e9;
		dks[k] = vec2(0.0);
		if (k >= u_nCl) {
			continue;
		}
		vec4 A = u_clA[k];
		int kind = int(A.w + 0.5);
		if (kind == 3) {
			vec3 ro = P0 - vec3(A.xy, 0.0), rd = Dv;
			ro.z /= 0.42;
			rd.z /= 0.42;
			float rb2 = dot(ro, ro) - dot(ro, rd) * dot(ro, rd) / dot(rd, rd);
			if (rb2 < u_clB[k].y * u_clB[k].y * 1.3) {
				R.REMM |= 1 << k;
			}
		}
		if (kind == 2 || kind == 3) {
			shellHits(R, EV, k, P0, Dv);
			continue;
		}
		if (kind == 0) {
			pillarSheet(R, EV, k, P0, Dv);
		}
		vec3 sc = vec3(A.z, A.z, u_clB[k].x);
		vec3 o = (P0 - vec3(A.xy, 0.0)) / sc, d = Dv / sc;
		float a = dot(d, d), bb = dot(o, d), c = dot(o, o) - 1.0;
		float disc = bb * bb - a * c;
		if (disc <= 0.0) {
			continue;
		}
		float sq = sqrt(disc);
		cin[k] = (-bb + sq) / a;
		cout_[k] = (-bb - sq) / a;
		hits++;
		if (kind == 4) {
			// a dark cloud's silhouette where the ray meets its mid-plane, and a step toward the core
			float Rr = u_clC[k].w;
			vec2 qx = (P0.xy - A.xy) / Rr;
			float wf = 0.12 * clamp(Rr / R.FP / 40.0, 0.0, 1.0);
			vec2 tg = normalize(vec2(-A.y, A.x) + 1e-6);
			vec2 toC = -normalize(A.xy + qx * Rr + 1e-6) * max(0.01, 2.5 * R.FP) / Rr;
			dks[k] = vec2(darkDens(R, k, qx, Rr, u_clB[k].w, wf, tg), darkDens(R, k, qx + toC, Rr, u_clB[k].w, wf, tg));
		}
	}

	float H0 = u_H0;
	float reachY = max(abs(q0.y) - H0 * KIT_RAY_DY, 0.0);
#if LOW
	bool vol = false;
	float subN = 6.0;
#else
	bool vol = length(vec2(q0.x, reachY)) < 1.32;
	float subN = 8.0;
#endif
	// the march's start, jittered on a Bayer pattern anchored to the picture
	float jit = 0.5 + (kitBayer4(dq) - 0.5) * u_jitAmp;
	float dhBase = 2.0 * H0 / u_steps;
	// RAYS THAT MEET NO BILLOWS: the slab's footprint along this ray (the arm gas,
	// averaged at a coarse mip at three points along it) holds no gas worth a
	// column, so only the smooth haze is left, and a few steps hold it
	bool billows = false;
	if (vol) {
		for (int j = -1; j <= 1; j++) {
			vec2 fp = R.RG * vec2(q0.x, q0.y + float(j) * 0.7 * H0 * KIT_RAY_DY);
			billows = billows || textureLod(u_discB, kitMapUV(fp, u_ext), 5.5).r > 0.006;
		}
		if (!billows) {
			dhBase = 2.0 * H0 / 6.0;
		}
	}

	// ---- the bulge: two smooth components less a cavity round the hole, split at the plane
	vec3 bF, bB;
	{
		vec2 b1 = bulgeComp(q0, u_bulge.x, u_bulge.z, 0.0) * u_bulgeI.x;
		vec2 b2 = bulgeComp(q0, u_bulge.y, u_bulge.z, 0.0) * u_bulgeI.y;
		vec2 bc = bulgeComp(q0, u_bulge.w, u_bulge.z, 0.0) * u_bulgeI.z;
		vec2 in1 = max(b1 - bc, 0.0);
		vec2 out2 = max(b2 - max(bc - b1, 0.0), 0.0);
		float rr = length(q0 * vec2(1.0, 0.8));
		vec3 ci = mix(u_bCore, u_bInner, smoothstep(0.012, 0.045, rr));
		vec3 co = mix(u_bInner, u_bOuter, smoothstep(0.03, 0.2, rr));
		bF = ci * in1.x + co * out2.x;
		bB = ci * in1.y + co * out2.y;
		// deep in, the eye adapts: the nucleus's glow eases back round the hole
		R.KB = 1.0 - u_kb * smoothstep(1.8, 5.5, u_zoom) * (1.0 - smoothstep(0.1, 0.5, rr));
		bF *= R.KB;
		bB *= R.KB;
	}

	bool planeDone = false;
	float h = H0;
	// the arms' and the lamps' light at the plane under this ray, for the haze
	vec3 LaP = vec3(0.0), LxP = vec3(0.0);
	if (vol || hits > 0) {
		LaP = armLight(vec3(pP, 0.0));
		LxP = lampLight(vec3(pP, 0.0));
	}
	for (int i = 0; i < 120; i++) {
		if (h <= -H0 + 1e-6) {
			break;
		}
		if (max(T.r, max(T.g, T.b)) < 0.01) {
			break;
		}
		float dh = (billows && abs(h) < 0.035) ? dhBase * 0.5 : dhBase;
		bool inCl = false;
		for (int k = 0; k < 8; k++) {
			if (k >= u_nCl) {
				break;
			}
			if (cin[k] < -1e8) {
				continue;
			}
			// (more steps through a cloud the bigger it is on the screen: a few
			// steps through a big one slid through its billows as the zoom moved)
			float sub = max((cin[k] - cout_[k]) / clamp(u_clA[k].z / R.FP / 9.0, subN, subN * 2.0), 0.0008);
			if (h <= cin[k] + 1e-6 && h > cout_[k]) {
				dh = min(dh, sub);
				inCl = true;
			} else if (h > cin[k]) {
				dh = min(dh, max(h - cin[k], sub));
			}
		}
		bool jump = !vol && !inCl;
		if (jump) {
			// nothing to sample here: jump to the next event (a cloud, a shell, the plane, the end)
			float nxt = planeDone ? -H0 : 0.0;
			for (int k = 0; k < 8; k++) {
				if (k >= u_nCl) {
					break;
				}
				if (cin[k] < -1e8) {
					continue;
				}
				if (cin[k] < h - 1e-6 && cin[k] > nxt) {
					nxt = cin[k];
				}
			}
			for (int e = 0; e < MAXEV; e++) {
				if (e >= EV.n) {
					break;
				}
				if ((EV.done & (1 << e)) == 0 && EV.h[e] < h - 1e-6 && EV.h[e] - 1e-6 > nxt) {
					nxt = EV.h[e] - 1e-6;
				}
			}
			dh = max(h - nxt, 1e-4);
		}
		if (h - dh < -H0) {
			dh = h + H0;
		}
		float hs = jump ? h - dh : h - jit * dh;
		for (int e = 0; e < MAXEV; e++) {
			if (e >= EV.n) {
				break;
			}
			if ((EV.done & (1 << e)) == 0 && hs <= EV.h[e]) {
				EV.done |= 1 << e;
				C += T * EV.c[e];
				T *= 1.0 - EV.a[e];
			}
		}
		if (!planeDone && hs <= 0.0) {
			planeDone = true;
			planeEvent(R, pP, sb, bF, bB, C, T);
		}
		if (jump) {
			h -= dh;
			continue;
		}
		vec3 pg = vec3(R.RG * vec2(q0.x, q0.y + hs * KIT_RAY_DY), hs);
		float ds = dh * KIT_RAY_LEN;
		float r = length(pg.xy);
		vec3 Em = vec3(0.0), sig = vec3(0.0);
		float vis = 1.0;
		vec3 Lc = vec3(0.0), La = vec3(0.0), Lx = vec3(0.0);
		bool lit = false;
		if (vol && r < 1.32) {
			vec4 dB = discB(pg.xy);
			float d3 = length(pg);
			float hz = u_gasK.y * exp(-abs(pg.z) / 0.05) * smoothstep(0.85, 0.12, r) * smoothstep(0.03, 0.09, d3) * (1.0 - 0.8 * smoothstep(1.6, 3.5, u_zoom));
			float rb = billows ? billowDens(R, pg, dB, 1.0) : 0.0;
			if (rb > 0.002) {
				rb *= remClear(R, pg);
			}
			if (rb > 0.002 && hits > 0) {
				float sup = 0.0;
				for (int k = 0; k < 8; k++) {
					if (k >= u_nCl) {
						break;
					}
					if (cin[k] < -1e8) {
						continue;
					}
					vec3 e = (pg - vec3(u_clA[k].xy, 0.0)) / vec3(u_clA[k].z, u_clA[k].z, u_clB[k].x);
					sup = max(sup, smoothstep(1.0, 0.55, length(e)));
				}
				rb *= 1.0 - 0.85 * sup;
			}
			if (rb > 0.002 || hz > 0.002) {
				Lc = coreLight(pg, vis);
				// (the haze alone takes the arms' and the lamps' light from the plane
				// below, read once a ray: per sample it was a third of the frame)
				if (rb > 0.002) {
					La = armLight(pg);
					Lx = LxP;
					lit = true;
				} else {
					La = LaP;
					Lx = LxP;
				}
				float cosT = dot(pg / max(d3, 1e-5), R.CAM);
				// billows: lit amber on the side facing the core, violet in their own shade
				if (rb > 0.002) {
					vec3 toC = normalize(-pg + vec3(0.0, 0.0, sign(pg.z) * 0.4 * d3));
					// (one step toward the core, read twice as deep: the second step cost a
					// sixth of the frame and changed little)
					float rb2 = 2.0 * billowDens(R, pg + toC * 0.018, dB, 0.0);
					float self = exp(-u_gasK.x * rb2 * 0.016);
					float reachB = (1.0 + d3 * d3 / 0.012) / (1.0 + d3 * d3 / 0.05);
					vec3 Lb = Lc * reachB * vis * self * hgN(cosT, 0.35) * 2.4 + La * (0.08 + 0.4 * self) + Lx * 0.6 + u_amb * 0.6;
					float haG = textureLod(u_discA, kitMapUV(pg.xy, u_ext), 2.0).b;
					Em += rb * u_gasK.x * (vec3(0.78, 0.84, 1.0) * Lb * 0.9) + rb * HA * haG * u_gasK.w;
					sig += vec3(rb * u_gasK.x * 1.35) * mix(vec3(1.0), RED, 0.35);
				}
				// the god-ray haze: thin gas above and below the disc lit by the core, cut by billow shadows
				Em += hz * Lc * mix(1.0, vis, u_gr) * hgN(cosT, 0.6) * 0.35 + hz * (La + Lx) * 0.08;
			}
		}
		if (inCl) {
			if (!lit) {
				Lc = coreLight(pg, vis);
				La = armLight(pg);
				Lx = LxP;
			}
			vec3 Lin = Lc * vis + La + Lx;
			for (int k = 0; k < 8; k++) {
				if (k >= u_nCl) {
					break;
				}
				if (cin[k] < -1e8 || hs > cin[k] || hs < cout_[k]) {
					continue;
				}
				cloudSample(R, k, pg, Em, sig, Lin, dks[k]);
			}
		}
		C += T * Em * ds;
		T *= exp(-sig * ds);
		h -= dh;
	}
	for (int e = 0; e < MAXEV; e++) {
		if (e >= EV.n) {
			break;
		}
		if ((EV.done & (1 << e)) == 0 && EV.h[e] >= 0.0) {
			EV.done |= 1 << e;
			C += T * EV.c[e];
			T *= 1.0 - EV.a[e];
		}
	}
	if (!planeDone) {
		planeEvent(R, pP, sb, bF, bB, C, T);
	}
	for (int e = 0; e < MAXEV; e++) {
		if (e >= EV.n) {
			break;
		}
		if ((EV.done & (1 << e)) == 0) {
			EV.done |= 1 << e;
			C += T * EV.c[e];
			T *= 1.0 - EV.a[e];
		}
	}

	// the stellar halo: a faint round glow the disc thins into, broken into soft wisps
	vec2 hv = vec2(v.x, v.y / u_halo.z) / u_k;
	float hr2 = dot(hv, hv) / (u_halo.y * u_halo.y);
	vec4 hw = nz(vec3(hv * 0.32, 0.53));
	float wisp = max(0.25 + 0.8 * hw.r + 0.45 * nz(vec3(hv * 1.3 + hw.ag * 0.3, 0.21)).r, 0.0);
	C += mix(vec3(0.42, 0.52, 0.9), vec3(0.95, 0.7, 0.48), u_halo.w) * u_halo.x * wisp / pow(1.0 + hr2, 1.7);
	C += T * (sky(v) + vec3(0.0021, 0.0030, 0.0062));
	return C;
}

// the supernova's flare: a hot block, a cross of light a few blocks long, a glow
vec3 supernova(vec2 v, ivec2 blk) {
	if (u_sn.z <= 0.0) {
		return vec3(0.0);
	}
	float cs = cos(u_phi), sn = sin(u_phi);
	vec2 sv = vec2(u_sn.x * cs + u_sn.y * sn, (u_sn.y * cs - u_sn.x * sn) * KIT_TILT) * u_k;
	ivec2 d = blk - blockOf(scr(sv));
	float g = u_sn.z;
	vec3 c = vec3(0.0);
	float L = 3.0 + 3.0 * g;
	if (d.x == 0 && d.y == 0) {
		c += FLARE * 8.0 * g;
	} else if (d.x == 0 || d.y == 0) {
		float a = float(abs(d.x) + abs(d.y));
		if (a <= L) {
			c += FLARE * 2.4 * g * pow(1.0 - (a - 1.0) / L, 2.0);
		}
	}
	float dd = length((v - sv) * u_zoom);
	c += FLARE * g * (0.34 * exp(-dd / 3.0) + 0.05 * exp(-dd / 9.0) + 0.008 * exp(-dd / 24.0));
	return c;
}

// how many times the lens squeezes the picture behind at S
float lensSqueeze(vec2 S) {
	float b = max(length(S), 1e-3);
	float e = 0.02;
	float g1 = lh_behind(S) * b;
	float g2 = lh_behind(S * ((b + e) / b)) * (b + e);
	return max(abs(g2 - g1) / e, lh_behind(S));
}

vec3 place(vec2 v, ivec2 blk, ivec2 dq) {
	float shadow = u_holeR * u_k;
	vec2 S = lh_to_s(v, vec2(0.0), shadow);
	bool lens = length(S) <= lh_dims.x * 0.97;
	vec2 vbg = lens ? v * lh_behind(S) : v;
	ivec2 sb = lens ? blockOf(scr(vbg)) : blk;
	float la = lens ? log2(max(lensSqueeze(S), 1.0)) : 0.0;
	vec3 C = radiance(vbg, sb, dq, la) + supernova(v, blk);
	if (!lens) {
		return C;
	}
	// SIMPLIFIED's hole: what lies behind squeezed dark and cooler near the shadow,
	// the disc's light on what is round it, the shadow cut, the disc laid over
	C *= lh_cool(S, smoothstep(3.0, 6.0, u_zoom)) * lh_squeeze(S);
	// light through gas: what the lens packs into a thin ring is seen through
	// more of the hole's dim surroundings, so it is dimmed as it is squeezed
	// (unlit, the bulge's bands repeated under the hole as bright rings)
	C /= 1.0 + 0.6 * max(lensSqueeze(S) - 1.0, 0.0);
	C += u_holeLight * 0.4 * lh_glow(S);
	float cap;
	vec4 d = lh_disc(S, lh_px_rs(shadow * u_zoom), u_time, smoothstep(2.6, 4.0, u_zoom), lh_hot(u_time, u_wxOn), cap);
	C *= 1.0 - cap;
	if (d.a > 0.004) {
		C = C * (1.0 - d.a) + lh_exact_hdr(d.rgb, u_exp) * d.a;
	}
	return C;
}

void fragment() {
	ivec2 blk = ivec2(floor(UV * u_vp_size));
	vec2 s = u_vp_origin + (vec2(blk) + 0.5) * 2.0;
	vec2 v = (s - u_cpix) / u_zoom;
	ivec2 dq = blk + ivec2(u_block0);
	vec3 C = place(v, blk, dq);
	if (u_tone_out) {
		// a palette probe sees what the composite will: toned, then its vibrance
		// (cut from the dull probe, the palette had no saturated tans, and the
		// elliptical's gradient flipped between tan and rust in rings)
		vec3 L = kitOklab(max(kitTone(C * u_exp, u_burn), 0.0));
		float kv = 1.0 + 0.35 * smoothstep(0.1, 0.32, L.x) * (1.0 - smoothstep(0.86, 0.97, L.x)) * (1.0 - smoothstep(0.06, 0.16, length(L.yz)));
		L.yz *= kv;
		COLOR = vec4(kitToSrgb(max(kitOklabToLinear(L), 0.0)), 1.0);
	} else {
		COLOR = vec4(max(C, vec3(0.0)), 1.0);
	}
}
