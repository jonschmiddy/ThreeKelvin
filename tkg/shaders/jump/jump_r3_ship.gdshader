shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R3 THE RIFT, the ship pass: the world as it is, with the stand-in hull drawn where the rift's
// source plane has it (rift.py `sample_ship` and the hull's light in `frame`). The warp pass
// then bends both. The fall is a lookup: D0 for a depth D, baked by SeqRift each frame.
// Why: docs/why/SeqRift.md#ship-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_warp.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
// the films' own seams (red) and their halo (green): JumpWarpField.film_seams
uniform sampler2D seams : filter_nearest, repeat_disable;
uniform sampler2D dtab : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 Tg = vec2(600.0, 262.0);
uniform float S = 1.0;
uniform float hull_on = 0.0;
uniform float alive = 1.0;
// the fall's clock, t - HIT (below zero: not falling yet), and the lurch before it
uniform float fall_k = -1.0;
uniform float lurch = 0.0;
uniform float fade = 1.0;
uniform float hull_k = 0.0;
uniform float seam_on = 0.0;
uniform float seam_u = 0.0;
uniform float seam_ph = 0.0;
uniform float seam_mul = 1.0;
uniform float red_k = 0.0;
uniform int tab_n = 512;
uniform float tab_max = 800.0;

const vec3 HOT = vec3(1.0, 0.93, 1.0);
const vec3 VIO = vec3(0.62, 0.40, 1.0);
const vec3 CRIM = vec3(0.85, 0.05, 0.14);

float A(vec2 h) {
	return j_hull_px(hull, h, ship.zw).a > 0.0 ? 1.0 : 0.0;
}

// D0 (film px from the rift, along the line) for a depth D, through the table (sqrt-spaced).
float d0_of(float D) {
	if (D < 0.0) {
		return -1.0;
	}
	if (D >= tab_max) {
		return 900.0;
	}
	float x = sqrt(D / tab_max) * float(tab_n - 1);
	int i = int(floor(x));
	float a = texelFetch(dtab, ivec2(i, 0), 0).r;
	float b = texelFetch(dtab, ivec2(min(i + 1, tab_n - 1), 0), 0).r;
	if (a < 0.0 || b < 0.0) {
		return -1.0;
	}
	return mix(a, b, x - float(i));
}

// The lit hull at canvas pixel h, in linear light; D is its depth (film px), 999 before the fall.
vec3 lit(vec2 h, float D) {
	vec4 px = j_hull_px(hull, h, ship.zw);
	vec3 c = jw_lin(px.rgb);
	vec3 c0 = c;
	vec2 dv = (ship.xy + h - Tg) / S;
	float d = length(dv);
	// the outline facing the rift (+x) catches the rim light, the top and bottom edges a little
	float ro0 = 1.0 - A(h + vec2(1.0, 0.0));
	float ro1 = A(h + vec2(1.0, 0.0)) * (1.0 - A(h + vec2(2.0, 0.0)));
	float ro2 = A(h + vec2(2.0, 0.0)) * (1.0 - A(h + vec2(3.0, 0.0)));
	float ud = max(1.0 - A(h - vec2(0.0, 1.0)), 1.0 - A(h + vec2(0.0, 1.0)));
	float rim = min(ro0 + ro1 * 0.55 + ro2 * 0.25 + ud * 0.35, 1.2);
	float Lr = hull_k * rim * exp(-d / 500.0) * 3.0;
	float Lh = hull_k * exp(-d / 150.0) * 0.8 + Lr;
	c = c * (1.0 + 1.3 * Lh) + Lh * 0.035 * VIO;
	c += floor(clamp(Lr, 0.0, 2.0) * 3.0) / 3.0 * (0.45 * VIO + 0.25 * HOT);
	if (seam_on > 0.5) {
		// the drive's light runs along the plate seams, tail to nose, quicker as the tear nears
		float xs = (50.0 + (h.x - ink_rect.x) * 236.0 / max(ink_rect.z, 1.0)) / 300.0;
		float wave = cos(TAU * (xs * 1.5 - seam_ph));
		float amp = (0.15 + 0.85 * seam_u) * (0.3 + 0.7 * pow(clamp(wave, 0.0, 1.0), 3.0)) * seam_mul;
		vec2 sh = texture(seams, (h + 0.5) / ship.zw).rg;
		float seam = sh.r;
		float e = floor(clamp(seam * amp, 0.0, 1.5) * 4.0) / 4.0;
		float halo = sh.g;
		float hal = floor(clamp(halo * amp, 0.0, 1.2) * 3.0) / 3.0;
		c = c * (1.0 + 1.2 * hal) + hal * 0.05 * VIO;
		c += e * (0.6 * VIO + 0.45 * HOT);
	}
	if (fall_k >= 0.0) {
		// red shift by depth: the deep parts slide to crimson and darken; the image fades at the end
		float red = clamp(exp(-(D - 8.0) / 95.0), 0.0, 1.0) * red_k;
		float lum = (c0.r + c0.g + c0.b) / 3.0;
		vec3 rs = (lum * 0.95 + 0.003) * CRIM * (1.0 + 0.35 * Lh);
		float dim = 0.25 + 0.75 * clamp(D / 40.0, 0.0, 1.0);
		c = (c * (1.0 - red) + rs * red) * (1.0 - red * (1.0 - dim)) * fade;
	}
	return c;
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec3 base = texture(screen, SCREEN_UV).rgb;
	vec3 o = base;
	if (hull_on > 0.5 && alive > 0.5) {
		if (fall_k < 0.0) {
			// still on its mooring: the hull pixel for pixel, drawn back a hair before the snap
			vec2 h = floor(p - vec2(lurch * S, 0.0) - ship.xy + 0.5);
			if (A(h) > 0.0) {
				o = jw_srgb(lit(h, 999.0));
			}
		} else {
			// falling: nine sub-samples through the fall's inverse, so the stretch does not shimmer
			vec3 acc = vec3(0.0);
			float cov = 0.0;
			for (int i = 0; i < 9; i++) {
				vec2 v = (p + JW_SUB[i] - Tg) / S;
				float D = -v.x;
				float D0 = d0_of(D);
				if (D0 < 0.0) {
					continue;
				}
				float gy = 0.30 + 0.70 * (1.0 - exp(-max(D, 0.0) / 45.0));
				vec2 sp = vec2(-D0, v.y / gy);
				vec2 h = floor(Tg + sp * S - ship.xy + 0.5);
				if (A(h) > 0.0) {
					acc += lit(h, D);
					cov += 1.0;
				}
			}
			if (cov > 0.0) {
				o = jw_srgb(mix(jw_lin(base), acc / cov, cov / 9.0));
			}
		}
	}
	COLOR = vec4(o, 1.0);
}
