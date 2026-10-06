// THE BLACK HOLE, EVERY STYLE'S: direction C's hole from the Oct 5 showcase
// (scratchpad `showcase/C/chart/place.glsl`, "the hole"), Jon's fixed pick for
// every style: "This is the best black hole rendition we have gotten. I love
// this shape and perspective. I want this no matter what style we pick." It
// draws the star chart's core (`chart_c_place`) and the sector map's core
// system. A wide round shadow seen at the plane's tilt, a thick banded ring
// (cream, amber, orange, red-brown), the lensed underside arc two bands cooler,
// a Keplerian swirl of streaky rings slipping past one another, infalling
// clumps hidden by the trace itself, and a hot spot now and then.
//
// HOW IT WORKS. Every pixel's light ray is traced ONCE (`LegacyHole.gd`
// integrates the photon orbit u'' = -u + 1.5 u^2 per impact parameter and keeps
// the table, `lh_lens`); a frame only looks it up. Where a ray meets the disc
// plane, the disc there is shaded; the image that went round the hole is drawn
// first, then the direct one over it. Nothing is painted as a shape.
//
// ---------------------------------------------------------------------- INTERFACE
// Stable since Oct 5. Changing it means telling every includer.
//
// UNIFORMS (all set by `LegacyHole.apply(material)`):
//   lh_lens    sampler2D  the photon table: x = impact parameter b (power-spaced,
//                         see lh_dims), y = path angle; R = u = 1/r reached (1.5
//                         inside the hole, 0 once escaped), G = the deflection of
//                         a ray that escapes (3.0 for one that falls in)
//   lh_dims    vec3       (b max, path angle max, b power): the table's spacing
//   lh_pal[8]  vec3       the disc's colours, LINEAR, darkest first
//   lh_tilt    float      the plane's tilt, sin of the elevation: 0.38 for both maps
//
// UNITS. Everything is in Schwarzschild radii (rs) from the hole's centre, y UP.
//   The shadow's radius is LH_SHADOW (2.598 rs); the disc runs from 3 rs out to
//   LH_OUT (7.8 rs), fading from 5.8. `lh_to_s` converts from any y-down space
//   (screen px, view px) given the shadow's radius in that space.
//
// FUNCTIONS
//   vec2  lh_to_s(vec2 p, vec2 centre, float shadow)
//         p and centre in a y-down space, shadow = the shadow's radius there -> S
//   float lh_px_rs(float shadow_px)   one screen px in rs, for the 4-sample AA
//   vec4  lh_disc(vec2 S, float px_rs, float t, float clumps, vec3 hot, out float captured)
//         the disc over the hole at S, four samples a block (no shimmer on thin
//         lensed rings). rgb = the band's colour (linear, a palette colour
//         exactly), a = coverage; `captured` = the share of the block inside the
//         shadow (draw the shadow by multiplying what is behind by 1 - captured,
//         BEFORE laying the disc over it). t = seconds, the disc's spin; clumps =
//         0..1, how much of the infalling clumps to show (the chart fades them in
//         from zoom 2.6 to 4); hot = lh_hot(t, on).
//   float lh_behind(vec2 S)   what is behind is lensed: sample the picture behind
//         at S * lh_behind(S) (a scale about the hole's centre, so the same factor
//         works in any space). The strong bend fades to nothing at 22 rs.
//   float lh_squeeze(vec2 S)  near the shadow the sky behind is squeezed into a
//         thin ring: multiply what is behind by this (0.01 at the shadow, 1 by
//         1.85 shadow radii), so the disc reads against dark
//   vec3  lh_cool(vec2 S, float amount)   the squeezed ring a little cooler and
//         bluer (multiply what is behind); amount 0..1 (the chart: zoom 3 to 6)
//   float lh_glow(vec2 S)     the disc's light falling on what is round it, as a
//         weight with falloff (0 inside 1.3 shadow radii, gone by 24 rs); add
//         colour * weight * how much there is to light
//   vec3  lh_hot(float t, float on)  the hot spot, a pure function of t: every 30 s
//         a spot brightens on the disc, orbits for 6 s and fades. (angle, gain,
//         radius rs); on = 0 under reduced motion
//   vec3  lh_exact_hdr(vec3 lin, float exposure)  the HDR that a hue-keeping
//         tone (max channel through 1 - exp(-m), burn 2.5, as the chart's) turns
//         back into `lin`, so a band lands exactly on its palette colour
//
// A CALLER'S MAIN, in full (the chart's, `chart_c_place.gdshaderinc`):
//   vec2 S = lh_to_s(v, vec2(0.0), shadow);           // v: view px, hole at 0
//   if (length(S) > lh_dims.x * 0.97) return picture(v);
//   vec3 C = picture(v * lh_behind(S));                // lensed, behind
//   C *= lh_cool(S, a) * lh_squeeze(S);
//   C += warm * lh_glow(S) * dust;
//   float cap; vec4 d = lh_disc(S, lh_px_rs(shadow * zoom), t, clumps, lh_hot(t, on), cap);
//   C *= 1.0 - cap;
//   if (d.a > 0.004) C = mix(C, lh_exact_hdr(d.rgb, exposure), d.a);

uniform sampler2D lh_lens : filter_linear, repeat_disable;
uniform vec3 lh_dims = vec3(24.0, 8.168141, 1.6);
uniform vec3 lh_pal[8];
uniform float lh_tilt = 0.38;

const float LH_PI = 3.14159265;
const float LH_TAU = 6.2831853;
const float LH_SHADOW = 2.5980762;   // the shadow's radius, rs (1.5 sqrt 3)
const float LH_OUT = 7.8;            // the disc reaches this far, rs: 3 shadow radii

// ------------------------------------------------------------------ helpers
// simplex noise (Ashima Arts / Ian McEwan, MIT), its own copy so the include
// stands alone
vec3 lh_m289_3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 lh_m289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 lh_m289_4(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 lh_perm3(vec3 x) { return lh_m289_3(((x * 34.0) + 1.0) * x); }
vec4 lh_perm4(vec4 x) { return lh_m289_4(((x * 34.0) + 1.0) * x); }

float lh_snoise2(vec2 v) {
	const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = lh_m289_2(i);
	vec3 p = lh_perm3(lh_perm3(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float lh_snoise3(vec3 v) {
	const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
	const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = lh_m289_3(i);
	vec4 p = lh_perm4(lh_perm4(lh_perm4(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));
	float n_ = 0.142857142857;
	vec3 ns = n_ * D.wyz - D.xzx;
	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
	vec4 x_ = floor(j * ns.z);
	vec4 y_ = floor(j - 7.0 * x_);
	vec4 x = x_ * ns.x + ns.yyyy;
	vec4 y = y_ * ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);
	vec4 b0 = vec4(x.xy, y.xy);
	vec4 b1 = vec4(x.zw, y.zw);
	vec4 s0 = floor(b0) * 2.0 + 1.0;
	vec4 s1 = floor(b1) * 2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0));
	vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	vec3 p0 = vec3(a0.xy, h.x);
	vec3 p1 = vec3(a0.zw, h.y);
	vec3 p2 = vec3(a1.xy, h.z);
	vec3 p3 = vec3(a1.zw, h.w);
	vec4 norm = 1.79284291400159 - 0.85373472095314 * vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
	m = m * m;
	return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// the integer hash the event clocks use (lowbias32 on two inputs), in [0, 1);
// `LegacyHole.hash01` is the same arithmetic on the CPU
float lh_hash(int n, int s) {
	uint x = (uint(n) * 2654435761u) ^ (uint(s + 1663821227) * 2246822507u);
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return float(x >> 8u) / 16777216.0;
}

// ------------------------------------------------------------------ the table
// u = 1/r reached at path angle ph for impact parameter b (rs = 1); G = deflection
vec2 lh_lens_at(float b, float ph) {
	float x = pow(clamp(b / lh_dims.x, 0.0, 1.0), 1.0 / lh_dims.z);
	vec2 sz = vec2(textureSize(lh_lens, 0));
	vec2 uv = (vec2(x, clamp(ph / lh_dims.y, 0.0, 1.0)) * (sz - 1.0) + 0.5) / sz;
	return textureLod(lh_lens, uv, 0.0).rg;
}

vec2 lh_to_s(vec2 p, vec2 centre, float shadow) {
	vec2 d = (p - centre) * (LH_SHADOW / max(shadow, 1e-6));
	return vec2(d.x, -d.y);
}

float lh_px_rs(float shadow_px) {
	return LH_SHADOW / max(shadow_px, 1e-6);
}

vec3 lh_hot(float t, float on) {
	if (on < 0.5) {
		return vec3(0.0, 0.0, 4.0);
	}
	int n = int(floor(t / 30.0));
	float t0 = 30.0 * float(n) + 10.0 * lh_hash(n, 55);
	float age = t - t0;
	if (age < 0.0 || age > 8.0) {
		return vec3(0.0, 0.0, 4.0);
	}
	float env = age < 1.0 ? smoothstep(0.0, 1.0, age) : (age < 6.0 ? 1.0 : 1.0 - smoothstep(6.0, 8.0, age));
	float r = 3.7 + 1.1 * lh_hash(n, 56);
	return vec3(LH_TAU * lh_hash(n, 57) - 0.32 * pow(3.0 / r, 1.5) * age, env, r);
}

// ------------------------------------------------------------------ the disc
// heat (0..1.3) and density of the disc at its own plane point P (rs; x right,
// y toward the viewer)
vec2 lh_disc_shade(vec2 P, float r, float t, float clumps, vec3 hot) {
	float tc = sqrt(max(1.0 - lh_tilt * lh_tilt, 0.0));
	float psi = atan(P.y, P.x);
	float dens = smoothstep(3.0, 3.5, r) * (1.0 - smoothstep(LH_OUT - 2.0, LH_OUT, r));
	float heat = pow(clamp(1.0 - (r - 3.0) / (LH_OUT - 3.0), 0.0, 1.0), 0.85);
	// streaky rings, each turning rigidly at its own Keplerian rate: they slip
	// past one another
	float ring = floor((r - 3.0) / 0.40);
	float rc = 3.0 + (ring + 0.5) * 0.40;
	float om = 0.32 * pow(3.0 / rc, 1.5);
	float ang = psi + om * t;
	float tex = lh_snoise3(vec3(cos(ang) * (1.2 + 0.3 * rc), sin(ang) * (1.2 + 0.3 * rc), ring * 1.73));
	float fine = lh_snoise2(vec2(r * 9.0, ang * 3.0 + ring));
	heat += 0.09 * tex + 0.05 * fine;
	// Doppler: the side coming toward us burns hotter
	float beta = sqrt(0.5 / max(r - 1.0, 0.05));
	heat += 0.40 * beta * (-cos(psi)) * tc;
	// clumps falling in, hidden behind the shadow by the trace itself
	if (clumps > 0.0) {
		for (int i = 0; i < 10; i++) {
			float fi = float(i);
			float Tf = 46.0 + 31.0 * fract(fi * 0.618);
			float cyc = t / Tf + fract(fi * 0.371);
			float ph = fract(cyc);
			float r0 = LH_OUT - 0.6;
			float rcl = r0 - (r0 - 3.2) * ph;
			float s = (r0 - 3.2) / Tf;
			float Ak = 0.32 * 5.196;
			float acl = fi * 2.399 + floor(cyc) * 1.7 - (2.0 * Ak / s) * (pow(rcl, -0.5) - pow(r0, -0.5));
			vec2 dd = P - rcl * vec2(cos(acl), sin(acl));
			heat += 0.35 * clumps * exp(-dot(dd, dd) / 0.02) * smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.9, 1.0, ph));
		}
	}
	if (hot.y > 0.0) {
		vec2 dd = P - hot.z * vec2(cos(hot.x), sin(hot.x));
		heat += 0.5 * hot.y * exp(-dot(dd, dd) / 0.18);
	}
	return vec2(heat, dens);
}

// one sample at S: (heat x alpha, alpha, captured)
vec3 lh_sample(vec2 S, float t, float clumps, vec3 hot) {
	float tc = sqrt(max(1.0 - lh_tilt * lh_tilt, 0.0));
	float b = length(S);
	if (b > lh_dims.x * 0.98) {
		return vec3(0.0);
	}
	float cap = b < LH_SHADOW ? 1.0 : 0.0;
	float al = atan(S.y, S.x);
	float sa = sin(al), ca = cos(al);
	float ph0 = atan(-lh_tilt, sa * tc);
	if (ph0 <= 0.0) {
		ph0 += LH_PI;
	}
	float H = 0.0, A = 0.0;
	// the image that went round the hole, then the direct one over it
	for (int k = 1; k >= 0; k--) {
		float ph = ph0 + float(k) * LH_PI;
		float uu = lh_lens_at(b, ph).r;
		if (uu >= 0.97 || uu <= 1.0 / LH_OUT) {
			continue;
		}
		float r = 1.0 / uu;
		float sp = sin(ph), cp = cos(ph);
		vec2 P = r * vec2(sp * ca, -lh_tilt * sp * sa + tc * cp);
		vec2 hd = lh_disc_shade(P, r, t, clumps, hot);
		// the image that went round fades out at the photon ring (no line round
		// the shadow) and is a cooler arc, two bands down: a hint of the lensing,
		// not a second disc. Opaque, so it never blends to in-between colours.
		float a = hd.y * (k == 1 ? 0.9 * smoothstep(1.06, 1.38, b / LH_SHADOW) : 1.0);
		float hh = hd.x - (k == 1 ? 0.30 : 0.0);
		H = H * (1.0 - a) + hh * a;
		A = A * (1.0 - a) + a;
	}
	return vec3(H, A, cap);
}

vec3 lh_colour(float heat) {
	if (heat > 1.22) {
		return lh_pal[7];
	}
	int i = clamp(int(floor(heat * 6.0)) + 1, 1, 6);
	return lh_pal[i];
}

vec4 lh_disc(vec2 S, float px_rs, float t, float clumps, vec3 hot, out float captured) {
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		vec2 o = (vec2(float(j & 1), float(j >> 1)) - 0.5) * px_rs;
		acc += lh_sample(S + o, t, clumps, hot);
	}
	acc *= 0.25;
	captured = acc.z;
	if (acc.y <= 0.004) {
		return vec4(0.0);
	}
	return vec4(lh_colour(acc.x / acc.y), acc.y);
}

// ------------------------------------------------------------------ round it
float lh_behind(vec2 S) {
	float b = length(S);
	float bb = max(b, LH_SHADOW + 0.05);
	float defl = lh_lens_at(bb, 0.0).g;
	float beta = bb - 7.6 * tan(min(defl, 1.25));
	beta = mix(beta, bb, smoothstep(13.0, 22.0, bb));
	return beta / max(b, 1e-4);
}

float lh_squeeze(vec2 S) {
	float gap = smoothstep(1.04, 1.85, length(S) / LH_SHADOW);
	return mix(0.01, 1.0, gap * gap);
}

vec3 lh_cool(vec2 S, float amount) {
	float b = length(S);
	float c = smoothstep(1.6, 4.0, b / LH_SHADOW) * (1.0 - smoothstep(15.0, 22.5, b)) * amount;
	return mix(vec3(1.0), vec3(0.62, 0.62, 1.15), c);
}

float lh_glow(vec2 S) {
	float b = length(S);
	float rr = b / LH_SHADOW;
	return 1.0 / (1.0 + pow(rr / 1.9, 2.6)) * smoothstep(1.3, 2.0, rr) * (1.0 - smoothstep(12.0, 24.0, b));
}

vec3 lh_exact_hdr(vec3 lin, float exposure) {
	float M = max(max(lin.r, lin.g), lin.b);
	if (M < 1e-5) {
		return vec3(0.0);
	}
	float M2 = min(M, 0.94);
	vec3 l2 = lin * (M2 / M);
	float m = -log(1.0 - M2);
	return l2 * (m / M2) / exposure;
}
