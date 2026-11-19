shader_type canvas_item;
render_mode unshaded;

// The BUNK, one art pixel at a time, in the page's drawing order (`bunk_1.js` frame): the room's light
// (desk_room.gdshaderinc with the starlight patch, the pillow, the porthole's ring and the strings'
// wash), the glass (its CRT: glitch, vignette, a 1-2-1 phosphor blur), dust, the bezel's lip, the
// porthole sky, the string bulbs, the lamp, the LEDs, the junction box readout, the mug's steam.
// Why: docs/why/DeskScene.md#porting-a-room

#define SMALL_Q 8
#define SMALL_N 32
#define SMALL_SETS 3
#define SMALL_TINTS
#define MORE_FIELDS
#define SMALL_PICK
#include "res://shaders/desk_room.gdshaderinc"

// the art as the emitters read it (RGB 0..255)
uniform sampler2D art_tex : filter_nearest, repeat_disable;
// the glass: the bezel's shade, each boot glyph pixel's place (line 1: c, line 2: 100 + c; -1 none)
uniform sampler2D glass_tex : filter_nearest, repeat_disable;
uniform sampler2D title_tex : filter_nearest, repeat_disable;
uniform sampler2D screen_tex : filter_nearest, repeat_disable;
uniform sampler2D steam_tex : filter_nearest, repeat_disable;
uniform sampler2D sky_tex : filter_nearest, repeat_disable;
uniform sampler2D dust_tex : filter_nearest, repeat_disable;
// the raster's snow while it opens (from DeskBunk, in doubles)
uniform sampler2D noise_tex : filter_nearest, repeat_disable;

uniform float fade = 0.0;
// the porthole's box (DeskBunk.port_box)
uniform ivec2 port_org = ivec2(0);
// the lamp's level (to 1) and warmth
uniform vec4 lamp = vec4(0.0);
uniform vec4 str_v[8];
uniform vec4 led_v[2];
// readout on, and its three rows' lengths
uniform vec4 jb = vec4(0.0);
uniform vec3 steam_warm = vec3(0.0);
uniform vec3 steam_cool = vec3(0.0);
// the CRT: DeskBunk.Ph, the warm-up's level and whole number, the picture's brightness
uniform int g_ph = 0;
uniform float g_k = 0.0;
uniform int g_n = 0;
uniform float g_bright = 1.0;
// card on, its time, the wipe's row (-99 none)
uniform vec3 g_title = vec3(0.0, 0.0, -99.0);
// glitch: kind (1 jitter, 2 split, 3 hold), then (first row, rows, shift) or (rows down)
uniform vec4 g_glitch = vec4(0.0);
uniform float g_wob = 1.0;
uniform bool g_on = false;
uniform float g_flick = 1.0;
// boot: line 1's chars, line 2's (-1 none), cursor x (+1000 when on), cursor y
uniform vec4 g_boot = vec4(0.0);

const ivec2 GP = ivec2(117, 22);
const int GW = 150;
const int GH = 140;
const ivec4 SB = ivec4(259, 137, 36, 48);
const ivec2 JB = ivec2(313, 142);
const vec3 PH = vec3(120.0, 235.0, 200.0);

vec3 pic(int x, int y) {
	return floor(texelFetch(screen_tex, ivec2(x, y), 0).rgb * 255.0 + 0.5);
}

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

// what the page's drawScreen puts at glass pixel (x, y)
vec3 scr(int x, int y) {
	if (g_ph == 1) {
		if (x >= 73 && x <= 76 && y >= 68 && y <= 71) {
			bool core = (x == 74 || x == 75) && (y == 69 || y == 70);
			float v = core ? 255.0 * g_k : 70.0 * g_k;
			return vec3(v * 0.85, v, v);
		}
	} else if (g_ph == 2) {
		if (x >= 75 - g_n && x < 75 + g_n && y >= 68 && y <= 71) {
			float v = (y == 69 || y == 70) ? 245.0 : 60.0;
			return vec3(v * 0.85, v, v);
		}
	} else if (g_ph == 3) {
		if (y >= 70 - g_n && y < 70 + g_n) {
			float n = texelFetch(noise_tex, ivec2(x, y), 0).r;
			float near = abs(float(y) - 69.5) < 2.0 ? 1.0 - g_k : 0.0;
			float v = (25.0 + 70.0 * n * n) * (1.0 - 0.65 * g_k) + 200.0 * near;
			return vec3(v * 0.8, v, v * 0.95);
		}
	} else if (g_ph == 4) {
		float i = texelFetch(glass_tex, ivec2(x, y), 0).g;
		vec3 c = vec3(6.0, 14.0, 13.0);
		if (i >= 0.0 && i < 100.0 && i < g_boot.x) c = PH;
		if (i >= 100.0 && g_boot.y >= 0.0 && i - 100.0 < g_boot.y) c = PH;
		float cx = mod(g_boot.z, 1000.0);
		if (g_boot.z >= 1000.0 && float(x) >= cx && float(x) < cx + 3.0 && float(y) >= g_boot.w && float(y) < g_boot.w + 5.0) c = PH * 0.8;
		return c;
	} else if (g_ph == 5) {
		int h = g_n;
		if (y >= 70 - h && y < 70 + h) {
			if (h <= 2) return vec3(210.0, 245.0, 240.0);
			int sy = clamp(int(floor(float(y - (70 - h)) * float(GH) / float(2 * h))), 0, GH - 1);
			return min(vec3(255.0), pic(x, sy) * (1.0 + 0.9 * (1.0 - g_k)));
		}
	} else if (g_ph == 6) {
		return card(vec3(0.0), x, y, g_title.y, -99.0);
	} else if (g_ph == 7) {
		vec3 v = pic(x, y) * g_bright;
		if (g_title.x > 0.5) v = card(v, x, y, g_title.y, g_title.z);
		return v;
	}
	return vec3(0.0);
}

// the picture through this frame's glitch, then the tube's vignette (the page's crtFilter, before the blur)
vec3 vig_px(int x, int y) {
	int sx = x;
	int sy = y;
	int kind = int(g_glitch.x);
	vec3 c;
	if (kind == 1 && y >= int(g_glitch.y) && y < int(g_glitch.y) + int(g_glitch.z)) {
		int sh = int(g_glitch.w);
		int s2 = (y - int(g_glitch.y)) % 2 == 1 ? sh : sign(sh);
		c = scr(clamp(x - s2, 0, GW - 1), y);
	} else if (kind == 2) {
		c = scr(x, y);
		if (x > 0) c.r = scr(x - 1, y).r;
		if (x < GW - 1) c.b = scr(x + 1, y).b;
	} else if (kind == 3) {
		c = y - int(g_glitch.y) >= 0 ? scr(x, y - int(g_glitch.y)) : vec3(2.0, 3.0, 4.0);
	} else {
		c = scr(x, y);
	}
	float ny = (float(y) - float(GH - 1) / 2.0) / (float(GH) / 2.0);
	float nx = (float(x) - float(GW - 1) / 2.0) / (float(GW) / 2.0);
	float r2 = (nx * nx + ny * ny) * 0.5;
	return c * (g_wob * (1.0 - 0.24 * r2 * r2));
}

// the phosphor's glow at (x, y): 1-2-1 across, then 1-2-1 down, edges held (0 when the tube is off)
vec3 glow(int x, int y) {
	if (!g_on) return vec3(0.0);
	int xl = x > 0 ? x - 1 : x;
	int xr = x < GW - 1 ? x + 1 : x;
	int yu = y > 0 ? y - 1 : y;
	int yd = y < GH - 1 ? y + 1 : y;
	vec3 u = (vig_px(xl, yu) + 2.0 * vig_px(x, yu) + vig_px(xr, yu)) * 0.25;
	vec3 m = (vig_px(xl, y) + 2.0 * vig_px(x, y) + vig_px(xr, y)) * 0.25;
	vec3 d = (vig_px(xl, yd) + 2.0 * vig_px(x, yd) + vig_px(xr, yd)) * 0.25;
	return (u + 2.0 * m + d) * 0.25;
}

vec3 glass_px(ivec2 q) {
	vec3 s = vig_px(q.x, q.y);
	if (g_on) s += max(vec3(0.0), glow(q.x, q.y) - 45.0) * 0.3;
	float sh = texelFetch(glass_tex, q, 0).r * g_flick;
	return st8(vec3(3.0 + s.r, 5.0 + s.g, 8.0 + s.b) * sh);
}

// the bezel's inner lip: lit faces take the room's light, shadowed ones darken; the glow bleeds on it
vec3 lip(vec3 o, ivec2 p, vec3 Lc) {
	if (p.x < GP.x - 2 || p.x >= GP.x + GW + 2 || p.y < GP.y - 2 || p.y >= GP.y + GH + 2) return o;
	ivec2 g = clamp(p, GP, GP + ivec2(GW - 1, GH - 1));
	int d = max(abs(p.x - g.x), abs(p.y - g.y));
	if (d == 0) return o;
	float face = 0.0;
	bool rows = p.y >= GP.y && p.y < GP.y + GH;
	bool cols = p.x >= GP.x && p.x < GP.x + GW;
	if (p.x >= GP.x + GW && rows) face = d == 1 ? 0.6 : 0.3;
	else if (p.y >= GP.y + GH && cols) face = d == 1 ? 0.8 : 0.4;
	else if (p.y < GP.y) face = -0.45;
	else if (p.x < GP.x) face = -0.3;
	if (face > 0.0) {
		vec3 l = min(vec3(1.0), Lc);
		o = st8(o + face * vec3(10.0 + 60.0 * l.r, 10.0 + 56.0 * l.g, 12.0 + 52.0 * l.b));
	} else {
		o = st8(o * (1.0 + face));
	}
	if (g_on) o = st8(o + glow(g.x - GP.x, g.y - GP.y) * (d == 1 ? 0.22 : 0.09) * g_flick);
	return o;
}

vec3 lit_only(ivec2 p) {
	vec3 b;
	vec3 l;
	room_lit(p, b, l);
	return l;
}

const vec3 LED_COL[5] = vec3[](vec3(255.0, 92.0, 60.0), vec3(110.0, 255.0, 150.0), vec3(110.0, 255.0, 140.0), vec3(255.0, 170.0, 70.0), vec3(255.0, 180.0, 80.0));

vec3 desk_px(ivec2 p) {
	int role = int(texelFetch(role_tex, p, 0).r + 0.5);
	if (role == 8) return glass_px(p - GP);
	vec3 base;
	vec3 M;
	room_lit(p, base, M);
	vec3 o = st8(base);
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
	o = lip(o, p, M);
	vec3 A = texelFetch(art_tex, p, 0).rgb;
	if (role == 7) {
		return floor(texelFetch(sky_tex, p - port_org, 0).rgb * 255.0 + 0.5);
	} else if (role >= 16 && role < 80) {
		bool core = role >= 48;
		int k = core ? role - 48 : role - 16;
		float v = str_v[k / 4][k % 4];
		vec3 off = A * vec3(0.07, 0.06, 0.06);
		vec3 ember = core ? vec3(190.0, 95.0, 40.0) : vec3(150.0, 62.0, 22.0);
		vec3 on = vec3(min(255.0, A.r * 1.1 + 12.0), min(255.0, A.g * 1.1 + 8.0), min(255.0, A.b * 1.08));
		vec3 c = v <= 0.3 ? mix(off, ember, v / 0.3) : mix(ember, on, min(1.0, (v - 0.3) / 0.7));
		o = st8(c * max(v, 1.0));
	} else if (role == 1 || role == 2) {
		float w = lamp.y;
		vec3 hc = role == 2 ? vec3(255.0, mix(150.0, 240.0, w), mix(70.0, 200.0, w)) : vec3(255.0, mix(110.0, 200.0, w), mix(40.0, 130.0, w));
		o = st8(mix(A * 0.12, hc, lamp.x));
	} else if (role >= 100 && role < 105) {
		int k = role - 100;
		float v = led_v[k / 4][k % 4];
		if (v > 0.0) o = st8(mix(o, LED_COL[k], v));
	} else if (role >= 120 && role < 123) {
		if (jb.x > 0.5 && float(p.x - JB.x) < jb[role - 119]) o = vec3(60.0, 190.0, 150.0);
	}
	ivec2 sp = p - SB.xy;
	if (role != 7 && sp.x >= 0 && sp.y >= 0 && sp.x < SB.z && sp.y < SB.w) {
		float al0 = texelFetch(steam_tex, sp, 0).r;
		if (al0 > 0.02) {
			float gdx = float(max(max(GP.x - p.x, 0), p.x - (GP.x + GW - 1)));
			float gdy = float(max(max(GP.y - p.y, 0), p.y - (GP.y + GH - 1)));
			al0 *= min(1.0, length(vec2(gdx, gdy)) / 4.0);
			float al = min(0.56, floor(al0 / 0.14 + bay(p.x, p.y)) * 0.14);
			if (al > 0.0) {
				vec3 t = p.x > 278 ? steam_warm : steam_cool;
				vec3 s = vec3(150.0, 156.0, 162.0) * min(M * 1.4 + 0.4, vec3(1.3)) + t;
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
	else if (dbg == 3) { COLOR = vec4(vec3(texelFetch(role_tex, p, 0).r / 130.0), 1.0); }
	else COLOR = vec4(desk_px(p) / 255.0, 1.0);
}
