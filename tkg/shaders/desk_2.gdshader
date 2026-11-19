shader_type canvas_item;
render_mode unshaded;

// DESK 2, one art pixel at a time, in the page's drawing order (`desk_2.js` frame): the room's light
// (desk_room.gdshaderinc, 33 bulbs each with its own tint), dust, the lamp, the string bulbs, the
// LEDs and their box glows, the porthole sky, the glass (its own CRT: a 3x3 bloom of a bright-pass,
// the recess, the lamp's smudge), the mug's steam. `desk_tube.gdshader` scales it up.
// Why: docs/why/DeskScene.md#porting-a-room

#define SMALL_Q 16
#define SMALL_N 64
#define SMALL_SETS 2
#define SMALL_TINTS
#include "res://shaders/desk_room.gdshaderinc"

// the art as the emitters read it (RGB 0..255, before the settled dust)
uniform sampler2D art_tex : filter_nearest, repeat_disable;
// the glass: the recess, each boot glyph pixel's place in the typing order (-1 none)
uniform sampler2D glass_tex : filter_nearest, repeat_disable;
// the title card (RGB 0..255; alpha 1 on the blinking prompt)
uniform sampler2D title_tex : filter_nearest, repeat_disable;
uniform sampler2D screen_tex : filter_nearest, repeat_disable;
uniform sampler2D steam_tex : filter_nearest, repeat_disable;
uniform sampler2D sky_tex : filter_nearest, repeat_disable;
uniform sampler2D dust_tex : filter_nearest, repeat_disable;

uniform float fade = 0.0;
// p, warm, flicker
uniform vec4 lamp = vec4(0.0);
uniform vec4 str_v[16];
uniform vec4 str_cream[16];
uniform float mon_on = 0.0;
uniform float iron_on = 0.0;
// the lamp's light on the glass, and its colour
uniform vec4 sheen = vec4(0.0);
uniform vec3 steam_warm = vec3(0.0);
uniform vec3 steam_cool = vec3(0.0);
// the glass: DeskTwo.St, k, the warm-up's whole number (half width or height), the dot's level,
// the squeeze's boost, the picture's brightness, the tube's life
uniform int g_st = 0;
uniform float g_k = 0.0;
uniform int g_n = 0;
uniform float g_dk = 1.0;
uniform float g_boost = 1.0;
uniform float g_bright = 1.0;
uniform float g_live = 1.0;
// card on, seconds since it came up, the wipe's row
uniform vec3 g_title = vec3(0.0, 0.0, -99.0);
// chars typed, cursor on, cursor x, y
uniform vec4 g_boot = vec4(0.0);
// jitter rows (first, last) and shift
uniform vec3 g_jit = vec3(-1.0, -1.0, 0.0);
uniform bool g_rgb = false;
uniform int g_vhold = 0;

const ivec2 GP = ivec2(117, 22);
const int GW = 150;
const int GH = 140;
const ivec4 SB = ivec4(252, 144, 36, 48);
const ivec2 PORT = ivec2(312, 24);
const vec3 BLANK = vec3(14.0, 24.0, 30.0);
const ivec2 BULB = ivec2(332, 133);

vec3 pic(int x, int y) {
	return floor(texelFetch(screen_tex, ivec2(x, y), 0).rgb * 255.0 + 0.5);
}

// the shell's titleCard over c at (x, y): wy is the wipe's row (-99 none)
vec3 card(vec3 c, int x, int y, float tt, float wy) {
	float fy = float(y);
	if (fy < wy) return c;
	if (fy == wy || fy == wy + 1.0) return vec3(200.0, 245.0, 225.0);
	float sh = 1.0 + 0.06 * max(0.0, 1.0 - abs(mod(tt * 22.0, float(GH + 30)) - 15.0 - fy) / 4.0);
	vec4 t = texelFetch(title_tex, ivec2(x, y), 0);
	vec3 v = t.rgb * sh;
	float on = tt < 0.25 ? 1.0 : (int(floor((tt - 0.25) * 1.6)) % 2 == 0 ? 1.0 : 0.18);
	if (on < 1.0 && t.a > 0.5 && fy >= wy + 2.0) {
		vec3 b0 = vec3(7.0, 13.0, 11.0);
		v = b0 + (v - b0) * on;
	}
	return v;
}

// what the page's fillScreen puts at glass pixel (x, y)
vec3 scr(int x, int y) {
	if (g_st == 1) {
		if (x >= 74 && x <= 75 && y >= 69 && y <= 70) return vec3(230.0, 250.0, 255.0) * g_dk;
	} else if (g_st == 2) {
		if (x >= 75 - g_n && x < 75 + g_n) {
			if (y == 69) return vec3(210.0, 240.0, 250.0);
			if (y == 70) return vec3(120.0, 170.0, 190.0);
		}
	} else if (g_st == 3) {
		int hh = g_n;
		if (y >= 70 - hh && y < 70 + hh) {
			int sy = min(GH - 1, int(floor(float(y - (70 - hh)) / float(2 * hh) * float(GH))));
			return min(vec3(255.0), pic(x, sy) * g_boost + vec3(40.0, 55.0, 60.0) * (1.0 - g_k));
		}
	} else if (g_st == 4) {
		int hh = g_n;
		if (y >= 70 - hh && y < 70 + hh) {
			float gl = 1.0 - g_k;
			float e = abs(float(y) - 69.5) < 2.0 ? gl : 0.0;
			return BLANK * (1.0 + 1.5 * gl) + vec3(190.0, 220.0, 230.0) * e;
		}
	} else if (g_st == 5) {
		return card(vec3(0.0), x, y, g_title.y, -99.0);
	} else if (g_st == 6) {
		if (g_boot.y > 0.5 && float(x) >= g_boot.z && float(x) < g_boot.z + 3.0 && float(y) >= g_boot.w && float(y) < g_boot.w + 5.0)
			return vec3(150.0, 222.0, 186.0) * 0.85;
		float i = texelFetch(glass_tex, ivec2(x, y), 0).g;
		if (i >= 0.0 && i < g_boot.x) return vec3(150.0, 222.0, 186.0);
		return BLANK;
	} else if (g_st == 7) {
		vec3 v = pic(x, y) * g_bright;
		if (g_title.x > 0.5) v = card(v, x, y, g_title.y, g_title.z);
		return v;
	}
	return vec3(0.0);
}

// the phosphor's bloom: a 3x3 box of the bright-pass, at 0.07
vec3 bloom(int x, int y) {
	vec3 s = vec3(0.0);
	for (int dy = -1; dy <= 1; dy++) {
		int yy = y + dy;
		if (yy < 0 || yy >= GH) continue;
		for (int dx = -1; dx <= 1; dx++) {
			int xx = x + dx;
			if (xx < 0 || xx >= GW) continue;
			vec3 c = scr(xx, yy);
			float l = 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
			if (l > 95.0) s += c * ((l - 95.0) / 160.0);
		}
	}
	return s * 0.07;
}

// the glass with the tube on (`drawScreen`): jitter, hold, vignette, recess, the bloom, the RGB split
vec3 glass_on(ivec2 q) {
	int x = q.x;
	int y = q.y;
	int shift = (float(y) >= g_jit.x && float(y) <= g_jit.y) ? int(g_jit.z) : 0;
	int sy = clamp(y - g_vhold, 0, GH - 1);
	int sx = clamp(x - shift, 0, GW - 1);
	float ex = (float(x) - 75.0) / 75.0;
	float ey = (float(y) - 70.0) / 70.0;
	float vig = 1.0 - 0.2 * (ex * ex * ey * ey * 2.2 + 0.25 * (ex * ex + ey * ey));
	float k = vig * g_live * texelFetch(glass_tex, q, 0).r;
	vec3 c = scr(sx, sy) + bloom(sx, sy);
	if (g_rgb) {
		int sl = clamp(sx - 1, 0, GW - 1);
		int sr = clamp(sx + 1, 0, GW - 1);
		c.r = scr(sl, sy).r + bloom(sl, sy).r;
		c.b = scr(sr, sy).b + bloom(sr, sy).b;
	}
	return st8(min(vec3(255.0), vec3(5.0 + c.r * k, 8.0 + c.g * k * 1.01, 13.0 + c.b * k * 1.03)) * fade);
}

vec3 glass_px(ivec2 q) {
	int x = q.x;
	int y = q.y;
	vec3 o = g_st == 0 ? st8(vec3(5.0, 8.0, 13.0) * fade) : glass_on(q);
	if (sheen.x > 0.0 && x >= GW - 16 && x <= GW - 15 && y >= 9 && y <= 10) {
		float a = 0.05 * min(1.0, sheen.x);
		o = st8(min(vec3(255.0), o + vec3(a * 255.0 * sheen.y, a * 235.0 * sheen.z, a * 215.0 * max(sheen.w, 0.5)) * fade));
	}
	return o;
}

// a small LED's box glow (`addGlow`), two stepped rings on whole art pixels
vec3 led_glow(vec3 o, ivec2 p, ivec2 c, vec3 col, float w) {
	int dx = p.x - c.x;
	int dy = p.y - c.y;
	if (dx < -2 || dx > 3 || dy < -2 || dy > 2) return o;
	float d = max(abs(float(dx) - 0.5) - 0.5, abs(float(dy)));
	float s = d <= 1.0 ? 0.5 : (bay(p.x, p.y) < 0.5 ? 0.2 : 0.0);
	if (s == 0.0) return o;
	vec3 A = texelFetch(art_tex, p, 0).rgb;
	return st8(min(vec3(255.0), o + A * s * w * col * 0.9 * fade + 40.0 * s * w * col * fade));
}

vec3 lit_only(ivec2 p) {
	vec3 b;
	vec3 l;
	room_lit(p, b, l);
	return l;
}

vec3 desk_px(ivec2 p) {
	int role = int(texelFetch(role_tex, p, 0).r + 0.5);
	if (role == 8) return glass_px(p - GP);
	if (role == 7) return floor(texelFetch(sky_tex, p - PORT, 0).rgb * 255.0 + 0.5);
	vec3 base;
	vec3 M;
	room_lit(p, base, M);
	vec3 o = st8(base);
	// dust, lit by the light where each mote is
	vec2 du = texelFetch(dust_tex, p, 0).rg;
	if (du.r > 0.0) {
		float lv = (M.r + M.g + M.b) / 3.0;
		float b = du.r * (0.03 + lv * lv) * 72.0;
		if (b >= 1.0) o = st8(o + b * M / (lv == 0.0 ? 1.0 : lv));
	}
	if (du.g > 0.0) {
		vec3 M1 = lit_only(p + ivec2(-1, 0));
		float lv = (M1.r + M1.g + M1.b) / 3.0;
		float b = du.g * (0.03 + lv * lv) * 72.0;
		if (b >= 1.0) o = st8(o + 0.45 * b * M1 / (lv == 0.0 ? 1.0 : lv));
	}
	vec3 A = texelFetch(art_tex, p, 0).rgb;
	if (role == 1 || role == 2) {
		float d = length(vec2(p - BULB));
		float fil = clamp(1.0 - d / 7.0, 0.0, 1.0);
		float pw = lamp.x;
		float lit = pw < 0.5 ? pw * (0.4 + 1.2 * fil) : 0.6 + 0.4 * (pw - 0.5) / 0.5;
		float k = min(1.0, lit);
		vec3 off = vec3(A.r * 0.16 + 4.0, A.g * 0.13 + 4.0, A.b * 0.12 + 5.0);
		float fl = 0.55 + 0.45 * lamp.z;
		vec3 on = vec3(min(255.0, A.r * 1.12 * fl), A.g * (0.62 + 0.5 * lamp.y) * fl * fl, A.b * (0.35 + 0.55 * lamp.y) * fl * fl * fl);
		o = st8((off + (on - off) * k) * fade);
		if (role == 2 && pw > 0.5) {
			float h = clamp((pw - 0.55) / 0.4, 0.0, 1.0) * lamp.y * clamp((lamp.z - 0.72) / 0.25, 0.0, 1.0);
			o = st8(min(vec3(255.0), o + (vec3(255.0, 248.0, 222.0) - o) * h));
		}
	} else if (role >= 16) {
		int n = role >= 80 ? role - 80 : role - 16;
		float w = str_v[n / 4][n % 4];
		vec3 off = vec3(A.r * 0.13 + 3.0, A.g * 0.11 + 3.0, A.b * 0.11 + 4.0);
		vec3 on = vec3(min(255.0, A.r * 1.1 + 12.0), min(255.0, A.g * 1.05 + 6.0), A.b * 0.95);
		o = st8((off + (on - off) * w) * fade);
		if (role >= 80 && w > 0.6) {
			float h = min(1.0, (w - 0.6) / 0.5);
			vec3 hc = str_cream[n / 4][n % 4] > 0.5 ? vec3(255.0, 246.0, 222.0) : vec3(255.0, 214.0, 150.0);
			o = st8(o + (hc - o) * h * 0.8);
		}
	} else if (role == 5) {
		o = st8((mon_on > 0.5 ? vec3(120.0, 255.0, 150.0) : vec3(40.0, 52.0, 44.0)) * fade);
	} else if (role == 4) {
		o = st8((iron_on > 0.0 ? vec3(255.0, 70.0, 46.0) : vec3(46.0, 16.0, 12.0)) * fade);
	}
	if (mon_on > 0.5) o = led_glow(o, p, ivec2(142, 169), vec3(0.25, 1.0, 0.45), 0.7);
	if (iron_on > 0.0) o = led_glow(o, p, ivec2(339, 191), vec3(1.0, 0.25, 0.15), 0.9);
	// the mug's steam: only ever lightens; it thins out within 4 px of the glass
	ivec2 sp = p - SB.xy;
	if (sp.x >= 0 && sp.y >= 0 && sp.x < SB.z && sp.y < SB.w) {
		float al0 = texelFetch(steam_tex, sp, 0).r;
		if (al0 > 0.02) {
			float gdx = float(max(max(GP.x - p.x, 0), p.x - (GP.x + GW - 1)));
			float gdy = float(max(max(GP.y - p.y, 0), p.y - (GP.y + GH - 1)));
			al0 *= min(1.0, length(vec2(gdx, gdy)) / 4.0);
			float al = min(0.56, floor(al0 / 0.14 + bay(p.x, p.y)) * 0.14);
			if (al > 0.0) {
				vec3 t = p.x > 271 ? steam_warm : steam_cool;
				vec3 s = (vec3(150.0, 156.0, 162.0) * min(M * 1.4 + 0.4, vec3(1.3)) + t) * fade;
				o = st8(max(o, o + (s - o) * al));
			}
		}
	}
	return o;
}

uniform int dbg = 0;

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(384.0, 216.0)));
	if (dbg == 1) { COLOR = vec4(texelFetch(fields_tex, p, 0).rgb * 0.5, 1.0); }
	else if (dbg == 3) { COLOR = vec4(vec3(texelFetch(role_tex, p, 0).r / 120.0), 1.0); }
	else if (dbg == 4) { COLOR = vec4(texelFetch(a2c_tex, p, 0).rgb / 255.0, 1.0); }
	else if (dbg == 5) { vec3 b; vec3 l; room_lit(p, b, l); COLOR = vec4(b / 255.0, 1.0); }
	else COLOR = vec4(desk_px(p) / 255.0, 1.0);
}
