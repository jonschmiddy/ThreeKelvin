shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R8 MAELSTROM, the warp pass: maelstrom.py `frame`. Nine taps a pixel through the storm's twist
// and inflow (and the swallow's pressure front), the hull read at each tap's own point in the
// disc (jump_r8_hull); the gas's two layers read
// through the same twist (the front one turning 1.18x faster); then the light: the gas as
// light, the eye, its lip and throat, the burning point, the swallow, and the streaks, wake and
// embers from the light buffer.
// Why: docs/why/SeqMaelstrom.md#warp-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_warp.gdshaderinc"
#include "res://shaders/jump/jump_r8.gdshaderinc"
#include "res://shaders/jump/jump_r8_hull.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D lightbuf : filter_nearest, repeat_disable;
uniform sampler2D gas : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform float hull_on = 0.0;
uniform float alive = 0.0;
// the gas layers' scales (the PNG holds each over its max) and the crop's half size
uniform vec2 gas_scale = vec2(1.276146, 1.0);
uniform vec2 gas_half = vec2(768.0, 480.0);
uniform float lv = 0.0;
uniform float reach = 1.0;
// t - HIT: the swallow's front, burst and flash clocks (below zero before it)
uniform float k_hit = -1.0;
uniform float hush = 1.0;
uniform float lip_r = 20.0;
// the burning point's screen place (how hot is the hull's `glow`)
uniform vec2 spot = vec2(0.0);
uniform float flash_a = 0.0;
uniform float flash_r = 150.0;
uniform float lift = 0.0;

const vec3 DUSK = vec3(0.38, 0.30, 0.75);

vec2 gas_at(vec2 q) {
	vec2 i = floor(q + 0.5) + gas_half;
	if (i.x < 0.0 || i.y < 0.0 || i.x >= 2.0 * gas_half.x || i.y >= 2.0 * gas_half.y) {
		return vec2(0.0);
	}
	return texelFetch(gas, ivec2(i), 0).rg * gas_scale;
}

// dusky violet far out, magenta in the arms, sea-green at the inner edge, white-hot at the core
vec3 gas_colour(float R) {
	float a = clamp((R - 30.0) / 90.0, 0.0, 1.0);
	float b = clamp((R - 110.0) / 180.0, 0.0, 1.0);
	float c = clamp((R - 8.0) / 26.0, 0.0, 1.0);
	vec3 inner = mix(HOT, SEA, c);
	return mix(mix(inner, MAG, a), VIO, b);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec3 acc = vec3(0.0);
	float gb = 0.0;
	float gf = 0.0;
	float cov = 0.0;
	for (int i = 0; i < 9; i++) {
		vec2 v = (p + JW_SUB[i] - Tg) / S;
		vec2 d = vec2(v.x, v.y / KY);
		float r = length(d) + 1e-4;
		float f = r8_f(r);
		float m = 1.0 + P * exp(-r / 240.0);
		// the background: turned back by the twist, sampled from further out by the inflow
		vec2 qd = jw_rot(d, -PH * f) * m;
		vec2 q = vec2(qd.x, qd.y * KY);
		if (k_hit >= 0.0 && k_hit < 0.9) {
			float front = 30.0 + 950.0 * k_hit;
			float amp = 10.0 * exp(-pow((r - front) / 24.0, 2.0)) * (1.0 - k_hit / 0.9);
			q -= vec2(d.x, d.y * KY) / r * amp;
		}
		// the ship lives in the world: read at this sight line's own point in the disc, as the film did
		bool on_hull = false;
		if (alive > 0.5 && hull_on > 0.5) {
			vec2 h = floor(r8_ship_h(d) + 0.5);
			if (A(h) > 0.0) {
				acc += lit(h);
				cov += 1.0;
				on_hull = true;
			}
		}
		if (!on_hull) {
			acc += jw_lin(jw_world(screen, SCREEN_PIXEL_SIZE, Tg + q * S, world));
		}
		if (lv > 0.0) {
			gb += gas_at(q).r;
			// the front wisps turn a little faster (they are nearer)
			vec2 q2 = jw_rot(d, -PH * 1.18 * f) * m;
			gf += gas_at(vec2(q2.x, q2.y * KY)).g;
		}
	}
	vec3 img = acc / 9.0;
	gb /= 9.0;
	gf /= 9.0;
	cov /= 9.0;

	// ---- light, in screen space at game-pixel resolution
	vec2 dv = (p - Tg) / S;
	float R0 = length(dv);
	float R = length(vec2(dv.x, dv.y / KY));
	float ang = atan(dv.y / KY, dv.x);
	vec3 Lt = vec3(0.0);
	float I = 0.0;
	float throat = 0.0;
	if (lv > 0.0) {
		float env = exp(-pow(R / reach, 2.2));
		float core = 1.0 / (1.0 + (R / 95.0) * (R / 95.0));
		// the drain: deep in the funnel the gas thins into a dark throat round the core
		float drain = 1.0 - 0.92 * exp(-pow(R / 34.0, 4.0));
		float burst = 0.0;
		if (k_hit >= 0.0 && k_hit < 1.4) {
			float front = 20.0 + 620.0 * k_hit;
			burst = 3.2 * exp(-pow((R - front) / (30.0 + 50.0 * k_hit), 2.0)) * exp(-k_hit * 1.6);
		}
		float g = pow(gb, 1.6) * 1.5 * env * (0.22 + 2.6 * core) * drain * lv * (1.0 + burst);
		vec3 gcol = gas_colour(R);
		Lt += g * (1.0 - cov) * 1.25 * gcol;
		I += g * 2.2;
		float g2 = pow(gf, 1.3) * env * (0.4 + 1.4 * core) * lv * (1.0 + burst);
		Lt += g2 * 0.9 * (0.55 * gcol + 0.45 * DUSK);
		// the eye: a white-hot pinpoint at the bottom of the drain and a turning lip of light round it
		float lip = exp(-pow((R - lip_r) / 1.6, 2.0)) * (0.55 + 0.45 * cos(4.0 * ang - PH))
			* (0.5 + 0.5 * cos(7.0 * ang - PH * 1.6 + 1.0));
		Lt += lip * 2.4 * lv * hush * (0.45 * HOT + 0.55 * SEA);
		Lt += exp(-pow(R0 / (1.2 + 0.8 * lv), 2.0)) * 5.0 * lv * (0.6 + 0.4 * hush) * HOT;
		float outl = R > lip_r ? 1.0 : 0.0;
		Lt += exp(-max(R - lip_r, 0.0) / 16.0) * outl * 0.5 * lv * hush * VIO;
		I += exp(-max(R - lip_r, 0.0) / 180.0) * outl * 1.4 * lv * hush;
		// the throat: down the drain the scene itself goes dark
		throat = exp(-pow(R / (lip_r - 1.0), 3.5)) * lv;
	}
	if (glow > 0.0 && alive > 0.5) {
		// the ship as a burning point as it goes down
		float Rs = length(p - spot) / S;
		Lt += exp(-pow(Rs / (1.5 + 3.0 * glow), 2.0)) * 4.0 * glow * HOT;
		Lt += exp(-Rs / 10.0) * 0.8 * glow * MAG;
	}
	if (flash_a > 0.0) {
		Lt += exp(-R0 / flash_r) * flash_a * HOT;
	}
	if (k_hit >= 0.0) {
		if (k_hit < 0.9) {
			float front = 30.0 + 950.0 * k_hit;
			Lt += exp(-pow((R - front) / (4.0 + 10.0 * k_hit), 2.0)) * 0.45 * pow(1.0 - k_hit / 0.9, 2.0) * (0.5 * VIO + 0.5 * SEA);
		}
		Lt += exp(-pow(R0 / (1.5 + 5.0 * k_hit), 2.0)) * 6.0 * exp(-k_hit * 4.0) * HOT;
	}
	Lt += texture(lightbuf, (p - world.xy + 0.5) / world.zw).rgb / 0.25;

	float qI = jw_stepped(I * 0.5, 6.0, p);
	img = img * (1.0 + 4.0 * qI) + qI * 0.010 * VIO;
	img *= 1.0 - 0.93 * throat;
	vec3 o = jw_add_light(img, Lt, p);
	o += lift * (0.6 * HOT + 0.4 * VIO);
	COLOR = vec4(clamp(jw_srgb(o), 0.0, 1.0), 1.0);
}
