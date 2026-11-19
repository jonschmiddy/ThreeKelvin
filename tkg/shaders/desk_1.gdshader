shader_type canvas_item;
render_mode unshaded;

// DESK 1, one art pixel at a time, in the page's drawing order (`desk_1.js` frameC): the room's
// light (desk_room.gdshaderinc), the LED glows, the iron's tip, the bulb, the string lights, the
// LEDs, the porthole sky, the mug's steam, the iron's smoke, dust, the screen's lips, the glass.
// Drawn into a 384 x 216 viewport; `desk_tube.gdshader` scales it up through the tube.
// Why: docs/why/DeskScene.md#the-plan

#include "res://shaders/desk_room.gdshaderinc"

// the glass: shade, the boot text's type time (-1 none) (150 x 140)
uniform sampler2D glass_tex : filter_nearest, repeat_disable;
// the title card (150 x 140, RGB 0..255; alpha 1 on the prompt, which blinks): DeskCard.title
uniform sampler2D title_tex : filter_nearest, repeat_disable;
// the game's picture on the glass (150 x 140)
uniform sampler2D screen_tex : filter_nearest, repeat_disable;
// the mug's steam (SB box, 50 x 66: the strongest wisp's alpha)
uniform sampler2D steam_tex : filter_nearest, repeat_disable;
// the porthole (32 x 32 from PORT_BOX)
uniform sampler2D sky_tex : filter_nearest, repeat_disable;
// dust in the air: R at a mote, G the fleck's second pixel
uniform sampler2D dust_tex : filter_nearest, repeat_disable;
// the raster's noise while it opens (150 x 140, from DeskOne in doubles)
uniform sampler2D noise_tex : filter_nearest, repeat_disable;

uniform float tip_on = 0.0;
uniform float fade = 0.0;
// fil, k, brown, drift
uniform vec4 bulb = vec4(0.0);
uniform float bulb_w = 0.0;
uniform vec4 str_v[4];
uniform float pipe_on = 0.0;
uniform float solder_on = 0.0;
uniform float mon_on = 0.0;
uniform vec3 steam_warm = vec3(0.0);
uniform vec3 steam_cool = vec3(0.0);
uniform vec4 wisp[24];
uniform int wisp_n = 0;
uniform float lwf = 0.0;
// the glass
uniform int g_phase = 0;
uniform float g_u = 0.0;
// pDot, pLine, pSq, the raster's opening
uniform vec4 g_p = vec4(0.0);
uniform vec3 g_off0 = vec3(2.0, 3.0, 5.0);
uniform float g_refl = 0.0;
// roll offset (rows), roll gain
uniform vec2 g_roll = vec2(0.0, 1.0);
uniform float g_frame = 0.0;
// jitter on, its first row, its rows, its shift
uniform vec4 g_jit = vec4(0.0);
uniform bool g_rgb = false;
uniform float g_b = 1.0;
uniform bool g_leaving = false;
// cursor on, its x, its y
uniform vec3 g_cursor = vec3(0.0);
// card on, seconds since it came up, wipe 0..1
uniform vec3 g_title = vec3(0.0);

const ivec2 GP = ivec2(117, 22);
const ivec2 GS = ivec2(150, 140);
const ivec4 SB = ivec4(250, 120, 50, 66);
const ivec2 PORT = ivec2(296, 8);
const int MUG_CX = 273;

float scr_ch(int sy, int sx, int ch) {
	int span = GS.y + 8;
	sy = ((sy % span) + span) % span;
	if (sy >= GS.y || sx < 0 || sx >= GS.x) return 3.0 + float(ch);
	return floor(texelFetch(screen_tex, ivec2(sx, sy), 0)[ch] * 255.0 + 0.5);
}

// What the tube shows at glass pixel q this frame, before the phosphor and the shade (the page's GB).
vec3 glass_gb(ivec2 q) {
	int x = q.x;
	int y = q.y;
	vec3 c = g_off0;
	float b = bay(x, y);
	if (g_phase == 1) {
		float d = length(vec2(float(x) - 75.0, float(y) - 70.0));
		float p = g_p.x;
		float f = g_leaving ? band2(d, vec2(1.4, 0.7), vec2(3.2 * p + 0.8, 0.25), 1.2, b) * (0.35 + 0.65 * p)
			: band2(d, vec2(1.2 * p + 0.3, 0.65), vec2(3.5 * p, 0.25), 1.2, b);
		c += vec3(220.0, 240.0, 250.0) * f;
	} else if (g_phase == 2) {
		float p = g_p.y;
		float hw = 2.0 + 73.0 * p;
		float ddx = max(0.0, abs(float(x) - 75.0 + 0.5) - hw);
		float dy = abs(float(y) - 70.0 + 0.5);
		float f = ddx > 0.0 ? 0.0 : band2(dy, vec2(1.0, 0.75), vec2(3.0, 0.18), 1.0, b);
		c += vec3(225.0, 245.0, 255.0) * f * (1.0 - 0.25 * p);
	} else if (g_phase == 3) {
		float p = g_p.w;
		float hh = 1.0 + 69.0 * p;
		float dy = abs(float(y) - 70.0 + 0.5);
		if (dy < hh) {
			float edge = dy > hh - 1.5 ? 0.5 : 0.0;
			float nz = texelFetch(noise_tex, q, 0).r;
			float lv = 0.55 * (1.0 - p) + 0.1 + nz + edge;
			c = vec3(10.0 + 170.0 * lv, 14.0 + 195.0 * lv, 16.0 + 205.0 * lv);
		}
	} else if (g_phase == 4) {
		c = vec3(8.0, 14.0, 11.0);
	} else if (g_phase == 5) {
		int dx = 0;
		if (g_jit.x > 0.5 && float(y) >= g_jit.y && float(y) < g_jit.y + g_jit.z) {
			int jd = int(g_jit.w);
			dx = (y % 2) == 1 ? jd : jd / 2;
		}
		int sy = y + int(g_roll.x);
		int sx = x - dx;
		if (g_rgb) c = vec3(scr_ch(sy, sx - 1, 0), scr_ch(sy, sx, 1), scr_ch(sy, sx + 1, 2));
		else c = vec3(scr_ch(sy, sx, 0), scr_ch(sy, sx, 1), scr_ch(sy, sx, 2));
		c *= g_roll.y;
	} else if (g_phase == 6) {
		float hh = 70.0 * pow(g_p.z, 1.6);
		float dy = float(y) - 70.0 + 0.5;
		if (abs(dy) < max(hh, 1.0)) {
			int sy = int(floor(70.0 + dy * 70.0 / max(hh, 1.0) + 0.5));
			float w = 1.0 - g_p.z;
			c = vec3(mix(scr_ch(sy, x, 0), 230.0, w * 0.7), mix(scr_ch(sy, x, 1), 245.0, w * 0.7), mix(scr_ch(sy, x, 2), 255.0, w * 0.7)) * (1.0 + w * 0.6);
		}
	}
	vec4 gt = texelFetch(glass_tex, q, 0);
	if (g_phase == 4) {
		if (gt.g >= 0.0 && g_u >= gt.g) c = vec3(140.0, 236.0, 172.0);
		if (g_cursor.x > 0.5 && float(x) >= g_cursor.y && float(x) < g_cursor.y + 3.0 && float(y) >= g_cursor.z && float(y) < g_cursor.z + 5.0)
			c = vec3(120.0, 220.0, 150.0);
	}
	if (g_title.x > 0.5) {
		float tt = g_title.y;
		float wy = g_title.z > 0.0 ? floor(g_title.z * float(GS.y + 4) + 0.5) - 2.0 : -99.0;
		float fy = float(y);
		if (fy >= wy) {
			if (fy == wy || fy == wy + 1.0) {
				c = vec3(200.0, 245.0, 225.0);
			} else {
				float sh = 1.0 + 0.06 * max(0.0, 1.0 - abs(mod(tt * 22.0, float(GS.y + 30)) - 15.0 - fy) / 4.0);
				c = texelFetch(title_tex, q, 0).rgb * sh;
				float on = tt < 0.25 ? 1.0 : (int(floor((tt - 0.25) * 1.6)) % 2 == 0 ? 1.0 : 0.18);
				if (on < 1.0 && texelFetch(title_tex, q, 0).a > 0.5 && fy >= wy + 2.0) {
					vec3 base0 = vec3(7.0, 13.0, 11.0);
					c = base0 + (c - base0) * on;
				}
			}
		}
	}
	return c;
}

// The glass pixel q as it is put: phosphor bleed, the tube's shade and brightness, the lamp's smudge.
vec3 glass_px(ivec2 q) {
	vec3 c = glass_gb(q);
	if (g_phase >= 1) {
		vec3 n = vec3(0.0);
		float k = 0.0;
		if (q.x > 0) { n += glass_gb(q + ivec2(-1, 0)); k += 1.0; }
		if (q.x < GS.x - 1) { n += glass_gb(q + ivec2(1, 0)); k += 1.0; }
		if (q.y > 0) { n += glass_gb(q + ivec2(0, -1)); k += 1.0; }
		if (q.y < GS.y - 1) { n += glass_gb(q + ivec2(0, 1)); k += 1.0; }
		n /= k;
		c += max(vec3(0.0), n - c) * 0.22 + max(vec3(0.0), n - 120.0) * 0.06;
	}
	float sh = texelFetch(glass_tex, q, 0).r;
	c *= sh * g_b;
	// A dark tube's whole numbers times .95 or .9 land on halves, which the page's doubles break
	// (.95 is a hair under, .9 a hair over); float32 breaks them the other way.
	if (g_b == 1.0) {
		vec3 t = c - floor(c);
		vec3 tie = vec3(lessThan(abs(t - 0.5), vec3(0.0005)));
		float dir = abs(sh - 0.95) < 0.001 ? -1.0 : (abs(sh - 0.9) < 0.001 ? 1.0 : 0.0);
		c = mix(c, floor(c) + 0.5 + dir * 0.25, tie * abs(dir));
	}
	if (g_refl > 0.0 && q.x < 24 && q.y > 88 && q.y < 140) {
		float dd = length(vec2((float(q.x) - 9.0) * 1.9, (float(q.y) - 114.0) * 0.75));
		float f = band3(dd, vec2(4.0, 0.35), vec2(9.0, 0.35), vec2(15.0, 0.3), 2.5, bay(q.x, q.y)) * g_refl;
		c += vec3(9.0, 6.0, 2.5) * f;
	}
	return st8(c);
}

vec3 lerp3(vec3 a, vec3 b, float k) {
	return a + (b - a) * k;
}

vec3 desk_px(ivec2 p) {
	int role = int(texelFetch(role_tex, p, 0).r + 0.5);
	if (role == 8) return glass_px(p - GP);
	vec3 base;
	vec3 lm;
	room_lit(p, base, lm);
	vec3 o = st8(base);
	vec3 gm;
	vec3 ga;
	glows_at(p, gm, ga);
	vec3 A = texelFetch(a2c_tex, p, 0).rgb;
	if (any(notEqual(gm, vec3(0.0))) || any(notEqual(ga, vec3(0.0)))) o = st8(o + A * gm + ga);
	vec3 M = lm + gm;
	float lm0 = 0.3 * A.r + 0.59 * A.g + 0.11 * A.b;
	if (role == 6) {
		float k = sat1(tip_on);
		o = st8(vec3(mix(o.r, 255.0, k), mix(o.g, 150.0 + 40.0 * (tip_on - 1.0 + 0.1), k), mix(o.b, 60.0, k)));
	} else if (role == 1 || role == 2) {
		vec3 off = vec3(lm0 * 0.5 * 0.32 * fade + 3.0, lm0 * 0.52 * 0.32 * fade + 4.0, lm0 * 0.56 * 0.32 * fade + 6.0);
		float fil = bulb.x;
		float k = bulb.y;
		if (fil <= 0.0) {
			o = st8(off);
		} else if (role == 2) {
			float ke = sat1(k - bulb.z * 1.6 + bulb.w * 0.06);
			o = st8(lerp3(off, vec3(255.0, mix(120.0, 236.0, ke), mix(40.0, 190.0, ke)), sat1(fil * 1.4)));
		} else {
			float gl = fil * (bulb_w / max(fil, 0.001));
			vec3 on = vec3(A.r * 1.12 + 14.0, A.g * mix(0.6, 1.06, k) + 6.0, A.b * mix(0.3, 0.92, k));
			o = st8(lerp3(off, on, sat1(gl * mix(0.55, 1.0, k))));
		}
	} else if (role >= 16) {
		int sn = role - 16;
		float v = str_v[sn / 4][sn % 4];
		vec3 off = vec3(A.r * 0.16 * fade + 2.0, A.g * 0.15 * fade + 2.0, A.b * 0.17 * fade + 3.0);
		if (v <= 0.0) {
			o = st8(off);
		} else {
			float f = min(v, 1.35);
			float ex = f > 1.0 ? f - 1.0 : 0.0;
			o = st8(lerp3(off, vec3(A.r * 1.06 + 16.0, A.g + 8.0, A.b * 0.85), sat1(f)) + vec3(120.0, 90.0, 50.0) * ex);
		}
	} else if (role == 3) {
		float v = 0.25 + 0.75 * pipe_on;
		o = st8(vec3(min(255.0, A.r * v * 1.15 + 20.0 * pipe_on), A.g * v * 0.95, A.b * v * 0.6));
	} else if (role == 4) {
		o = solder_on > 0.5 ? vec3(255.0, 70.0, 50.0) : st8(vec3(o.r * 0.9 + 20.0, o.g * 0.9, o.b * 0.9));
	} else if (role == 5) {
		o = mon_on > 0.5 ? vec3(120.0, 255.0, 140.0) : st8(o + vec3(8.0, 12.0, 8.0));
	} else if (role == 7) {
		o = floor(texelFetch(sky_tex, p - PORT, 0).rgb * 255.0 + 0.5);
	}
	// the mug's steam: only ever lightens, warm on the lamp's side and teal on the screen's
	ivec2 sp = p - SB.xy;
	if (sp.x >= 0 && sp.y >= 0 && sp.x < SB.z && sp.y < SB.w) {
		float al0 = texelFetch(steam_tex, sp, 0).r;
		if (al0 > 0.02) {
			float al = min(0.56, floor(al0 / 0.14 + bay(p.x, p.y)) * 0.14);
			if (al > 0.0) {
				vec3 t = p.x <= MUG_CX ? steam_warm : steam_cool;
				vec3 s = vec3(150.0, 156.0, 162.0) * min(M * 1.4 + 0.4, vec3(1.3)) + t;
				o = st8(max(o, lerp3(o, s, al)));
			}
		}
	}
	// the iron's smoke, its points in drawing order
	for (int k = 0; k < 24; k++) {
		if (k >= wisp_n) break;
		vec4 w = wisp[k];
		if (int(w.x) == p.x && int(w.y) == p.y) {
			vec3 s = vec3(190.0, 200.0, 210.0) * min(M * 1.6 + 0.12, vec3(1.2));
			o = st8(lerp3(o, s, w.z));
		}
	}
	// dust, lit by the light where each mote is
	vec2 du = texelFetch(dust_tex, p, 0).rg;
	if (du.r > 0.0) {
		float lv = (M.r + M.g + M.b) / 3.0;
		float b = du.r * (0.03 + lv * lv) * 72.0;
		if (b >= 1.0) o = st8(o + b * M / (lv == 0.0 ? 1.0 : lv));
	}
	if (du.g > 0.0) {
		vec3 M1 = light_at(p + ivec2(-1, 0));
		float lv = (M1.r + M1.g + M1.b) / 3.0;
		float b = du.g * (0.03 + lv * lv) * 72.0;
		if (b >= 1.0) o = st8(o + 0.45 * b * M1 / (lv == 0.0 ? 1.0 : lv));
	}
	// the screen's lips: the glass sits behind a hole; the right lip faces the lamp
	if (max(max(A.r, A.g), A.b) - min(min(A.r, A.g), A.b) <= 70.0) {
		float warm = 18.0 * sat1(lwf);
		float m = 1.0;
		float add = 0.0;
		bool hit = false;
		if (p.y >= GP.y - 1 && p.y <= GP.y + GS.y) {
			if (p.x == GP.x + GS.x) { m = 1.3; add = warm; hit = true; }
			else if (p.x == GP.x + GS.x + 1) { m = 1.1; add = warm * 0.4; hit = true; }
			else if (p.x == GP.x - 1) { m = 0.5; hit = true; }
			else if (p.x == GP.x - 2) { m = 0.78; hit = true; }
		}
		if (p.x >= GP.x && p.x < GP.x + GS.x) {
			if (p.y == GP.y - 1) { m = 1.15; add = warm * 0.5; hit = true; }
			else if (p.y == GP.y + GS.y) { m = 0.58; add = 0.0; hit = true; }
			else if (p.y == GP.y + GS.y + 1) { m = 0.84; add = 0.0; hit = true; }
		}
		if (hit) o = st8(vec3(o.r * m + add, o.g * m + add * 0.78, o.b * m + add * 0.5));
	}
	return o;
}

uniform int dbg = 0;

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(384.0, 216.0)));
	if (dbg == 1) { COLOR = vec4(texelFetch(fields_tex, p, 0).rgb * 0.5, 1.0); }
	else if (dbg == 2) { COLOR = vec4(texelFetch(screen_tex, p % ivec2(150, 140), 0).rgb, 1.0); }
	else if (dbg == 3) { COLOR = vec4(vec3(texelFetch(role_tex, p, 0).r / 30.0), 1.0); }
	else if (dbg == 4) { COLOR = vec4(texelFetch(a2c_tex, p, 0).rgb / 255.0, 1.0); }
	else if (dbg == 5) { vec3 b; vec3 l; room_lit(p, b, l); COLOR = vec4(b / 255.0, 1.0); }
	else if (dbg == 6) { COLOR = vec4(texelFetch(px_tex, p, 0).rgb / 2.0, 1.0); }
	else if (dbg == 7) { COLOR = vec4(vec3(w_small[0].w, fl_small[0].w, fl_lamp) / 2.0, 1.0); }
	else COLOR = vec4(desk_px(p) / 255.0, 1.0);
}
