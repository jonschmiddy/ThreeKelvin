shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R12 NEGATIVE, the world pass: the approved film's r12.py `frame()` per pixel. The
// field F (< 0 inside the negative) comes from the mode and the few numbers
// `SeqNegative.step` works out for this instant; everything else is spatial.
// Why: docs/why/SeqNegative.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 core = vec2(0.0);
uniform vec2 pc = vec2(0.0);
uniform float d_in_max = 34.0;
// 0 wake, 1 wave, 2 tighten, 3 collapse, 4 point, 5 snap, 6 ring, 7 after
uniform int mode = 0;
uniform float t = 0.0;
uniform float hull_on = 0.0;
uniform float R = 0.0;
uniform float reach = 1100.0;
uniform float wob_amp = 0.0;
uniform float wob_t = 0.0;
uniform float fsc = 1.0;
uniform float lift = 0.0;
uniform float throb = 0.0;
uniform float ech = 0.0;
uniform float band = 3.5;
uniform float rim_g = 0.0;
uniform float ink_on = 0.0;
uniform float inkk = 0.0;
uniform float tight = 0.0;
uniform float front_amp = 0.0;
uniform float pull_k = 0.0;
uniform float k_snap = -1.0;
uniform float wake_s = 0.0;
uniform float glow_on = 0.0;
uniform float pulse_t[9];
uniform float pulse_s[9];
uniform int pulse_n = 0;
uniform vec3 disc = vec3(0.0);
uniform vec2 tremble = vec2(0.0);
uniform vec4 after = vec4(0.0);
uniform float after_on = 0.0;
uniform float point_on = 0.0;
uniform float full_mix = 0.0;
uniform float full_lift = 0.04;
uniform vec3 pal[40];
uniform int pal_n = 0;

const vec3 NEG0 = vec3(12.0, 9.0, 22.0) / 255.0;
const vec3 NEG1 = vec3(40.0, 32.0, 62.0) / 255.0;
const float NEG_STOPS[6] = float[6](0.0, 0.30, 0.52, 0.68, 0.80, 0.90);
const vec3 NEG_COLS[6] = vec3[6](vec3(12.0, 9.0, 22.0), vec3(40.0, 32.0, 62.0), vec3(92.0, 80.0, 122.0),
	vec3(146.0, 134.0, 170.0), vec3(182.0, 174.0, 200.0), vec3(208.0, 203.0, 222.0));
const vec3 HOLE_RAMP[5] = vec3[5](vec3(255.0, 253.0, 255.0), vec3(242.0, 236.0, 253.0),
	vec3(224.0, 214.0, 247.0), vec3(202.0, 190.0, 236.0), vec3(178.0, 164.0, 222.0));

float wobble(float ang, float amp, float tt) {
	return amp * (sin(3.0 * ang + 1.3 * tt) * 0.5 + sin(5.0 * ang - 2.1 * tt + 1.0) * 0.3
		+ sin(8.0 * ang + 3.3 * tt + 2.0) * 0.2);
}

float dhull(vec2 p) {
	return j_hull_sdf(sdf, p - ship.xy, ship.zw, sdf_pad, ink_rect);
}

// The negative, unquantised: luminance stretched and inverted through the ramp, the
// colour's complement at half strength.
vec3 neg_raw(vec3 x, float lf) {
	float L = dot(x, vec3(0.30, 0.55, 0.15));
	float v = clamp(1.0 - pow(clamp(L, 0.0, 1.0), 0.45) + lf, 0.0, 1.0);
	vec3 o = NEG_COLS[5];
	for (int i = 0; i < 5; i++) {
		if (v < NEG_STOPS[i + 1]) {
			o = mix(NEG_COLS[i], NEG_COLS[i + 1], (v - NEG_STOPS[i]) / (NEG_STOPS[i + 1] - NEG_STOPS[i]));
			break;
		}
	}
	vec3 chroma = x - vec3(L);
	return clamp(o / 255.0 - chroma * 0.5, 0.0, 1.0);
}

// Snapped to the palette with a pair dither: the nearest colour, the next only where the
// value truly falls between the two.
vec3 quant(vec3 img, vec2 p) {
	if (pal_n == 0) {
		return img;
	}
	vec3 c = floor(clamp(img, 0.0, 1.0) * 255.0 / 8.0) * 8.0 + 4.0;
	int a = 0, s = 0;
	float ad = 1e9, sd = 1e9;
	for (int k = 0; k < pal_n; k++) {
		vec3 dv = c - pal[k];
		float d = dot(dv, dv);
		if (d < ad) { s = a; sd = ad; a = k; ad = d; } else if (d < sd) { s = k; sd = d; }
	}
	vec3 c1 = pal[a], c2 = pal[s];
	vec3 seg = c2 - c1;
	float al = dot(c - c1, seg) / max(dot(seg, seg), 1e-6);
	al = clamp((al - 0.12) / 0.76, 0.0, 1.0);
	return (al > j_dith4(p) ? c2 : c1) / 255.0;
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 dc = p - core;
	float D_C = length(vec2(dc.x, dc.y * 1.15));
	float ang = atan(dc.y * 1.15, dc.x);
	bool gone = mode >= 5;
	bool has_f = mode >= 1 && mode <= 4;

	// --- the region field
	float F = 999.0;
	if (mode == 1) {
		F = D_C + wobble(ang, wob_amp, wob_t) - R;
	} else if (mode == 2) {
		F = dhull(p) + wobble(ang, wob_amp, wob_t) - reach;
	} else if (mode == 3) {
		vec2 sp = pc + (p - pc) / fsc;
		float d = 999.0;
		if (sp.x >= 0.0 && sp.y >= 0.0 && sp.x < 960.0 && sp.y < 540.0) {
			d = dhull(sp) * fsc;
		}
		F = d + wobble(ang, 2.5, wob_t) * fsc - 7.0 * (0.4 + 0.6 * fsc);
	} else if (mode == 4) {
		F = length(p - pc) - 3.0;
	}

	// --- the sky, bent: the front's push, the collapse's pull, the snap ring
	vec2 bend = vec2(0.0);
	if (front_amp > 0.0 && (mode == 1 || mode == 2)) {
		float b = front_amp * exp(-pow((F - 10.0) / 15.0, 2.0));
		vec2 u;
		if (mode == 1) {
			u = dc / (D_C + 1e-3);
		} else {
			u = vec2(dhull(p + vec2(1.0, 0.0)) - dhull(p - vec2(1.0, 0.0)),
				dhull(p + vec2(0.0, 1.0)) - dhull(p - vec2(0.0, 1.0))) * 0.5;
		}
		bend -= b * u;
	}
	if (pull_k > 0.0) {
		float dd = length(p - pc) + 1e-3;
		bend += 9.0 * pull_k * exp(-dd / 160.0) * (p - pc) / dd;
	}
	if (k_snap >= 0.0 && k_snap < 1.2) {
		float rr = length((p - pc) * vec2(1.0, 1.2));
		float front = 10.0 + 820.0 * pow(k_snap, 0.72);
		float a = 3.0 * exp(-k_snap / 0.4);
		float b = a * exp(-pow((rr - front) / 10.0, 2.0)) * sign(rr - front + 1e-3);
		bend += b * (p - pc) / (rr + 1e-3);
	}
	vec3 sky = j_world(screen, SCREEN_PIXEL_SIZE, floor(p + bend + 0.5), world);

	// --- the hull: its picture, its hole of light, its inner distance and coverage
	vec3 ship_rgb = vec3(0.0);
	vec3 hole = vec3(0.0);
	float al = 0.0;
	float d_in = 0.0;
	bool hull_here = hull_on > 0.5 && !gone && fsc > 0.012;
	if (hull_here) {
		if (fsc >= 0.999) {
			vec2 h = p - tremble - ship.xy;
			vec4 px = j_hull_px(hull, h, ship.zw);
			if (px.a > 0.0) {
				vec4 ax = texture(aux, (h + 0.5) / ship.zw);
				ship_rgb = px.rgb;
				hole = HOLE_RAMP[int(ax.b * 4.0 + 0.5)] / 255.0;
				d_in = ax.g * 32.0;
				al = 1.0;
			}
		} else {
			float cov = 0.0;
			for (int i = 0; i < 3; i++) {
				for (int j = 0; j < 3; j++) {
					vec2 sp = pc + (p + vec2((float(i) + 0.5) / 3.0, (float(j) + 0.5) / 3.0) - 0.5 - pc) / fsc;
					vec2 h = floor(sp - ship.xy);
					vec4 px = j_hull_px(hull, h, ship.zw);
					if (px.a > 0.0) {
						vec4 ax = texture(aux, (h + 0.5) / ship.zw);
						ship_rgb += px.rgb;
						hole += HOLE_RAMP[int(ax.b * 4.0 + 0.5)] / 255.0;
						d_in += ax.g * 32.0;
						cov += 1.0;
					}
				}
			}
			if (cov > 0.0) {
				ship_rgb /= cov;
				hole /= cov;
				d_in /= cov;
			}
			al = cov / 9.0;
		}
	}

	// --- the normal world: the drive's glow, the hull lit by its pulses
	vec3 normal = sky;
	if (glow_on > 0.5) {
		vec3 Lg = j_splat(p, core + tremble, 6.0 + 16.0 * wake_s, J_VIO, 0.10 + 0.45 * wake_s, 1.6);
		if (al < 0.5) {
			normal = j_add_glow(normal, Lg, 7.0, p);
		}
	}
	if (al > 0.0) {
		vec3 lit = ship_rgb;
		if (glow_on > 0.5) {
			vec2 hp = p - tremble;
			float dcore = length(vec2(hp.x - core.x, (hp.y - core.y) * 1.7));
			float seam = texture(aux, (hp - ship.xy + 0.5) / ship.zw).r;
			vec3 hv = vec3(0.0);
			for (int j = 0; j < pulse_n; j++) {
				float dtp = t - pulse_t[j];
				if (dtp < 0.0 || dtp > 0.6) {
					continue;
				}
				float s = pulse_s[j];
				float front = dtp * (150.0 + 160.0 * s);
				float amp = (0.5 + 1.1 * s) * exp(-dtp / 0.22);
				float wave = exp(-pow((dcore - front) / (5.0 + 5.0 * s), 2.0)) * amp;
				int m3 = j - 3 * (j / 3);
				vec3 pcol = m3 == 0 ? J_LIL : (m3 == 1 ? J_VIO : J_WHT);
				hv += wave * (0.2 + 1.5 * seam) * pcol;
				hv += amp * 1.4 * exp(-dcore / 7.0) * exp(-dtp / 0.08) * J_WHT;
			}
			hv += (1.6 * seam + 0.25) * wake_s * exp(-dcore / (40.0 + 120.0 * wake_s)) * (J_VIO * 0.6 + J_LIL * 0.4);
			float lm = max(hv.r, max(hv.g, hv.b));
			if (lm > 0.0) {
				float q = j_glow_q(lm, 7.0, p);
				vec3 colr = hv / lm;
				lit = ship_rgb * (1.0 + 0.85 * q * (0.4 + 0.6 * colr)) + q * colr * 0.6;
				float hot = clamp((lm - 3.0) / 2.0, 0.0, 1.0);
				lit = mix(lit, J_WHT, hot);
			}
		}
		normal = mix(normal, lit, al);
	}

	// --- the negative world
	float lf = lift + 0.05 * throb;
	if (mode == 1 && ech > 0.0) {
		float e = exp(-pow((F + 40.0) / 9.0, 2.0)) * 0.10 + exp(-pow((F + 95.0) / 9.0, 2.0)) * 0.06;
		lf -= e * ech;
	}
	vec3 nr = neg_raw(sky, lf);
	if (mode == 1 && F < 0.0) {
		nr += exp(min(F, 0.0) / 30.0) * vec3(10.0, 2.0, 18.0) / 255.0;
	}
	vec3 neg = quant(nr, p);
	if (al > 0.0) {
		vec3 hc = mix(hole, NEG0, inkk);
		float corek = clamp(d_in / 6.0, 0.0, 1.0);
		if (inkk > 0.0 && (1.0 - corek) * 1.4 < inkk * 2.2 - 0.3) {
			hc = NEG0;
		}
		neg = mix(neg, hc, al);
	}
	if (hull_here && fsc > 0.3 && tight < 0.99) {
		float dh = fsc < 0.999 ? dhull(pc + (p - pc) / fsc) * fsc : dhull(p);
		float shade = (0.55 * exp(-max(dh - 1.0, 0.0) / 2.6) + 0.18 * exp(-dh / 12.0)) * (dh > 0.0 ? 1.0 : 0.0);
		shade = floor(shade * (1.0 - tight) * 5.0 + j_dith4(p) * 0.9) / 5.0;
		neg = mix(neg, NEG1, shade);
	}
	if (point_on > 0.5) {
		vec2 dp = abs(p - floor(pc));
		if ((dp.x <= 1.0 && dp.y <= 1.0) || (dp.x <= 2.0 && dp.y == 0.0) || (dp.y <= 2.0 && dp.x == 0.0)) {
			neg = NEG0;
		}
	}

	// --- the mask: inside the negative, a dithered edge
	bool M = false;
	if (!has_f && !gone) {
		if (disc.x > 0.5) {
			float Fd = D_C + wobble(ang, 1.0 + 0.2 * disc.y, disc.z) - disc.y;
			M = clamp(0.5 - Fd / 3.0, 0.0, 1.0) > j_dith4(p);
		}
	} else if (has_f) {
		M = clamp(0.5 - F / band, 0.0, 1.0) > j_dith4(p);
	}
	if (full_mix > 0.0 && full_mix > j_dith4(p)) {
		M = true;
		neg = quant(neg_raw(sky, full_lift), p);
	} else if (mode == 6) {
		float rr = length((p - pc) * vec2(1.0, 1.2));
		float front = 10.0 + 820.0 * pow(k_snap, 0.72);
		float wdt = 4.0 + 6.0 * exp(-k_snap / 0.15);
		float st = exp(-k_snap / 0.5);
		float ring = clamp(1.0 - abs(rr - front) / wdt, 0.0, 1.0) * st * 2.2;
		M = ring > j_dith4(p);
		if (M) {
			neg = quant(neg_raw(sky, -0.05), p);
		}
	}
	vec3 o = M ? neg : normal;

	// --- the front's rim: a white line, violet outside, an ink shadow inside
	if (has_f) {
		float th2 = 1.0 + 1.4 * throb;
		float line = exp(-pow((F - 0.8) / 0.9, 2.0));
		float halo = exp(-max(F - 1.5, 0.0) / 9.0) * (F > 1.0 ? 1.0 : 0.0);
		vec3 Lrim = line * 1.6 * rim_g * th2 * (J_WHT * 0.7 + J_LIL * 0.3)
			+ halo * 0.55 * rim_g * th2 * (J_VIO * 0.75 + J_ROSE * 0.25);
		if (ink_on > 0.5) {
			float ink = 0.6 * exp(min(F + 1.0, 0.0) / 5.0) * (F < -0.5 ? 1.0 : 0.0) * rim_g * (0.8 + 0.4 * throb);
			ink = floor(clamp(ink, 0.0, 0.9) * 4.0 + j_dith4(p) * min(ink * 3.0, 1.0)) / 4.0;
			o = mix(o, NEG1, ink);
		}
		o = j_add_glow(o, Lrim, 7.0, p);
	}

	// --- the afterimage: the hull's inverted picture hanging as light, cooling, eroding
	if (after_on > 0.5) {
		vec2 h = p - ship.xy;
		vec4 px = j_hull_px(hull, h, ship.zw);
		if (px.a > 0.0 && after.y < 0.999) {
			vec4 ax = texture(aux, (h + 0.5) / ship.zw);
			float keep = (ax.g * 32.0 / d_in_max) * 0.85 + 0.15 * (0.02 + 0.98 * j_noise(h));
			if (keep >= after.y) {
				vec3 hcol = HOLE_RAMP[int(ax.b * 4.0 + 0.5)] / 255.0;
				vec3 tint = pow(hcol, vec3(1.6)) * mix(J_WHT, J_VIO * 0.75 + J_LIL * 0.25, after.z);
				o = j_add_glow(o, tint * (0.35 + 1.5 * after.x), 6.0, p);
			}
		}
		o = j_add_glow(o, j_splat(p, pc, 1.0, J_WHT, after.w, 1.0), 7.0, p);
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
