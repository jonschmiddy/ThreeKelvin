shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R10 COIL RAIL, the world pass: the approved film's r10.py `frame()` per pixel. The rings,
// the rail, the pulses, the field lines, the arcs, the hull's place and light, the cone and
// the afterglow are each a few numbers `SeqCoilRail.step` works out for this instant; this
// pass is spatial. Distances along the rail are in the film's pixels scaled by `s`, radii by
// `hk` (JumpPlace: space scales, time never).
// Why: docs/why/SeqCoilRail.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D aux2 : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float d_in_max = 34.0;
uniform float hull_on = 0.0;
// the frame: the nose at rest, the rail row, the drive, the scales
uniform float nose = 325.0;
uniform float nose0 = 319.0;
uniform float s = 1.0;
uniform float hk = 1.0;
uniform float ax = 282.0;
uniform vec2 core = vec2(0.0);
uniform float t = 0.0;
uniform float c = 0.0;
uniform float hold_e = 0.0;
uniform float kf = -1.0;
uniform float kj = -1.0;
uniform float rr = 0.0;
// the rings and their thrown ghosts: (cx, R, E, squash), yaw, on
uniform vec4 ring_p[7];
uniform float ring_yaw[7];
uniform float ring_on[7];
uniform float ring_x[7];
uniform float ring_uf[7];
uniform float ring_fl[7];
uniform float ring_pop[7];
uniform vec4 ghost_p[14];
uniform float ghost_yaw[14];
uniform float ghost_on[14];
// the bow emitter (x, y, strength, charge), the rail (on, x end, line, side rows)
uniform vec4 emit = vec4(0.0);
uniform vec4 rail = vec4(0.0);
// the chase pulses (head x, length), the field lines, the arcs (7 points each)
uniform float pulse_x[16];
uniform float pulse_ln[16];
uniform int pulse_n = 0;
uniform float field_k = 0.0;
uniform vec2 arc_pts[84];
uniform int arc_n = 0;
uniform float arc_w = 0.0;
// the ship: its offset, 0 still 1 running 2 spear -1 gone, the run's progress, the light it
// faces (x, gain), the waves of charge running forward, the smear, the spear
uniform vec2 ship_d = vec2(0.0);
uniform int ship_mode = 0;
uniform float run_p = 0.0;
uniform vec2 face = vec2(0.0);
uniform float wave_t[20];
uniform int wave_n = 0;
uniform float hold_dim = 1.0;
uniform vec4 smear = vec4(0.0);
uniform vec2 spear = vec2(0.0);
// after the shot: the bow, the jump point, the afterglow (f, gone, tip, width), the pinch
uniform float xn = 0.0;
uniform float xj = 0.0;
uniform vec4 after = vec4(0.0);
uniform float fade_j = 1.0;
uniform vec3 pinch = vec3(0.0);

const vec3 VIO = vec3(0.62, 0.36, 1.00);
const vec3 LIL = vec3(0.86, 0.74, 1.00);
const vec3 WHT = vec3(1.00, 0.96, 1.00);
const vec3 MAG = vec3(1.00, 0.36, 0.84);
const vec3 ROSE = vec3(1.00, 0.78, 0.95);
const float V0 = 520.0;
const float ACC = 4200.0;
const float T_FIRE = 5.0;
const float T_WAKE = 0.6;

float run_k(float d) {
	return (-V0 + sqrt(V0 * V0 + 2.0 * ACC * max(d, 0.0))) / ACC;
}

float tent(float d, float w) {
	return max(0.0, 1.0 - d / w);
}

// A splat with its own x and y squash (r10.py `splat`).
vec3 splat2(vec2 p, vec2 at, float r, vec3 col, float k, float sx, float sy) {
	vec2 d = p - at;
	float d2 = (d.x * sx) * (d.x * sx) + (d.y * sy) * (d.y * sy);
	return k * exp(-d2 / (2.0 * r * r)) * col;
}

// A point of light of `mass` through the film's two box blurs (r 2 and r 7, twice each).
vec3 blur_pt(vec2 p, vec2 at, float mass, vec3 col) {
	vec2 d = abs(p - at);
	float g = mass * (3.0 / 25.0 * tent(d.x, 5.0) * tent(d.y, 5.0) + 2.0 / 225.0 * tent(d.x, 15.0) * tent(d.y, 15.0));
	return g * col;
}

vec3 ring_col(float E) {
	float a = clamp(E - 0.3, 0.0, 1.0);
	vec3 cc = mix(VIO, MAG, a);
	float w = clamp((E - 1.6) / 2.5, 0.0, 1.0);
	return mix(cc, WHT, w);
}

// The four glints that turn with the spin.
float glints(float th) {
	float nd = 0.0;
	for (int j = 0; j < 4; j++) {
		float w = th - float(j) * PI * 0.5;
		w -= TAU * floor((w + PI) / TAU);
		nd += exp(-pow(w / 0.16, 2.0));
	}
	return nd;
}

// One point of the ring's curve seen from pixel p: the line there, its band, its glow.
void ring_pt(float th, float d, float d2, bool front, float n, float E, float rri, bool glow, vec3 col, vec3 cf,
		inout vec3 Lf, inout vec3 Lb, inout vec3 Lg) {
	float kn = 1.0 / sqrt(1.0 + n / 120.0);
	float nd = glints(th - rri);
	float wf = E * (0.55 + 0.9 * nd) * kn;
	float wb = E * (0.20 + 0.45 * nd) * kn;
	if (d < 0.5) {
		if (front) {
			Lf += wf * 1.6 * cf;
		} else {
			Lb += wb * 1.4 * (col * 0.8 + VIO * 0.2);
		}
	}
	if (front && d2 < 0.5) {
		Lf += wf * 0.7 * col;
	}
	if (glow) {
		Lg += E * 0.9 * kn * (0.6 * tent(d, 5.0) + 0.1333 * tent(d, 15.0)) * col;
	}
}

// A ring (cx, R, E, squash) at yaw, spun to rri, as the film plotted it: points along the
// ellipse (x = cx + rx sin th, y = ax + ry cos th), the near arc (sin th <= 0.05) in front of
// the hull with a second line a pixel left of it, the far arc behind, the glow seeds blurred.
// The points bunch where the curve turns, so the light is their density per pixel.
void ring_add(vec2 p, vec4 prm, float yaw, float rri, bool glow, inout vec3 Lf, inout vec3 Lb, inout vec3 Lg) {
	float cx = prm.x, R = prm.y, E = prm.z, sq = prm.w;
	if (R < 0.6) {
		if (p.x == floor(cx + 0.5) && p.y == ax) {
			Lf += E * 1.4 * WHT;
		}
		return;
	}
	float n = TAU * R * 1.4 + 12.0;
	float ry = R * (1.0 + sq);
	float rx = max(R * yaw * (1.0 - 2.5 * sq), 1.0);
	vec3 col = ring_col(E);
	vec3 cf = E > 1.2 ? ROSE * 0.5 + col * 0.5 : col;
	float dx = p.x - cx, dy = p.y - ax;
	float uy = dy / ry, ux = dx / rx;
	vec3 Lf2 = vec3(0.0), Lb2 = vec3(0.0), Lg2 = vec3(0.0);
	// the two side arcs, each column's point of the curve, where it is steeper than 45 degrees
	if (abs(uy) < 1.0) {
		float sr = sqrt(1.0 - uy * uy);
		float xs = rx * sr;
		float xp = rx * abs(uy) / (ry * sr + 1e-6);
		if (xp < 1.0) {
			float sl = 1.0 / sqrt(1.0 + xp * xp);
			for (int g = -1; g <= 1; g += 2) {
				float ex = float(g) * sr;
				float th = atan(ex, uy);
				float speed = length(vec2(rx * cos(th), ry * sin(th)));
				float dens = n / TAU / max(speed, 0.5);
				float d = abs(dx - float(g) * xs) * sl;
				float d2 = abs(dx + 1.0 - float(g) * xs) * sl;
				ring_pt(th, d, d2, ex <= 0.05, n, E * dens, rri, glow, col, cf, Lf2, Lb2, Lg2);
			}
		}
	}
	// the caps, each row's point, where the curve is flatter than 45 degrees
	if (abs(ux) < 1.0) {
		float sr = sqrt(1.0 - ux * ux);
		float ys = ry * sr;
		float yp = ry * abs(ux) / (rx * sr + 1e-6);
		if (yp < 1.0) {
			float sl = 1.0 / sqrt(1.0 + yp * yp);
			for (int g = -1; g <= 1; g += 2) {
				float ey = float(g) * sr;
				float th = atan(ux, ey);
				float speed = length(vec2(rx * cos(th), ry * sin(th)));
				float dens = n / TAU / max(speed, 0.5);
				float d = abs(dy - float(g) * ys) * sl;
				float d2 = abs(dy - float(g) * ys) * sl + 1.0;
				ring_pt(th, d, d2, ux <= 0.05, n, E * dens, rri, glow, col, cf, Lf2, Lb2, Lg2);
			}
		}
	}
	Lf += Lf2;
	Lb += Lb2;
	Lg += Lg2;
}

float dhull(vec2 h) {
	return j_hull_sdf(sdf, h, ship.zw, sdf_pad, ink_rect);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float dy = p.y - ax;
	float ady = abs(dy);
	float sdy = sign(dy);

	// --- the sky: pinched toward the rail in the charge, pushed out by the shock cone
	float sy = p.y;
	if (pinch.x > 0.0) {
		float xwin = clamp((p.x - nose) / (60.0 * s), 0.0, 1.0) * clamp((pinch.y - p.x) / (60.0 * s), 0.0, 1.0);
		sy = ax + dy * (1.0 + pinch.x * xwin * exp(-ady / (110.0 * hk)));
	}
	float age = -1.0;
	float rf = 0.0;
	bool live = false;
	if (kf >= 0.0) {
		float d_f = (p.x - nose0) / s;
		age = t - (T_FIRE + run_k(d_f));
		live = p.x >= nose0 - 4.0 * s && p.x <= xn && age >= 0.0;
		rf = hk * (44.0 + 300.0 * max(age, 0.0));
		if (live) {
			float d = ady - rf;
			float A = 7.0 * hk * exp(-age / 0.5);
			sy += -sdy * A * exp(-pow(d / 9.0, 2.0)) * (d < 0.0 ? 1.0 : 0.0) + sdy * A * 0.5 * exp(-pow(d / 14.0, 2.0)) * (d > 0.0 ? 1.0 : 0.0);
		}
	}
	vec3 sky = j_world(screen, SCREEN_PIXEL_SIZE, vec2(p.x, floor(sy + 0.5)), world);

	vec3 Lline = vec3(0.0);
	vec3 Lfront = vec3(0.0);
	vec3 Lglow = vec3(0.0);
	float Lhull = 0.0;

	// --- the bow emitter
	if (emit.z > 0.0) {
		vec2 e = emit.xy;
		float ce = emit.w;
		Lglow += j_splat(p, e, 1.2 + 1.0 * ce, WHT, emit.z * 1.4, 1.0);
		Lglow += j_splat(p, e, 5.0 + 8.0 * ce, MAG, 0.18 * emit.z, 1.0);
		Lglow += j_splat(p, e, 18.0 + 16.0 * ce, VIO, 0.05 * emit.z, 1.0);
	}

	// --- the rail and the chase pulses racing down it
	if (rail.x > 0.5 && p.x >= nose + 2.0 * s && p.x <= rail.y) {
		if (dy == 0.0) {
			Lline += rail.z * (LIL * 0.5 + MAG * 0.5);
		} else if (ady == 1.0) {
			Lline += rail.w * VIO;
		}
	}
	for (int j = 0; j < pulse_n; j++) {
		float xh = pulse_x[j];
		float ln = pulse_ln[j];
		if (dy == 0.0 && p.x >= max(nose, xh - ln) && p.x <= min(xh, ring_x[6])) {
			float u = clamp((xh - p.x) / ln, 0.0, 1.0);
			Lline += (1.6 * pow(1.0 - u, 1.5) + 0.1) * (WHT * 0.6 + MAG * 0.4);
		}
		Lglow += blur_pt(p, vec2(xh, ax), 0.5 * TAU, MAG);
	}

	// --- field lines between neighbouring rings: three arcs a side, dashes crawling forward
	if (field_k > 0.0) {
		for (int i = 0; i < 6; i++) {
			float x0 = floor(ring_x[i]), x1 = floor(ring_x[i + 1]);
			if (p.x < x0 + 2.0 || p.x > x1 - 2.0) {
				continue;
			}
			float u = (p.x - ring_x[i]) / (ring_x[i + 1] - ring_x[i]);
			float su = pow(sin(PI * u), 0.9);
			for (int b = 0; b < 3; b++) {
				float bb = b == 0 ? 7.0 : (b == 1 ? 15.0 : 26.0);
				float wgt = b == 0 ? 0.55 : (b == 1 ? 0.30 : 0.16);
				float yo = 58.0 * hk + 1.0 + bb * hk * su;
				if (floor(ax + yo + 0.5) == p.y || floor(ax - yo + 0.5) == p.y) {
					float dash = mod(floor(u * 6.0 - rr * 0.35 + bb * 0.1), 2.0) == 0.0 ? 1.0 : 0.0;
					Lline += wgt * field_k * (0.35 + 0.65 * dash) * (VIO * 0.6 + MAG * 0.4);
				}
			}
		}
	}
	// the arcs: jagged lightning ring to ring, one pixel a column
	for (int a = 0; a < arc_n; a++) {
		for (int sgi = 0; sgi < 6; sgi++) {
			vec2 q0 = arc_pts[a * 7 + sgi];
			vec2 q1 = arc_pts[a * 7 + sgi + 1];
			if (p.x < floor(q0.x + 0.5) || p.x > floor(q1.x + 0.5)) {
				continue;
			}
			float yy = q0.y + (q1.y - q0.y) * clamp((p.x - q0.x) / max(q1.x - q0.x, 1e-3), 0.0, 1.0);
			if (floor(yy + 0.5) == p.y) {
				Lfront += arc_w * (WHT * 0.5 + MAG * 0.5);
			}
		}
	}

	// --- the rings, their ghosts, their streaks, their light
	vec3 Lrf = vec3(0.0), Lrb = vec3(0.0), Lrg = vec3(0.0);
	for (int i = 0; i < 7; i++) {
		if (ring_on[i] < 0.5) {
			continue;
		}
		vec4 rp = ring_p[i];
		float rri = rr + float(i) * 0.7;
		ring_add(p, rp, ring_yaw[i], rri, true, Lrf, Lrb, Lrg);
		for (int g = 0; g < 2; g++) {
			int gi = i * 2 + g;
			if (ghost_on[gi] > 0.5) {
				vec3 gf = vec3(0.0), gb = vec3(0.0), gg = vec3(0.0);
				ring_add(p, ghost_p[gi], ghost_yaw[gi], rri, false, gf, gb, gg);
				Lrb += gf + gb;
			}
		}
		float uf = ring_uf[i];
		if (uf < 1.15 && dy == 0.0) {
			float ln_ = 70.0 * s * max(0.0, 1.0 - uf);
			if (ln_ > 1.0 && p.x >= max(nose + 2.0 * s, rp.x - ln_) && p.x <= rp.x) {
				float uu = clamp((rp.x - p.x) / ln_, 0.0, 1.0);
				Lrb += 1.4 * pow(1.0 - uu, 1.4) * max(0.0, 1.0 - uf) * (ROSE * 0.6 + MAG * 0.4);
			}
		}
		// each ring lights a little of the space inside and round it
		Lglow += splat2(p, vec2(rp.x, ax), rp.y * 0.55, VIO, 0.020 * rp.z, 1.0, 0.54);
		float f = ring_fl[i];
		if (f > 0.02) {
			Lglow += splat2(p, vec2(rp.x, ax), rp.y * 0.45, WHT * 0.7 + MAG * 0.3, 0.9 * f, 2.6, 0.6);
			float bar = exp(-pow((p.x - rp.x) / 0.6, 2.0)) * exp(-ady / (rp.y * 0.9 * f + 3.0)) * (ady < rp.y * 2.2 ? 1.0 : 0.0);
			Lfront += bar * 1.4 * f * ROSE;
		}
		float kp = ring_pop[i];
		if (kp >= 0.0) {
			Lglow += j_splat(p, vec2(rp.x, ax), 1.5 + 4.0 * kp, WHT, 2.5 * exp(-kp / 0.05), 1.0);
			Lglow += j_splat(p, vec2(rp.x, ax), 6.0 + 30.0 * kp, MAG, 0.3 * exp(-kp / 0.08), 1.0);
		}
	}
	Lline += Lrb;
	Lfront += Lrf;
	Lglow += Lrg;

	// --- the hull: its place, the light crawling forward, the rings' rim light, the run's heat
	vec4 hpx = vec4(0.0);
	bool have_hull = hull_on > 0.5 && ship_mode >= 0 && ship_mode < 2;
	if (have_hull) {
		vec2 h = p - ship_d - ship.xy;
		hpx = j_hull_px(hull, h, ship.zw);
		if (hpx.a > 0.0) {
			vec4 ax1 = texture(aux, (h + 0.5) / ship.zw);
			vec4 ax2 = texture(aux2, (h + 0.5) / ship.zw);
			float seam = ax1.r;
			float lum = (hpx.r + hpx.g + hpx.b) / 3.0;
			vec2 hp = p - ship_d;
			float dcore = length(vec2((hp.x - core.x) / hk, (hp.y - core.y) * 1.7 / hk));
			float fwd = max((hp.x - core.x) / hk, 0.0);
			float hv = 0.0;
			if (ship_mode == 0 && t > T_WAKE) {
				for (int w = 0; w < wave_n; w++) {
					float dtp = wave_t[w];
					float front = dtp * (260.0 + 300.0 * c);
					float amp = (0.25 + 0.6 * c) * exp(-dtp / 0.25);
					hv += exp(-pow((fwd - front) / (5.0 + 5.0 * c), 2.0)) * amp * (0.2 + 1.6 * seam);
				}
				hv += (0.08 + 0.5 * c) * exp(-dcore / (10.0 + 30.0 * c)) * (0.4 + 0.6 * seam);
				hv += seam * 0.25 * c * (fwd < 40.0 + 160.0 * c ? 1.0 : 0.0);
				vec2 nrm = vec2(dhull(h + vec2(1.0, 0.0)) - dhull(h - vec2(1.0, 0.0)), dhull(h + vec2(0.0, 1.0)) - dhull(h - vec2(0.0, 1.0)));
				nrm = normalize(nrm + vec2(1e-5, 0.0));
				vec2 l = vec2(face.x - hp.x, ax - hp.y);
				float facing = clamp(dot(nrm, l) / (length(l) + 1e-6), 0.0, 1.0);
				hv += facing * facing * (ax2.a * 0.9 + ax2.b * 0.3) * face.y;
			}
			if (ship_mode == 1) {
				float pp = run_p;
				hv += (0.25 + 3.6 * pow(pp, 2.2)) * (0.4 + 0.6 * lum) + (0.5 + 1.0 * pp) * seam;
				hv += exp(-((nose - hp.x) / hk) / (10.0 + 140.0 * pow(pp, 1.5))) * 2.8;
			}
			Lhull = hv;
		}
		if (ship_mode == 0 && t > T_WAKE) {
			Lglow += j_splat(p, core + ship_d, (6.0 + 16.0 * c) * hk, VIO, 0.05 + 0.35 * c, 1.6);
		}
	}
	// the run's smear: the hull's own light dragged back along its rows
	if (ship_mode == 1 && smear.z > 0.0 && p.y >= ship.y && p.y < ship.y + ship.w
			&& p.x >= ship.x + smear.x && p.x < ship.x + smear.y + ship.z) {
		for (int si = 0; si < 10; si++) {
			float xo = floor(smear.x + (smear.y - smear.x) * float(si) / 10.0 + 0.5);
			vec4 sp = j_hull_px(hull, p - vec2(xo, 0.0) - ship.xy, ship.zw);
			if (sp.a > 0.0) {
				float wv = (0.06 + 0.22 * float(si) / 10.0) * smear.w;
				float ls = pow((sp.r + sp.g + sp.b) / 3.0, 2.0) * 1.8;
				Lline += wv * ls * (LIL * 0.5 + MAG * 0.5);
			}
		}
	}
	// the spear: a needle of light from where the hull was to the jump point
	if (ship_mode == 2 && ady <= 3.0 && p.x >= spear.x && p.x <= spear.y) {
		float u = (p.x - spear.x) / max(spear.y - spear.x, 1.0);
		if (ady == 0.0) {
			Lfront += (3.0 * u + 0.6) * WHT;
		} else {
			float wv = ady == 1.0 ? 0.9 : (ady == 2.0 ? 0.35 : 0.12);
			Lfront += (3.0 * u + 0.3) * wv * ROSE;
		}
	}

	// --- after the shot: the cone, its haze, the rail's afterglow, the jump
	if (kf >= 0.0) {
		if (live) {
			float fade = exp(-age / 0.9) * fade_j * clamp(((p.x - nose0) / s + 1.0) / 30.0, 0.2, 1.0);
			if (floor(ax + sdy * rf + 0.5) == p.y || (dy == 0.0 && rf < 0.5)) {
				Lline += 1.5 * fade * (LIL * 0.5 + MAG * 0.5);
			}
			if (floor(ax + sdy * rf * 0.82 + 0.5) == p.y) {
				Lline += 0.45 * fade * VIO;
			}
			if (floor(ax + sdy * (rf + 1.0) + 0.5) == p.y) {
				Lline += 0.4 * fade * MAG;
			}
			if (ady < rf) {
				Lglow += fade * (0.03 + 0.22 * exp(-pow((ady - rf) / 10.0, 2.0))) * 0.5 * (VIO * 0.7 + MAG * 0.3);
			}
		}
		if (p.x > after.y && p.x <= after.z) {
			float taper = clamp((p.x - after.y) / (70.0 * s), 0.0, 1.0);
			Lline += exp(-pow(dy / after.w, 2.0)) * taper * 2.2 * after.x * (WHT * 0.4 + ROSE * 0.6);
			Lglow += exp(-pow(dy / 6.0, 2.0)) * taper * 0.35 * after.x * MAG;
		}
	}
	if (kj >= 0.0) {
		vec2 J = vec2(xj, ax);
		float pk = exp(-kj / 0.16);
		Lglow += j_splat(p, J, 2.2, WHT, 7.0 * pk, 1.0);
		Lglow += j_splat(p, J, 22.0 + 70.0 * kj, MAG, 0.9 * exp(-kj / 0.22), 1.0);
		Lglow += j_splat(p, J, 60.0 + 120.0 * kj, VIO, 0.25 * exp(-kj / 0.35), 1.0);
		float bar = exp(-pow(dy / 0.6, 2.0)) * exp(-abs(p.x - xj) / (520.0 * exp(-kj / 0.45) + 20.0));
		Lfront += bar * 2.4 * exp(-kj / 0.32) * ROSE;
		float vbar = exp(-pow((p.x - xj) / 0.6, 2.0)) * exp(-ady / (60.0 * exp(-kj / 0.25) + 6.0)) * (ady < 150.0 ? 1.0 : 0.0);
		Lfront += vbar * 1.3 * exp(-kj / 0.2) * LIL;
		float front = 10.0 + 380.0 * pow(kj, 0.8);
		float rr2 = length(vec2((p.x - xj) * 0.8, dy));
		Lglow += exp(-pow((rr2 - front) / (5.0 + 10.0 * kj), 2.0)) * exp(-kj / 0.3) * 0.22 * (VIO * 0.6 + MAG * 0.4);
	}

	// --- compose: line light behind the hull, the glow, the hull lit, the near light
	bool al = hpx.a > 0.0;
	vec3 o = j_add_line(sky, al ? vec3(0.0) : Lline, 9.0);
	o = j_add_glow(o, al ? Lglow * 0.3 : Lglow, 7.0, p);
	if (al) {
		float q = j_glow_q(Lhull, 7.0, p);
		vec3 lit = hpx.rgb * (1.0 + 0.9 * q) * (1.0 - 0.25 * q * (1.0 - MAG)) + q * (MAG * 0.30 + VIO * 0.15);
		float hotc = clamp((Lhull - 2.6) / 1.6, 0.0, 1.0);
		o = mix(lit, WHT, hotc);
	}
	o = j_add_line(o, Lfront, 9.0);
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
