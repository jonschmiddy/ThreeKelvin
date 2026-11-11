shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R14 BIG CRUNCH, the light and the hull over the poured sky: the torn edge of what is left
// of space, the aura hugging the hull, the ball and its halo, the pressure rings, the held
// point, the slam's flare, the hull lit by the light pouring in and crushed with the ball,
// then the burst's shock rings and ember. The film's r14.py `frame()` after `sky_pour`.
// Why: docs/why/SeqBigCrunch.md#compose

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D aux2 : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform sampler2D fil_lin : filter_linear, repeat_enable;
uniform sampler2D fil_nn : filter_nearest, repeat_enable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 win = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float d_in_max = 34.0;
uniform float hull_on = 0.0;
uniform vec2 pc = vec2(203.0, 282.0);
uniform vec2 core = vec2(0.0);
uniform float hk = 1.0;
uniform float t = 0.0;
uniform float p_t = 0.0;
uniform float th = 0.0;
uniform float rb = 0.0;
uniform vec2 ab0 = vec2(0.0);
// the torn edge's strength and its lobes' fade-in; the aura's strength
uniform float edge_k = 0.0;
uniform float lobe_k = 0.0;
uniform float aura = 0.0;
// the ball (on, crunch), the beats' rings (k since each, -1 off), the held point
// (k, inhale, breath, on), the slam (k, -1 off)
uniform vec2 ball = vec2(0.0);
uniform float beat_k[4];
uniform vec4 hold = vec4(0.0);
uniform float slam_k = -1.0;
// the hull: shown, its scale about the sink, its darkening, its tremble, the gulps' waves
uniform float show_ship = 0.0;
uniform float fsc = 1.0;
uniform float sil = 0.0;
uniform vec2 tremble = vec2(0.0);
uniform float lit_on = 0.0;
uniform float gulp_t[4];
uniform int gulp_n = 0;
// the burst (k since it, -1 off)
uniform float kb = -1.0;

const vec3 VOID = vec3(5.0, 3.0, 10.0) / 255.0;
const float NFIL = 720.0;

float shock_r(float k) {
	return 8.0 + 1150.0 * (1.0 - exp(-k / 0.40));
}

float dhull(vec2 p) {
	return j_hull_sdf(sdf, p - ship.xy, ship.zw, sdf_pad, ink_rect);
}

// The filament noise over angle: smooth, wrapped `scale` times round.
float fil_at(float a, float scale) {
	float x = (a + PI) / TAU * scale * NFIL;
	return texture(fil_lin, vec2((x + 0.5) / NFIL, 0.5)).r;
}

float fil_nearest(float a) {
	float x = floor((a + PI) / TAU * NFIL);
	return texture(fil_nn, vec2((x + 0.5) / NFIL, 0.5)).r;
}

// The hull at p: its lit picture and coverage, whole at rest, crushed about the sink.
vec4 hull_at(vec2 p) {
	if (fsc >= 0.999) {
		vec2 h = p - tremble - ship.xy;
		vec4 px = j_hull_px(hull, h, ship.zw);
		if (px.a <= 0.0) {
			return vec4(0.0);
		}
		vec3 lit = px.rgb;
		if (lit_on > 0.5) {
			vec4 ax1 = texture(aux, (h + 0.5) / ship.zw);
			float seam = ax1.r;
			float din = ax1.g * 32.0;
			float rim_h = clamp(1.0 - (din - 1.0) / 4.0, 0.0, 1.0);
			vec2 hp = h + ship.xy;
			float dcore = length(vec2(hp.x - core.x, (hp.y - core.y) * 1.7)) / hk;
			vec3 hv = (0.4 + 2.2 * p_t + 1.6 * th) * rim_h * (J_LIL * 0.6 + J_WHT * 0.4);
			hv += (0.15 + 1.1 * p_t * p_t + 0.4 * th) * (J_LIL * 0.5 + J_VIO * 0.5);
			for (int g = 0; g < gulp_n; g++) {
				float dtp = gulp_t[g];
				float front = dtp * 420.0;
				float wave = exp(-pow((dcore - front) / 9.0, 2.0)) * exp(-dtp / 0.25) * 1.6;
				hv += wave * (0.2 + 1.5 * seam) * J_WHT;
				hv += 1.8 * exp(-dcore / 8.0) * exp(-dtp / 0.06) * J_WHT;
			}
			float lm = max(hv.r, max(hv.g, hv.b));
			float vq = 1.0 - exp(-lm);
			float q = clamp(floor(vq * 8.0 + j_dith2(p) * min(1.0, vq * 4.0)) / 8.0, 0.0, 1.0);
			vec3 colr = hv / max(lm, 1e-6);
			lit = px.rgb * (1.0 + 0.9 * q * (0.4 + 0.6 * colr)) + q * colr * 0.55;
			float hot = clamp((lm - 3.2) / 2.0, 0.0, 1.0);
			lit = mix(lit, J_WHT, hot);
		}
		lit = lit * (1.0 - sil) + (px.rgb * 0.18 + VOID) * sil;
		return vec4(lit, 1.0);
	}
	vec3 acc = vec3(0.0);
	float cov = 0.0;
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			vec2 sp = pc + (p + vec2((float(i) + 0.5) / 3.0, (float(j) + 0.5) / 3.0) - 0.5 - pc) / fsc;
			vec4 px = j_hull_px(hull, floor(sp - ship.xy), ship.zw);
			if (px.a > 0.0) {
				acc += px.rgb;
				cov += 1.0;
			}
		}
	}
	if (cov <= 0.0) {
		return vec4(0.0);
	}
	return vec4((acc / cov) * 0.18 + VOID, cov / 9.0);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec3 sky = j_world(screen, SCREEN_PIXEL_SIZE, p, world);
	vec2 d = p - pc;
	float RP = length(d) + 1e-3;
	vec2 U = d / RP;
	float ANG = atan(d.y, d.x);
	vec3 Lunder = vec3(0.0);
	vec3 Lover = vec3(0.0);

	// --- the drain edge: the torn border of what is left of space, running in from every side
	if (edge_k > 0.0) {
		float sx = U.x > 0.0 ? (win.x + win.z - 1.0 - pc.x) / U.x : (U.x < 0.0 ? (win.x - pc.x) / U.x : 1e9);
		float sy = U.y > 0.0 ? (win.y + win.w - 1.0 - pc.y) / U.y : (U.y < 0.0 ? (win.y - pc.y) / U.y : 1e9);
		float RMAX = min(sx, sy);
		float R0 = sqrt(RP * RP + ab0.x * ab0.x) + ab0.y;
		float edge = R0 - RMAX;
		float fil = fil_at(ANG, 0.5);
		float lobes = 13.0 * sin(3.0 * ANG + 1.7 * t) + 8.0 * sin(7.0 * ANG - 2.9 * t + 1.0) + 5.0 * sin(13.0 * ANG + 4.1 * t);
		float e = edge + 12.0 * (fil - 0.5) + lobes * lobe_k;
		float wdt = 3.5 + 6.0 * fil;
		float rim = exp(-pow(max(e, -40.0) / wdt, 2.0)) * (0.6 + 0.9 * fil) * (1.0 + 1.5 * th) * edge_k;
		Lunder += rim * (J_LIL * 0.45 + J_VIO * 0.55);
		float rim_max = 1.5 * (1.0 + 1.5 * th) * edge_k;
		Lunder += exp(-max(-e, 0.0) / 26.0) * (e < 0.0 ? 1.0 : 0.0) * 0.25 * rim_max * (0.5 + fil) * J_VIO;
	}

	// --- the hull, and the aura that hugs it early in the pour
	vec4 hs = vec4(0.0);
	if (show_ship > 0.5 && hull_on > 0.5) {
		hs = hull_at(p);
	}
	if (aura > 0.0) {
		float dh = max(dhull(p), 0.0);
		Lunder += aura * exp(-dh / (4.0 + 10.0 * p_t)) * (J_LIL * 0.5 + J_VIO * 0.5);
		Lunder += aura * 0.6 * exp(-dh / (14.0 + 30.0 * p_t)) * (J_VIO * 0.7 + J_ROSE * 0.3);
	}

	// --- the ball: white body threaded with light running inward, its rim, its halo
	if (ball.x > 0.5) {
		float crunch = ball.y;
		float boil = (1.5 + 0.03 * rb) * (sin(5.0 * ANG + 9.0 * t) * 0.6 + sin(9.0 * ANG - 13.0 * t + 1.0) * 0.4);
		float Fb = RP - rb + (rb > 12.0 ? boil : 0.0);
		float body = 0.4 + 2.2 * p_t * p_t + 3.5 * crunch + 1.6 * th;
		float filn = fil_nearest(ANG);
		float run = 0.5 + 0.5 * sin(0.06 * (RP + 520.0 * t) + 6.0 * filn);
		float threads = 0.65 + 0.7 * filn * run;
		float inside = clamp(0.5 - Fb / 2.0, 0.0, 1.0);
		float cor = exp(-RP / max(rb * 0.5, 1.5));
		float dens = inside * body * threads * (0.5 + 1.4 * cor);
		if (show_ship > 0.5) {
			dens *= 1.0 - (0.55 + 0.2 * sil) * hs.a;
		}
		Lover += dens * (J_WHT * 0.82 + J_LIL * 0.18);
		float line = exp(-pow((Fb - 0.5) / 1.0, 2.0)) * (1.6 + 1.8 * th + 2.0 * crunch);
		Lover += line * J_WHT;
		float halo_w = 3.0 + 5.0 * p_t + 6.0 * th;
		float halo = exp(-max(Fb, 0.0) / halo_w) * (Fb > 0.0 ? 1.0 : 0.0) * (0.9 + 1.2 * p_t + 1.4 * th + 1.5 * crunch);
		Lunder += halo * (J_VIO * 0.8 + J_ROSE * 0.2);
		Lunder += 0.12 * (p_t + crunch) * exp(-max(Fb, 0.0) / 18.0) * J_VIO;
		for (int b = 0; b < 4; b++) {
			float k2 = beat_k[b];
			if (k2 >= 0.0) {
				float rr = 150.0 * hk * 1.5 + 900.0 * pow(k2, 0.8);
				Lunder += exp(-pow((RP - rr) / 1.4, 2.0)) * 1.1 * exp(-k2 / 0.16) * (J_LIL * 0.5 + J_VIO * 0.5);
			}
		}
	}

	// --- the held point: a hard white pip with four short spikes, breathing, then inhaling
	if (hold.w > 0.5) {
		float br = hold.z;
		Lover += j_splat(p, pc, 1.3, J_WHT, 6.0 * br, 1.0);
		Lunder += j_splat(p, pc, 8.0 * hold.y + 1.0, J_VIO, 1.3 * br, 1.0);
		vec2 dp = p - floor(pc);
		float dd = max(abs(dp.x), abs(dp.y));
		if ((dp.y == 0.0 || dp.x == 0.0) && dd >= 2.0 && dd <= 8.0) {
			Lover += 1.6 * br * pow(1.0 - dd / 9.0, 1.5) * J_LIL;
		}
	}
	// the slam: the drive bites
	if (slam_k >= 0.0) {
		Lunder += j_splat(p, core, 10.0 + 40.0 * slam_k, J_VIO, 2.2 * exp(-slam_k / 0.08), 1.4);
		Lover += j_splat(p, core, 3.0 + 6.0 * slam_k, J_WHT, 2.5 * exp(-slam_k / 0.05), 1.0);
	}

	// --- compose: sky, light under, hull, light over
	vec3 o = j_add_glow(sky, Lunder, 7.0, p);
	o = mix(o, hs.rgb, hs.a);
	o = j_add_glow(o, Lover, 7.0, p);

	// --- the burst: the shock ring, a second fainter one, the ember
	if (kb >= 0.0 && kb < 1.3) {
		vec3 Lb = vec3(0.0);
		float S = shock_r(kb);
		float st = exp(-kb / 0.45);
		float dd = RP - S;
		Lb += exp(-pow(dd / 1.3, 2.0)) * 2.6 * st * J_WHT;
		Lb += exp(-max(dd, 0.0) / 12.0) * (dd > 0.0 ? 1.0 : 0.0) * 1.3 * st * (J_VIO * 0.75 + J_ROSE * 0.25);
		Lb += exp(min(dd, 0.0) / 30.0) * (dd <= 0.0 ? 1.0 : 0.0) * 0.45 * st * J_LIL;
		float S2 = shock_r(max(kb - 0.09, 0.0)) * 0.82;
		Lb += exp(-pow((RP - S2) / 1.6, 2.0)) * 0.5 * st * (kb > 0.09 ? 1.0 : 0.0) * (J_LIL * 0.6 + J_VIO * 0.4);
		Lb += j_splat(p, pc, 3.0 + 6.0 * kb, J_VIO, 1.6 * exp(-kb / 0.15), 1.0);
		Lb += j_splat(p, pc, 1.5, J_WHT, 3.0 * exp(-kb / 0.15), 1.0);
		o = j_add_glow(o, Lb, 7.0, p);
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
