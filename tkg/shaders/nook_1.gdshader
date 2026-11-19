shader_type canvas_item;
render_mode unshaded;

// The NOOK, one art pixel at a time, in the page's drawing order (`nook_1.js` frame): the room's light
// (desk_room.gdshaderinc with the scope's glow), the bezel's bevel, dust, the porthole sky, the rack
// bulb, the string bulbs, the LEDs, the rack's meter, the oscilloscope, the glass (its own CRT, a
// phosphor glow, the tube mask, the glow on the lip), the mug's steam, the fade in. Every put goes
// through the page's soft knee.
// Why: docs/why/DeskScene.md#porting-a-room

#define SMALL_Q 8
#define SMALL_N 32
#define SMALL_SETS 1
#define SMALL_TINTS
#define MORE_FIELDS
#define SMALL_PICK
#include "res://shaders/desk_room.gdshaderinc"

uniform sampler2D art_tex : filter_nearest, repeat_disable;
// the glass: its mask, each boot glyph pixel's place (line 1: c, READY: 100 + c; -1 none)
uniform sampler2D glass_tex : filter_nearest, repeat_disable;
uniform sampler2D title_tex : filter_nearest, repeat_disable;
uniform sampler2D screen_tex : filter_nearest, repeat_disable;
uniform sampler2D steam_tex : filter_nearest, repeat_disable;
uniform sampler2D sky_tex : filter_nearest, repeat_disable;
uniform sampler2D dust_tex : filter_nearest, repeat_disable;

uniform float fade = 1.0;
uniform ivec2 port_org = ivec2(0);
// the rack bulb: level, warmth, drift, brown-out
uniform vec4 bulb = vec4(0.0);
uniform vec4 str_v[8];
uniform vec4 str_w[8];
uniform vec4 led_b[3];
uniform vec4 led_col[12];
// the bevel: the strings' mean, the screen's level
uniform vec2 bev = vec2(0.0);
// the meter: on, segments lit
uniform vec2 readout = vec2(0.0);
uniform float scope_g = 0.0;
uniform float scope_vis = 0.0;
// per column: row, span (low, high), level (0 brightest)
uniform vec4 trace[17];
uniform int trace_n = 0;
uniform vec3 steam_cool = vec3(0.0);
// the CRT (DeskNook._crt)
uniform int g_ph = 0;
uniform vec3 g_fill = vec3(5.0, 8.0, 13.0);
uniform float g_k = 0.0;
uniform int g_n = 0;
uniform vec2 g_open = vec2(0.0);
uniform vec4 g_boot = vec4(0.0);
uniform vec3 g_title = vec3(0.0, 0.0, -99.0);
// k0, squash (-1 none), its height, its boost
uniform vec4 g_pic = vec4(1.0, -1.0, 70.0, 1.0);
// hold rows, jitter first and end row, RGB split
uniform vec4 g_gl = vec4(0.0, -1.0, -1.0, 0.0);
// the glitch's frame and number (for the jitter's rows)
uniform vec2 g_gl2 = vec2(0.0);

const ivec2 GP = ivec2(117, 22);
const int GW = 150;
const int GH = 140;
const ivec4 SC = ivec4(16, 96, 17, 14);
const ivec4 SB = ivec4(100, 139, 36, 48);
const vec3 INK = vec3(150.0, 232.0, 180.0);
const vec3 LEVELS[5] = vec3[](vec3(215.0, 255.0, 205.0), vec3(120.0, 232.0, 112.0), vec3(72.0, 176.0, 78.0), vec3(52.0, 124.0, 58.0), vec3(40.0, 96.0, 48.0));

float soft1(float v) {
	return v < 200.0 ? v : 200.0 + 55.0 * (v - 200.0) / (v - 200.0 + 55.0);
}

vec3 soft(vec3 v) {
	return vec3(soft1(v.r), soft1(v.g), soft1(v.b));
}

// the page's hh: murmur's finaliser on 32-bit ints
float hh(int n) {
	uint x = uint(n) ^ 0x9e3779b9u;
	x = (x ^ (x >> 16u)) * 0x85ebca6bu;
	x = (x ^ (x >> 13u)) * 0xc2b2ae35u;
	x ^= x >> 16u;
	return float(x) / 4294967296.0;
}

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

vec3 picture(int x, int y) {
	int sy;
	if (g_pic.y >= 0.0) {
		float d = float(y) - 70.0 + 0.5;
		if (abs(d) > g_pic.z) return vec3(4.0, 6.0, 9.0);
		sy = int(floor(70.0 + d * 70.0 / g_pic.z + 0.5));
	} else {
		int per = GH + 6;
		sy = (((y - int(g_gl.x)) % per) + per) % per;
	}
	int sh = 0;
	int gf = int(g_gl2.x);
	int gn = int(g_gl2.y);
	if (float(y) >= g_gl.y && float(y) < g_gl.z && hh(y * 13 + gf * 7 + gn) >= 0.25)
		sh = (hh(y * 3 + gf * 11 + gn) < 0.6 ? 1 : 2) * (hh(y + gf * 5 + gn * 3) < 0.5 ? -1 : 1);
	vec3 c = vec3(4.0, 7.0, 10.0);
	if (sy < GH) {
		int sx = clamp(x - sh, 0, GW - 1);
		c = pic(sx, sy);
		if (g_gl.w > 0.5) {
			c.r = pic(max(0, sx - 1), sy).r;
			c.b = pic(min(GW - 1, sx + 1), sy).b;
		}
	}
	vec3 v = c * (g_pic.x * g_pic.w) + vec3(2.0, 4.0, 6.0);
	if (g_title.x > 0.5) v = card(v, x, y, g_title.y, g_title.z);
	return v;
}

// what the page's drawCRT leaves at glass pixel (x, y)
vec3 scr(int x, int y) {
	if (g_ph == 0) return g_fill;
	if (g_ph == 1) {
		if (y == 70 && (x == 75 || x == 74)) return vec3(230.0, 255.0, 250.0) * g_k;
		if (y == 69 && (x == 75 || x == 74)) return vec3(90.0, 120.0, 120.0) * g_k;
		if ((y == 70 && (x == 76 || x == 73)) || (y == 71 && (x == 75 || x == 74))) return vec3(70.0, 95.0, 95.0) * g_k;
		return g_fill;
	}
	if (g_ph == 2) {
		if (x >= 75 - g_n && x < 75 + g_n) {
			if (y == 70) return vec3(215.0, 245.0, 245.0);
			if (y == 69 || y == 71) return vec3(60.0, 85.0, 90.0);
		}
		return g_fill;
	}
	if (g_ph == 3) {
		int dy = abs(y - 70);
		if (dy > g_n) return vec3(7.0, 10.0, 14.0);
		float n = hh((x * 7 + y * 131) ^ (int(g_open.y) * 977));
		float v = 18.0 + (68.0 * g_open.x + 22.0 * n * g_open.x) * (dy >= g_n - 1 ? 1.3 : 1.0);
		return vec3(v * 0.82 + 6.0, v * 0.95 + 10.0, v + 14.0);
	}
	if (g_ph == 4) {
		vec3 c = vec3(8.0, 14.0, 18.0);
		float i = texelFetch(glass_tex, ivec2(x, y), 0).g;
		if (i >= 0.0 && i < 100.0 && i < g_boot.x) c = INK;
		else if (i >= 100.0 && g_boot.y > 0.5) c = INK * 0.9;
		float cx = mod(g_boot.z, 1000.0);
		if (g_boot.z >= 1000.0 && float(x) >= cx && float(x) < cx + 3.0 && float(y) >= g_boot.w && float(y) < g_boot.w + 5.0) c = INK * 0.85;
		return c;
	}
	if (g_ph == 5) return card(vec3(0.0), x, y, g_title.y, -99.0);
	return picture(x, y);
}

// the phosphor's glow: each neighbour's light past 80 bleeds in
vec3 glow_b(int x, int y) {
	vec3 c = scr(x, y);
	vec3 g = vec3(0.0);
	if (x > 0) g += max(vec3(0.0), scr(x - 1, y) - 80.0);
	if (x < GW - 1) g += max(vec3(0.0), scr(x + 1, y) - 80.0);
	if (y > 0) g += max(vec3(0.0), scr(x, y - 1) - 80.0);
	if (y < GH - 1) g += max(vec3(0.0), scr(x, y + 1) - 80.0);
	return c + 0.09 * g;
}

vec3 scope_px(ivec2 p) {
	float g = scope_g;
	vec3 c = vec3(12.0, 19.0, 19.0);
	if (g > 0.0) {
		c = c * (1.0 - g) + vec3(9.0, 34.0, 24.0) * g;
		int rx = p.x - SC.x;
		int ry = p.y - SC.y;
		if (rx % 4 == 0 && ry % 4 == 3) c += vec3(10.0, 26.0, 15.0) * g;
		else if (p.y == 103 && rx % 2 == 0) c += vec3(5.0, 14.0, 8.0) * g;
	}
	if (p.y == SC.y) c *= 0.7;
	vec3 o = st8(soft(c));
	int cx = p.x - SC.x;
	if (scope_vis > 0.0 && cx < trace_n) {
		vec4 tr = trace[cx];
		if (float(p.y) >= tr.y && float(p.y) <= tr.z) {
			float f = (float(p.y) == tr.x ? 1.0 : 0.8) * scope_vis;
			vec3 bg = vec3(9.0, 34.0, 24.0);
			o = st8(soft(bg + (LEVELS[int(tr.w)] - bg) * f));
		}
	}
	return o;
}

// the bezel's inner lip as a bevel: the top dark, the lower edge catching the string lights
vec3 bevel(vec3 o, ivec2 p) {
	int x0 = GP.x - 1;
	int x1 = GP.x + GW;
	bool cols = p.x >= x0 && p.x <= x1;
	bool rows = p.y >= GP.y && p.y < GP.y + GH;
	float f = 1.0;
	vec3 a = vec3(0.0);
	if (cols && p.y == GP.y - 1) f = 0.5;
	else if (cols && p.y == GP.y - 2) f = 0.78;
	else if (rows && p.x == GP.x + GW) f = 0.58;
	else if (rows && p.x == GP.x + GW + 1) f = 0.84;
	else if (cols && p.y == GP.y + GH) { f = 1.3; a = vec3(22.0 * bev.x + 5.0 * bev.y, 16.0 * bev.x + 8.0 * bev.y, 8.0 * bev.x + 10.0 * bev.y); }
	else if (cols && p.y == GP.y + GH + 1) f = 1.1;
	else if (rows && p.x == GP.x - 1) { f = 1.15; a = vec3(6.0, 4.0, 2.0) * bev.x; }
	else return o;
	return st8(soft(o * f + a));
}

// the phosphor spilling onto the inner lip (bottom and left)
vec3 lip(vec3 o, ivec2 p) {
	if (p.y == GP.y + GH && p.x >= GP.x - 1 && p.x <= GP.x + GW)
		return st8(soft(o + 0.07 * glow_b(clamp(p.x - GP.x, 0, GW - 1), GH - 2)));
	if (p.x == GP.x - 1 && p.y >= GP.y && p.y < GP.y + GH)
		return st8(soft(o + 0.07 * glow_b(1, clamp(p.y - GP.y, 0, GH - 1))));
	return o;
}

vec3 lit_only(ivec2 p) {
	vec3 b;
	vec3 l;
	room_lit(p, b, l);
	return l;
}

vec3 desk_px(ivec2 p) {
	int role = int(texelFetch(role_tex, p, 0).r + 0.5);
	vec3 A = texelFetch(art_tex, p, 0).rgb;
	vec3 o;
	vec3 M = vec3(0.0);
	if (role == 8) {
		ivec2 q = p - GP;
		float m = texelFetch(glass_tex, q, 0).r;
		vec3 c = glow_b(q.x, q.y) * m;
		// a dark tube's whole numbers times .95 land on halves, which the page's double breaks down
		// (.95 is a hair under) and float32 breaks up (as on DESK 1)
		vec3 t = c - floor(c);
		vec3 tie = vec3(lessThan(abs(t - 0.5), vec3(0.0005)));
		if (abs(m - 0.95) < 0.001) c = mix(c, floor(c) + 0.25, tie);
		o = st8(soft(c));
	} else if (role == 9) {
		o = scope_px(p);
	} else if (role == 7) {
		o = floor(texelFetch(sky_tex, p - port_org, 0).rgb * 255.0 + 0.5);
	} else if (role == 1) {
		bool lp = p.y == 112;
		int dc = abs(p.x - 358);
		float k = bulb.x * (lp ? (dc < 7 ? 0.92 : 0.8) : (dc < 3 ? 1.3 : (dc < 6 ? 1.1 : 0.95)));
		bool fil = !lp && dc < 3;
		float bw = bulb.y;
		vec3 h = vec3(255.0 * k * 1.15, (140.0 + 85.0 * bw + 15.0 * (bw - bulb.z) - 40.0 * bulb.w) * k * (fil ? 1.12 : 1.0),
			(50.0 + 110.0 * bw + 30.0 * (bw - bulb.z) - 50.0 * bulb.w) * k * (fil ? 1.05 : 0.92));
		o = st8(soft(max(A * vec3(0.1, 0.1, 0.12), h)));
	} else if (role >= 16 && role < 100) {
		int k = role - 16;
		float b = str_v[k / 4][k % 4];
		float w = str_w[k / 4][k % 4];
		bool rim = A.b < 170.0;
		vec3 c = vec3(255.0 * b * (rim ? 1.0 : 1.15), (150.0 + 75.0 * w) * b * (rim ? 0.85 : 1.08), (60.0 + 110.0 * w) * b * (rim ? 0.6 : 1.0));
		o = st8(soft(max(A * vec3(0.15, 0.15, 0.17), c)));
	} else if (role >= 100 && role < 112) {
		int k = role - 100;
		float b = led_b[k / 4][k % 4];
		o = st8(soft(A * (b > 0.0 ? led_col[k].rgb * max(0.14, b) : vec3(0.14, 0.15, 0.18))));
	} else if (role == 120) {
		int i = p.x - 305;
		bool seg = i % 3 != 2;
		o = (readout.x > 0.5 && seg && float(i) < readout.y) ? st8(soft(vec3(110.0, 215.0, 150.0))) : (seg ? vec3(16.0, 30.0, 26.0) : vec3(12.0, 16.0, 20.0));
	} else {
		vec3 base;
		room_lit(p, base, M);
		o = st8(base);
		o = bevel(o, p);
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
		o = lip(o, p);
		ivec2 sp = p - SB.xy;
		if (sp.x >= 0 && sp.y >= 0 && sp.x < SB.z && sp.y < SB.w) {
			float al0 = texelFetch(steam_tex, sp, 0).r;
			if (al0 > 0.02) {
				float gdx = float(max(max(GP.x - p.x, 0), p.x - (GP.x + GW - 1)));
				float gdy = float(max(max(GP.y - p.y, 0), p.y - (GP.y + GH - 1)));
				al0 *= min(1.0, length(vec2(gdx, gdy)) / 4.0);
				float al = min(0.56, floor(al0 / 0.14 + bay(p.x, p.y)) * 0.14);
				if (al > 0.0) {
					vec3 t = p.x >= 119 ? steam_cool : steam_cool * 0.6;
					vec3 s = vec3(150.0, 156.0, 162.0) * min(M * 1.4 + 0.4, vec3(1.3)) + t;
					o = st8(max(o, o + (s - o) * al));
				}
			}
		}
	}
	if (fade < 1.0) o = st8(o * fade);
	return o;
}

uniform int dbg = 0;

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(384.0, 216.0)));
	if (dbg == 1) { COLOR = vec4(texelFetch(fields_tex, p, 0).rgb * 0.5, 1.0); }
	else if (dbg == 3) { COLOR = vec4(vec3(texelFetch(role_tex, p, 0).r / 130.0), 1.0); }
	else COLOR = vec4(desk_px(p) / 255.0, 1.0);
}
