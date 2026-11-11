shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R1 HYPERSPACE, the world pass: the approved film's r1.py `frame()` per pixel. The sky
// bent toward the pinhole and rung by the shock, the lifted stars' homes painted bare while
// they are streaks, the streaks and flow read from the light buffers, the pinhole, the hull
// lit by its drive's pulses and the pinhole's rim, the two launch frames, the aftermath.
// Why: docs/why/SeqHyperspace.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_light.gdshaderinc"
#include "res://shaders/jump/jump_r1.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D aux2 : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform sampler2D light_back : filter_nearest, repeat_disable;
uniform sampler2D light_front : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float d_in_max = 34.0;
uniform float hull_on = 0.0;
uniform float mask_on = 0.0;
uniform vec2 vp = vec2(772.0, 281.0);
uniform vec2 core = vec2(0.0);
uniform float mid_y = 282.0;
uniform float tail_x = 90.0;
uniform float ink_w = 236.0;
// this instant
uniform float t = 0.0;
uniform float k_hit = -1.0;
uniform float S = 0.0;
uniform float after = 0.0;
uniform float bend_on = 0.0;
uniform float s = 0.0;
uniform float tw = -1.0;
uniform float hold = 0.0;
uniform float pin_g = 0.0;
uniform float tight = 0.0;
uniform float flick = 1.0;
// the hull's place: its offset, its stretch about the tail, its squash about the middle line
uniform vec2 ship_d = vec2(0.0);
uniform float sxs = 1.0;
uniform float sqy = 1.0;
uniform float hot = 0.0;
uniform float place_on = 1.0;

const float T_WAKE = 0.7;
const float T_HOLD = 4.55;

float hsdf(vec2 h) {
	return j_hull_sdf(sdf, h, ship.zw, sdf_pad, ink_rect);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 px = SCREEN_PIXEL_SIZE;

	// --- the sky, bent toward the pinhole while the drive pulls, rung by the shock after
	vec2 dv = p - vp;
	float r = length(vec2(dv.x, dv.y * 1.4));
	float m = 0.0;
	if (bend_on > 0.5) {
		m += 0.30 * (S / 0.72) * exp(-r / 210.0);
	}
	if (k_hit >= 0.0) {
		float front = 12.0 + 420.0 * pow(k_hit, 0.8);
		float amp = 0.16 * exp(-k_hit / 0.7);
		m -= amp * exp(-pow((r - front) / 16.0, 2.0)) * sign(r - front + 1e-3);
		m += 0.30 * exp(-k_hit / 0.12) * exp(-r / 210.0);
	}
	vec2 q = abs(m) > 1e-3 ? floor(vp + dv * (1.0 + m) + 0.5) : p;
	vec3 sky = j_world(screen, px, q, world);
	bool aft = after > 0.5;
	if (mask_on > 0.5) {
		vec2 qc = clamp(q, world.xy, world.xy + world.zw - 1.0);
		vec4 mk = texture(mask, (qc - world.xy + 0.5) / world.zw);
		if (mk.a > 0.0) {
			// a lifted star's home: bare sky while the star is a streak, the star while a dot
			float u = (mk.a * 255.0 - 1.0) / 254.0 * 0.15;
			vec2 head;
			vec2 tail;
			r1_star(qc, vp, S, aft, false, u, head, tail);
			sky = mix(mk.rgb, sky, r1_keep(length(head - tail), aft));
		}
	}

	// --- light behind the hull: the streaks, the pinhole, the drive's glow, the aftermath
	vec3 Lline = j_light(light_back, p, world);
	vec3 Lglow = vec3(0.0);
	if (pin_g > 0.0) {
		float g = pin_g;
		Lglow += j_splat(p, vp, 1.0 + 1.6 * g * (1.0 - 0.7 * tight), R1_WHT, (0.6 + 3.0 * g + 3.0 * tight) * flick, 1.0);
		Lglow += j_splat(p, vp, 5.0 + 16.0 * g * (1.0 - 0.6 * tight), R1_VIO, 0.25 + 0.9 * g, 1.0);
		Lglow += j_splat(p, vp, 30.0 + 40.0 * g * (1.0 - 0.5 * tight), R1_VIO, 0.08 + 0.25 * g, 1.0);
		float bar = exp(-pow((p.y - vp.y) / (0.55 + 0.3 * g), 2.0)) * exp(-abs(p.x - vp.x) / (20.0 + 120.0 * g + 160.0 * tight));
		Lline += bar * (0.4 * g + 1.0 * tight) * R1_LIL;
	}
	if (tw >= 0.0) {
		Lglow += j_splat(p, core + ship_d, 6.0 + 20.0 * s, R1_VIO, 0.12 + 0.7 * s, 1.6);
	}
	if (sxs > 1.0) {
		// launching: a tapered smear of light ahead of the hull into the pinhole
		float x_end = tail_x + ship_d.x + ink_w * sxs;
		float seg = exp(-pow((p.y - mid_y) / (sxs > 3.0 ? 1.3 : 2.5), 2.0));
		seg *= (p.x > tail_x + ship_d.x && p.x < vp.x) ? 1.0 : 0.0;
		seg *= clamp(1.0 - (p.x - x_end) / 160.0, 0.0, 1.0);
		Lglow += seg * 1.3 * R1_LIL;
	}
	if (k_hit >= 0.0) {
		if (k_hit > 1.0 / 60.0) {
			float kk = k_hit - 1.0 / 60.0;
			float gone = tail_x + (vp.x - tail_x) * pow(j_ease(kk / 1.25), 0.8);
			float f = exp(-kk / 0.9);
			float in_ = (p.x > gone && p.x <= vp.x) ? 1.0 : 0.0;
			float core_ = exp(-pow((p.y - mid_y) / (0.5 + 2.5 * exp(-kk / 0.06)), 2.0)) * in_;
			float taper = clamp((p.x - gone) / 60.0, 0.0, 1.0);
			Lline += core_ * taper * 2.4 * f * (R1_WHT * 0.5 + R1_LIL * 0.5);
			Lglow += exp(-pow((p.y - mid_y) / 5.0, 2.0)) * in_ * taper * 0.45 * f * R1_VIO;
			float ai = exp(-kk / 0.09);
			if (ai > 0.03) {
				vec4 hp = j_hull_px(hull, p - ship.xy, ship.zw);
				if (hp.a > 0.0) {
					Lline += pow((hp.r + hp.g + hp.b) / 3.0, 1.5) * 2.2 * ai * (R1_VIO * 0.7 + R1_LIL * 0.3);
				}
			}
		}
		float pk = exp(-k_hit / 0.18);
		Lglow += j_splat(p, vp, 2.0, R1_WHT, 6.0 * pk, 1.0);
		Lglow += j_splat(p, vp, 26.0 + 60.0 * k_hit, R1_VIO, 0.8 * exp(-k_hit / 0.25), 1.0);
		float bar = exp(-pow((p.y - vp.y) / 0.6, 2.0)) * exp(-abs(p.x - vp.x) / (400.0 * exp(-k_hit / 0.5) + 20.0));
		Lline += bar * 2.2 * exp(-k_hit / 0.30) * R1_LIL;
		float vbar = exp(-pow((p.x - vp.x) / 0.6, 2.0)) * exp(-abs(p.y - vp.y) / (90.0 * exp(-k_hit / 0.3) + 6.0));
		Lline += vbar * 1.0 * exp(-k_hit / 0.20) * R1_LIL;
		float front = 12.0 + 420.0 * pow(k_hit, 0.8);
		float ring = exp(-pow((r - front) / (6.0 + 12.0 * k_hit), 2.0)) * exp(-k_hit / 0.30);
		Lglow += ring * 0.20 * (R1_VIO * 0.7 + R1_MAG * 0.3);
	}

	// --- the hull: stretched about its tail on the launch frames, lit by the drive's pulses
	vec4 hs = vec4(0.0);
	float Lh = 0.0;
	if (place_on > 0.5 && hull_on > 0.5) {
		float ink_top = ship.y + ink_rect.y;
		float sx_ = floor((p.x - ship_d.x - tail_x) / sxs + 0.5);
		float sy_ = floor((p.y - ship_d.y - mid_y) / sqy + (mid_y - ink_top) + 0.5);
		vec2 h = vec2(ink_rect.x + sx_, ink_rect.y + sy_);
		vec4 hp = j_hull_px(hull, h, ship.zw);
		if (hp.a > 0.0) {
			hs = vec4(hp.rgb, 1.0);
			if (tw >= 0.0 && sxs <= 1.0) {
				vec4 ax = texture(aux, (h + 0.5) / ship.zw);
				vec4 ax2 = texture(aux2, (h + 0.5) / ship.zw);
				float seam = ax.r;
				vec2 hc = h + ship.xy;
				float dcore = length(vec2(hc.x - core.x, (hc.y - core.y) * 1.7));
				float a2 = 3.2 / (T_HOLD - T_WAKE);
				float b2 = 1.1;
				float last = floor(b2 * tw + a2 * tw * tw);
				float hv = 0.0;
				for (int j = 0; j < 4; j++) {
					float pk = last - float(j);
					if (pk < 0.0) {
						break;
					}
					float tp = (-b2 + sqrt(b2 * b2 + 4.0 * a2 * pk)) / (2.0 * a2);
					float dtp = tw - tp;
					float front = dtp * (160.0 + 160.0 * s);
					float amp = (0.18 + 0.55 * s) * exp(-dtp / 0.22);
					hv += exp(-pow((dcore - front) / (5.0 + 6.0 * s), 2.0)) * amp * (0.25 + 1.5 * seam);
					hv += amp * 1.6 * exp(-dcore / 7.0) * exp(-dtp / 0.08);
				}
				if (hold < 0.5) {
					hv += (0.10 + 0.45 * s) * exp(-dcore / (10.0 + 26.0 * s)) * (0.4 + 0.6 * seam);
					hv += seam * 0.22 * s * (dcore < 40.0 + 180.0 * s ? 1.0 : 0.0);
				} else {
					hv += 0.55 * exp(-dcore / 40.0) * (0.3 + 0.9 * seam);
				}
				if (pin_g > 0.0) {
					// the pinhole's rim light on the faces that look at it
					vec2 l = vp - (hc + ship_d);
					vec2 N = vec2(hsdf(h + vec2(1.0, 0.0)) - hsdf(h - vec2(1.0, 0.0)), hsdf(h + vec2(0.0, 1.0)) - hsdf(h - vec2(0.0, 1.0)));
					float facing = clamp(dot(normalize(N + 1e-6), l / (length(l) + 1e-6)), 0.0, 1.0);
					hv += facing * facing * (ax2.a * 0.8 + ax2.b * 0.3) * (0.15 + 1.1 * pin_g) * (1.0 + 0.6 * hold);
				}
				Lh = hv;
			}
		}
	}

	// --- composite: back light behind the hull, the glow, the hull, the near light
	bool hid = hs.a > 0.5;
	vec3 o3 = j_add_line(sky, hid ? vec3(0.0) : Lline, 9.0);
	if (hid) {
		vec3 base = mix(hs.rgb, R1_WHT, hot);
		float qv = j_glow_q(Lh, 7.0, p);
		vec3 lit = base * (1.0 + 0.9 * qv) * (1.0 - 0.25 * qv * (1.0 - R1_VIO)) + qv * (R1_VIO * 0.40 + R1_LIL * 0.12);
		o3 = mix(lit, R1_WHT, clamp((Lh - 3.0) / 2.0, 0.0, 1.0));
	} else {
		o3 = j_add_glow(o3, Lglow, 7.0, p);
	}
	o3 = j_add_line(o3, j_light(light_front, p, world), 9.0);
	COLOR = vec4(clamp(o3, 0.0, 1.0), 1.0);
}
