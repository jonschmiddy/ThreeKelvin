shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE CLOUD A SYSTEM SITS IN, BAKED ONCE (direction C, "Alive"; `SkyBake.field`).
// The sky is at infinity: these fields never zoom, and only slide by the
// cloud's share of the pan. They hold DENSITY, never light: the system's sun
// lights them every frame from wherever it is on screen (`sky_nebula`), so the
// light rides the star while the cloud stays put, and the flow map carries the
// gas along its current.
//
// One texel is one 2x2 block of the sky: texel (i, j) holds the field at sky
// pixel ((i - MB) * 2 + 1, (j - MB) * 2 + 1), MB blocks of margin for the
// slide and the flow's reach.
//
// The shapes are the cloud's own, the same noise as before (`SkyWeather`
// places its weather by a port of it, so a strike still lands in thick gas and
// a jet on a pillar's tip); what changed is what is made of them -- pillars
// with shoulders and heads, a dust bank they rise from, puffed billows, far gas
// and veils behind -- and that the young cluster an emission cloud is lit by is
// the system's own sun.
//
// mode 0 -> T0: r gas (what glows or scatters), g dust (optical depth),
//               b, a the kind's own (emission: the rose body, lane;
//               reflection: striations, fine knots; planetary: clumps;
//               remnant: the two nets of strands; dark: its lit face)
// mode 1 -> T1: r billows (`bil`), g fine, b far gas, a veil
// mode 2 -> T2: gradients of T0's gas (rg) and dust (ba), 0.5 + g * GK
//
// LEGACY (`legacy`, for `sky_nebula_legacy.gdshader`): the old cloud's own
// noises, raw, for it to stream on the current instead of churning in place.
// A value that is ridged after reading is held in two channels, high and low
// (`hilo`), so its crest keeps its edge:
// mode 0 -> emission: fing (rg), lane (ba); reflection: striations (r);
//           planetary: clumps (r); remnant: fil (rg), fil2 (ba)
// mode 1 -> billows (rg, high and low), fine (b)

uniform int mode = 0;
uniform int kind = 0;
uniform int shape = 0;
uniform float sd = 0.0;
// the bake's size in texels, and its margin in blocks
uniform vec2 tex = vec2(576.0, 366.0);
uniform float mb = 48.0;
// the star's sky pixel at no pan (the cluster an emission cloud is lit by)
uniform vec2 cc = vec2(480.0, 270.0);
uniform sampler2D src : filter_nearest, repeat_disable;
// THE PILLARS (`SkyBake.em_pillars`): base and tip (sky px), widths at base and head, seed
uniform vec4 pil_a[8];
uniform vec4 pil_b[8];
uniform int n_pil = 0;
uniform bool legacy = false;

#include "res://shaders/sky_noise.gdshaderinc"

const float GK = 4.0;

vec2 spot(float k, vec2 lo, vec2 hi) {
	return lo + vec2(hash2(vec2(k * 13.0 + sd * 17.0, 5.0)), hash2(vec2(k * 17.0 + sd * 13.0, 9.0))) * (hi - lo);
}

// puffy billows (1-|n|), for the edges of a mass only
float billow2(vec2 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 6; i++) { if (i >= oct) break; s += a * (1.0 - abs(kitSnoise2(p))); n += a; p = kitRot2(p) * 2.07 + vec2(3.3, 7.1); a *= 0.52; }
	return s / n;
}


// A DARK COLUMN OF DUST (C's): leaning and kinked from base to tip, a knotty
// head a little wider than its neck, its edges eroded and soft (gas thinning
// out, never a cut: crisp edges read as logs), denser in its heart. Optical
// depth 0..1.
float pillar(vec2 P, vec2 base, vec2 tip, float w0, float w1, float psd) {
	vec2 ba = tip - base;
	float L = length(ba);
	vec2 u = ba / L, nrm = vec2(-u.y, u.x);
	vec2 d = P - base;
	float along = dot(d, u) / L;
	float s = clamp(along, 0.0, 1.0);
	float bend = (sin(s * 2.4 + psd) * 0.06 + sin(s * 6.1 + psd * 2.3) * 0.02) * L * s;
	float side = dot(d, nrm) - bend;
	float lumps = kitFbm2(vec2(along * L / 40.0, sign(side) * 2.3) + psd * 7.3, 3);
	float rough = kitFbm2(vec2(along * L / 11.0, side / 11.0) + psd * 3.9, 3);
	float w = mix(w0, w1, pow(s, 0.65)) * (1.0 + 0.45 * lumps) + 5.0 * rough;
	float body = smoothstep(w + 7.0, w - 6.0, abs(side)) * smoothstep(-0.02, 0.06, along) * smoothstep(1.0, 0.92, along);
	vec2 hc = base + u * L * 0.95 + nrm * bend;
	vec2 hq = P - hc;
	float hd = length(hq) + w1 * 0.40 * kitFbm2(hq / 8.0 + psd * 5.1, 3);
	float head = smoothstep(w1 * 1.22 + 7.0, w1 * 1.22 - 5.0, hd);
	float k = 0.78 + 0.22 * kitFbm2(P / 17.0 + psd * 3.1, 3);
	return sat(max(body, head)) * k;
}
// a broad dark cloud a pillar grows out of, so none of them floats in from the edge
float dust_mass(vec2 P, vec2 c, vec2 r, float msd) {
	vec2 q = (P - c) / r;
	float e = length(q) + 0.35 * kitFbm2(P / 46.0 + msd, 4) + 0.12 * kitFbm2(P / 13.0 + msd * 2.0, 3);
	return smoothstep(1.05, 0.70, e) * (0.85 + 0.15 * kitFbm2(P / 30.0 + msd, 3));
}

// far gas, deeper and cooler, seen through the gaps (C's `farGas`)
float far_gas(vec2 P) {
	vec2 q = P / 540.0 + vec2(5.3, 2.1) + sd;
	vec2 w = kitWarp2(q, 0.7, 3);
	float f = kitFbm2(w, 5);
	return 0.25 + 0.75 * smoothstep(-0.35, 0.55, f) * (0.65 + 0.35 * billow2(w * 3.0, 3));
}
// thin threads through the cloud (C's `veilFil`)
float veil_fil(vec2 P) {
	vec2 q = P / 250.0 + vec2(1.9, 7.7) + sd;
	vec2 w = kitWarp2(q, 0.85, 4);
	float r = kitRidge2(w * 1.25, 5);
	return smoothstep(0.58, 0.93, r) * smoothstep(-0.25, 0.35, kitFbm2(q * 0.6 + 4.0, 3));
}

vec4 field0(vec2 sp) {
	vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
	float bil = fbm(u * 1.4, 5);
	float fine = fbm(u * 4.2 + vec2(5.0, sd), 4);
	if (kind == 0 || kind == 1) {
		// the cloud's masses round the star: the old body, puffed out by a
		// warped simplex billow so its edges are round lobes, never contours
		vec2 dc = sp - cc;
		float r = length(dc) / 720.0;
		vec2 dir = dc / max(length(dc), 1.0);
		float body = sm(0.25, 0.75, bil + 0.2 * (1.0 - min(r, 1.4)));
		vec2 q = sp / 520.0 + vec2(1.7, 0.6) * sd;
		vec2 w = q + 0.7 * vec2(kitFbm2(q * 0.7 + 3.1, 4), kitFbm2(q * 0.7 + 9.7, 4));
		float detail = kitFbm2(w * 3.4 + 1.3, 4);
		float wisp = kitRidge2(kitWarp2(w * 2.2 + 6.0, 0.6, 3), 4);
		// big soft masses with dark gaps between them: a smooth power curve, never
		// a threshold (thresholds make camouflage)
		float mass = pow(sm(0.30, 0.82, bil + 0.10 * (1.0 - min(r, 1.4)) + 0.10 * detail), 1.5);
		float g = 0.04 + mass * (0.80 + 0.35 * detail) + 0.18 * wisp * smoothstep(0.05, 0.4, mass) * (1.0 - mass);
		// a little more gas round the star, for its light to push against
		g += 0.12 * exp(-pow(length(dc * vec2(1.0, 1.24)) / 300.0, 2.0)) * (0.6 + 0.4 * fbm(sp / 80.0 + 3.0, 3));
		// THE PILLARS rising toward the star (`SkyBake.em_pillars`), each from a dark mass of its own
		float pil = 0.0;
		for (int k = 0; k < 8; k++) {
			if (k >= n_pil) break;
			vec4 pa = pil_a[k], pb = pil_b[k];
			pil = max(pil, pillar(sp, pa.xy, pa.zw, pb.x, pb.y, pb.z));
			vec2 bd0 = normalize(pa.xy - pa.zw);
			pil = max(pil, dust_mass(sp, pa.xy + bd0 * 40.0, vec2(pb.x * 2.6, pb.x * 2.2), pb.z + 2.0));
		}
		float lane = ridge(fbm(u * 2.2 + vec2(sd, 11.0), 3), 9.0);
		// a dust bank low in the sky, which the pillars rise out of (a broad edge
		// in lumps, never a straight line)
		float ba = (hash2(vec2(sd * 7.0, 61.0)) - 0.5) * 1.0;
		vec2 bd = vec2(sin(ba), cos(ba));
		float top = 214.0 + 40.0 * kitFbm2(sp / vec2(140.0, 90.0) + 3.0 + sd, 4) + 14.0 * kitFbm2(sp / 34.0 + 9.0, 3);
		float bank = smoothstep(top - 4.0, top + 30.0, dot(dc, bd)) * (0.82 + 0.18 * kitFbm2(sp / 40.0, 3));
		float tau = clamp(max(pil * 1.05, bank) + lane * 0.45 * body, 0.0, 1.0);
		if (kind == 1) {
			// a reflection cloud is the same dust, lit from outside: thinner pillars,
			// soft lanes; and its combed striations
			tau = clamp(pil * 0.75 + bank * 0.85 + lane * 0.30 * body, 0.0, 1.0);
			float stri = noise2(vec2(dot(u, vec2(0.8, 0.6)) * 12.0, dot(u, vec2(-0.6, 0.8)) * 1.5) + vec2(sd, 0.0));
			return vec4(clamp(g, 0.0, 1.0), tau, stri, fbm(u * 6.0 + vec2(sd, 3.0), 3));
		}
		return vec4(clamp(g, 0.0, 1.0), tau, body, lane);
	} else if (kind == 2) {
		// the shell's knots (worked out about its centre, in its own frame)
		vec2 pc = spot(1.0, vec2(-80.0, -60.0), vec2(1040.0, 600.0));
		float aa = hash2(vec2(sd, 77.0)) * 3.1416;
		vec2 d = sp - pc;
		vec2 dd = vec2(d.x * cos(aa) - d.y * sin(aa), d.x * sin(aa) + d.y * cos(aa));
		if (shape == 1 || shape == 2) dd.y *= 1.5;
		float R0 = max(380.0, length(pc - vec2(480.0, 270.0)) * (0.75 + 0.35 * hash2(vec2(sd, 41.0))));
		float clump = fbm(dd / R0 * 9.0 + vec2(sd, 4.0), 3);
		return vec4(0.0, 0.0, clump, 0.0);
	} else if (kind == 5) {
		// THE CORE (C): the galaxy's heart, warm clouds swirling round the hole in
		// a gentle two-armed spiral (read on the circle, no seam), dark lanes
		// cutting the swirl
		vec2 r = (sp - cc) / vec2(1.0, 0.55);
		float rho = length(r);
		vec2 q = sp / 360.0 + 3.0 + sd * 0.1;
		vec2 w = kitWarp2(q, 0.7, 4);
		float big = kitFbm2(w * 0.9, 4) * 0.5 + 0.5;
		float detail = kitFbm2(w * 3.2 + 1.3, 4);
		vec2 dirc = r / max(rho, 1e-3);
		float spiral = 0.5 + 0.5 * sin(atan(dirc.y, dirc.x) * 2.0 - log(max(rho, 20.0)) * 3.2 + kitFbm2(w, 3) * 1.6);
		float d = pow(sat((big * 0.75 + spiral * 0.35 - 0.35) / 0.5), 1.4);
		float gas = d * (0.82 + 0.3 * detail) * (0.35 + 0.65 * smoothstep(1300.0, 150.0, rho));
		float s2 = sin(atan(dirc.y, dirc.x) * 2.0 - log(max(rho, 20.0)) * 3.2 + 1.9 + 0.8 * kitFbm2(sp / 160.0, 3));
		float lane = smoothstep(0.70, 0.97, s2) * smoothstep(50.0, 170.0, rho) * (0.4 + 0.6 * (kitFbm2(sp / 60.0, 4) * 0.5 + 0.5));
		return vec4(clamp(gas, 0.0, 1.0), clamp(lane, 0.0, 1.0), 0.0, 0.0);
	} else if (kind == 3) {
		float fil = ridge(fbm(u * 2.4 + vec2(sd, 2.0), 4), 14.0);
		float fil2 = ridge(fbm(u * 3.6 + vec2(3.0, sd), 4), 16.0);
		return vec4(0.0, 0.0, fil, fil2);
	} else {
		// DARK: dust that hides what is behind it; between its clumps a little dim gas
		float d = sm(0.3, 0.66, bil + 0.15 * (fine - 0.5));
		float gas = (1.0 - d) * sm(0.2, 0.5, bil);
		return vec4(gas, d, 0.0, 0.0);
	}
}

// a value 0..1 in two channels: the high step and what is left of it
vec2 hilo(float v) {
	float s = clamp(v, 0.0, 1.0) * 255.0;
	return vec2(floor(s) / 255.0, fract(s));
}

// LEGACY's noises (the old `sky_nebula` terms, without their churn)
vec4 legacy0(vec2 sp) {
	vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
	if (kind == 0) {
		vec2 c0 = spot(1.0, vec2(-160.0, -120.0), vec2(1120.0, 660.0));
		vec2 dc = sp - c0;
		float r = length(dc) / 720.0;
		vec2 dir = dc / max(length(dc), 1.0);
		return vec4(hilo(fbm(dir * 2.8 + vec2(r * 0.9 + sd, sd * 2.0), 3)), hilo(fbm(u * 2.2 + vec2(sd, 11.0), 3)));
	} else if (kind == 1) {
		return vec4(noise2(vec2(dot(u, vec2(0.8, 0.6)) * 12.0, dot(u, vec2(-0.6, 0.8)) * 1.5) + vec2(sd, 0.0)), 0.0, 0.0, 1.0);
	} else if (kind == 2) {
		vec2 pc = spot(1.0, vec2(-80.0, -60.0), vec2(1040.0, 600.0));
		float aa = hash2(vec2(sd, 77.0)) * 3.1416;
		vec2 d = sp - pc;
		vec2 dd = vec2(d.x * cos(aa) - d.y * sin(aa), d.x * sin(aa) + d.y * cos(aa));
		if (shape == 1 || shape == 2) dd.y *= 1.5;
		float R0 = max(380.0, length(pc - vec2(480.0, 270.0)) * (0.75 + 0.35 * hash2(vec2(sd, 41.0))));
		return vec4(fbm(dd / R0 * 9.0 + vec2(sd, 4.0), 3), 0.0, 0.0, 1.0);
	} else if (kind == 3) {
		return vec4(hilo(fbm(u * 2.4 + vec2(sd, 2.0), 4)), hilo(fbm(u * 3.6 + vec2(3.0, sd), 4)));
	}
	return vec4(0.0, 0.0, 0.0, 1.0);
}

void fragment() {
	vec2 ij = floor(UV * tex);
	if (legacy && mode != 2) {
		vec2 sp = (ij - mb) * 2.0 + 1.0;
		if (mode == 0) {
			COLOR = legacy0(sp);
		} else {
			vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
			COLOR = vec4(hilo(fbm(u * 1.4, 5)), fbm(u * 4.2 + vec2(5.0, sd), 4), 1.0);
		}
	} else if (mode == 2) {
		ivec2 c = ivec2(ij), mx = ivec2(tex) - 1;
		vec4 xp = texelFetch(src, clamp(c + ivec2(1, 0), ivec2(0), mx), 0), xm = texelFetch(src, clamp(c - ivec2(1, 0), ivec2(0), mx), 0);
		vec4 yp = texelFetch(src, clamp(c + ivec2(0, 1), ivec2(0), mx), 0), ym = texelFetch(src, clamp(c - ivec2(0, 1), ivec2(0), mx), 0);
		vec4 xp2 = texelFetch(src, clamp(c + ivec2(2, 0), ivec2(0), mx), 0), xm2 = texelFetch(src, clamp(c - ivec2(2, 0), ivec2(0), mx), 0);
		vec4 yp2 = texelFetch(src, clamp(c + ivec2(0, 2), ivec2(0), mx), 0), ym2 = texelFetch(src, clamp(c - ivec2(0, 2), ivec2(0), mx), 0);
		// per sky pixel (a texel is two), smoothed over two texels so it never creases
		vec2 gG = (vec2(xp.r - xm.r, yp.r - ym.r) * 2.0 + vec2(xp2.r - xm2.r, yp2.r - ym2.r)) / 16.0;
		vec2 gD = (vec2(xp.g - xm.g, yp.g - ym.g) * 2.0 + vec2(xp2.g - xm2.g, yp2.g - ym2.g)) / 16.0;
		COLOR = clamp(vec4(gG, gD) * GK + 0.5, 0.0, 1.0);
	} else if (mode == 0) {
		vec2 sp = (ij - mb) * 2.0 + 1.0;
		COLOR = clamp(field0(sp), 0.0, 1.0);
	} else {
		vec2 sp = (ij - mb) * 2.0 + 1.0;
		vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
		float bil = fbm(u * 1.4, 5);
		float fine = fbm(u * 4.2 + vec2(5.0, sd), 4);
		COLOR = vec4(bil, fine, far_gas(sp), veil_fil(sp));
	}
}
