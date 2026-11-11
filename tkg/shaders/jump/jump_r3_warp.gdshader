shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R3 THE RIFT, the warp pass: rift.py `frame` after the ship. Nine taps a pixel through the
// tear's pressure front, the heal's quadrupole ring-down and the point-mass lens (Einstein radius
// rE, frame dragging, a throat of radius rh), then the light: the lip, tidal arcs, photon ring,
// the crack and its scar, flashes, fronts, and the motes from the light buffer.
// Distances are the film's: (screen - Tg) / S.
// Why: docs/why/SeqRift.md#warp-pass

#include "res://shaders/jump/jump_warp.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D lightbuf : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec2 Tg = vec2(600.0, 262.0);
uniform float S = 1.0;
uniform float rE = 0.0;
uniform float rh = 0.0;
uniform float spin = 0.0;
// t - HIT (the tear's front) and t - HEAL - 0.30 (the ring-down)
uniform float k_hit = -1.0;
uniform float k_gw = -1.0;
// before the tear: on, its u, the inhale, the lip's flicker; the tidal arcs (angle, span, radius)
uniform float pre_on = 0.0;
uniform float pre_u = 0.0;
uniform float pre_inh = 1.0;
uniform float pre_flick = 1.0;
uniform int arc_n = 0;
uniform vec3 arcs[7];
// the ring: on, its clock, how far healed
uniform float ring_on = 0.0;
uniform float ring_heal = 1.0;
// the crack: 0 none, 1 the tear, 2 the scar; its points (film px from the rift) and their u
uniform int crack_mode = 0;
uniform vec2 crack[17];
uniform float crack_u[17];
uniform float crack_a = 0.0;
uniform float crack_keep = 0.5;
// flashes: amplitude and falloff of the frame's flash, the lift, the pinpoint of the shut
uniform float flash_a = 0.0;
uniform float flash_r = 150.0;
uniform float lift = 0.0;
uniform float pin_a = 0.0;
// t - HEAL - 0.28 (the shut), below zero before it
uniform float k_shut = -1.0;

const vec3 HOT = vec3(1.0, 0.93, 1.0);
const vec3 VIO = vec3(0.62, 0.40, 1.0);
const vec3 MAG = vec3(0.95, 0.35, 0.85);
const vec3 CRIM = vec3(0.85, 0.05, 0.14);

// a screen point to the film's world plane round the rift, through the fronts (shock_disp, gw_disp)
vec2 fronts(vec2 w) {
	vec2 v = (w - Tg) / S;
	if (k_hit > 0.0 && k_hit <= 0.9) {
		float r = length(v) + 1e-3;
		float front = 40.0 + 900.0 * k_hit;
		float amp = 9.0 * exp(-pow((r - front) / 22.0, 2.0)) * (1.0 - k_hit / 0.9);
		v -= v / r * amp;
	}
	if (k_gw > 0.0 && k_gw <= 2.6) {
		float r = length(v) + 1e-3;
		float front = 620.0 * k_gw;
		float env = exp(-pow((r - front + 60.0) / 130.0, 2.0)) * exp(-k_gw * 1.4);
		float phase = (r - front) / 46.0 * TAU;
		float amp = 7.0 * env * sin(phase);
		v += v / r * amp * (0.55 + 0.45 * cos(2.0 * atan(v.y, v.x)));
	}
	return v;
}

// distance (film px) from v to the crack, and the crack's u at the nearest point
vec2 crack_d(vec2 v) {
	float best = 1e9;
	float bu = 0.0;
	for (int i = 0; i < 16; i++) {
		vec2 a = crack[i];
		vec2 b = crack[i + 1];
		vec2 ab = b - a;
		float s = clamp(dot(v - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		float uu = mix(crack_u[i], crack_u[i + 1], s);
		if (crack_mode == 2 && abs(uu) > crack_keep) {
			continue;
		}
		float d = length(v - a - ab * s);
		if (d < best) {
			best = d;
			bu = uu;
		}
	}
	return vec2(best, bu);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 9; i++) {
		vec2 v = fronts(p + JW_SUB[i]);
		vec2 b = v;
		bool throat = false;
		if (rE >= 0.01) {
			float r2 = dot(v, v) + 1e-4;
			float r = sqrt(r2);
			// the bend fades far out so the frame's edge does not swim (a lens with finite reach)
			float reach = 9.0 * rE + 60.0;
			float taper = exp(-pow(r / reach, 2.0));
			b = v * (1.0 - (rE * rE / r2) * taper);
			if (spin != 0.0) {
				b = jw_rot(b, spin * pow(rE / max(r, rh + 1e-3), 2.0) * taper);
			}
			throat = r < rh;
		}
		if (!throat) {
			acc += jw_lin(jw_world(screen, SCREEN_PIXEL_SIZE, Tg + b * S, world));
		}
	}
	vec3 img = acc / 9.0;

	// ---- light, in screen space at game-pixel resolution
	vec2 dv = (p - Tg) / S;
	float R = length(dv);
	float ang = atan(dv.y, dv.x);
	float outside = R > rh + 0.5 ? 1.0 : 0.0;
	vec3 Lt = vec3(0.0);
	float I = 0.0;
	if (pre_on > 0.5) {
		float u = pre_u;
		// a lip of light round the pin of dark, brightest just outside it
		Lt += exp(-pow((R - rh - 0.8) / (0.8 + 0.8 * u), 2.0)) * (1.0 + 2.6 * u) * pre_inh * pre_flick * outside * HOT;
		Lt += exp(-max(R - rh, 0.0) / (3.0 + 9.0 * u)) * (0.25 + 0.9 * u) * pre_inh * outside * VIO;
		I += exp(-max(R - rh, 0.0) / (14.0 + 30.0 * u)) * 1.6 * u * pre_inh;
		// tidal arcs flicker at the Einstein radius as the bend grows
		for (int i = 0; i < 7; i++) {
			if (i >= arc_n) {
				break;
			}
			float da = jw_wrap(ang - arcs[i].x);
			float arc = exp(-pow((R - arcs[i].z) / 0.8, 2.0)) * exp(-pow(da / arcs[i].y, 2.0));
			Lt += arc * (0.5 + 1.5 * u) * pre_inh * outside * (0.5 * HOT + 0.5 * MAG);
		}
	}
	if (ring_on > 0.5) {
		float k = k_hit;
		float heal = ring_heal;
		float swirl = 0.65 + 0.35 * cos(2.0 * ang - k * 2.4 - 0.6) * cos(3.0 * ang + k * 1.5 + 1.0);
		float boost = 1.0 + 2.5 * exp(-k * 5.0);
		// the photon ring, thin and white-hot at the throat's lip; its violet bloom outside only
		Lt += exp(-pow((R - rh - 1.0) / 1.1, 2.0)) * 2.6 * boost * swirl * heal * HOT;
		Lt += exp(-max(R - rh - 1.0, 0.0) / (4.0 + 0.05 * rE)) * outside * 0.55 * boost * heal * VIO;
		// a faint second ring where the Einstein ring stands; inside the lip the last red light falling in
		Lt += exp(-pow((R - rE) / 2.0, 2.0)) * 0.22 * heal * swirl * MAG;
		Lt += exp(-pow((R - rh + 1.2) / 1.0, 2.0)) * (R <= rh + 0.5 ? 1.0 : 0.0) * 1.1 * heal * CRIM;
		// the gas round the rift is lit (a lit cloud is a brighter cloud)
		I += exp(-max(R - rh, 0.0) / (40.0 + 0.7 * rE)) * (2.2 + 3.0 * exp(-k * 3.0)) * heal * outside;
	}
	if (crack_mode > 0) {
		// a jagged line of light (its glow is the films' blurred line: a gaussian across it)
		vec2 cd = crack_d(dv);
		float line = cd.x * S < 0.55 ? 1.0 : 0.0;
		if (crack_mode == 1) {
			Lt += line * 5.0 * crack_a * HOT + 25.0 * 0.315 * exp(-cd.x * cd.x / 3.2) * crack_a * VIO;
		} else if (cd.x < 1e8) {
			float val = abs(cd.y) > crack_keep - 0.04 ? 3.0 : 1.0;
			Lt += line * val * crack_a * HOT + val * 3.0 * 0.364 * exp(-cd.x * cd.x / 2.4) * crack_a * VIO;
		}
	}
	if (flash_a > 0.0) {
		Lt += exp(-R / flash_r) * flash_a * HOT;
	}
	if (k_hit >= 0.0 && k_hit < 0.9) {
		// the tear's pressure front, a thin ring of light riding the kick in the stars
		float front = 40.0 + 900.0 * k_hit;
		Lt += exp(-pow((R - front) / (4.0 + 10.0 * k_hit), 2.0)) * 0.35 * pow(1.0 - k_hit / 0.9, 2.0) * VIO;
	}
	if (pin_a > 0.0) {
		Lt += exp(-R / 30.0) * pin_a * HOT;
	}
	if (k_shut >= 0.0) {
		float k = k_shut;
		Lt += exp(-pow(R / (1.2 + 4.0 * k), 2.0)) * 7.0 * exp(-k * 5.0) * HOT;
		Lt += exp(-R / (12.0 + 30.0 * k)) * 0.8 * exp(-k * 3.0) * VIO;
		if (k_gw > 0.0 && k_gw < 2.6) {
			// the shudder's fronts: faint light on the crests of the ring-down
			float front = 620.0 * k_gw;
			float env = exp(-pow((R - front + 60.0) / 130.0, 2.0)) * exp(-k_gw * 1.4);
			float crest = pow(clamp(sin((R - front) / 46.0 * TAU), 0.0, 1.0), 8.0);
			Lt += env * crest * (0.55 + 0.45 * cos(2.0 * ang)) * 0.10 * VIO;
		}
	}
	Lt += texture(lightbuf, (p - world.xy + 0.5) / world.zw).rgb / 0.25;

	// compose: the illumination multiplies the scene (stepped), the emitted light adds (stepped)
	float qI = jw_stepped(I * 0.5, 6.0, p);
	img = img * (1.0 + 5.0 * qI) + qI * 0.012 * VIO;
	vec3 o = jw_add_light(img, Lt, p);
	o += lift * (0.6 * HOT + 0.4 * VIO);
	COLOR = vec4(clamp(jw_srgb(o), 0.0, 1.0), 1.0);
}
