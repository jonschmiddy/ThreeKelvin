shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled, depth_draw_opaque;

// THE BANNERS LIT (`YardCloth`, docs/why/YardBanner.md#pixels): the page's drawCloth on the game's 1x grid,
// depth-tested, the cloth's texture nearest; mode 0 its light (the room's lamps summed and stepped in 0.1
// steps, a narrow dither band at each step, whole steps on a painted mark, the glint of a mark or an accent thread), mode 1 the
// row's field colour (the rims' colour, `yard_cloth_show`). Written raw: this viewport does no colour space.


uniform sampler2D state : filter_nearest;
#define STATE state
#include "res://shaders/yard_cloth.gdshaderinc"
uniform sampler2D atlas : filter_nearest;
uniform sampler2D field : filter_nearest;
uniform int mode = 0;
uniform float bx[7];
uniform int nl = 0;
// each light: (x, y, z or a direction, 1 a point), (colour, power), (wrap, translucency, 1 / reach^2, glints),
// (strength down the cloth: a + b v / 100, this frame's flicker, -)
uniform vec4 lp[16];
uniform vec4 lc[16];
uniform vec4 lk[16];
uniform vec4 lv[16];
uniform vec3 amb = vec3(0.3);
uniform float expo = 1.0;

const float QSTEP = 0.1;
// tapestry (`YardClothTex`): folds x1.8, light wrapped 0.15 further, darks deepened by a 1.05 power, glints past 0.05
const float NEX = 1.8;
const float WRAP = 0.15;
const float GAMMA = 1.05;
const float SPEC = 0.05;

varying vec3 pg;
varying vec3 nv;
varying vec2 tuv;
varying flat int bi;

void vertex() {
	int i = int(UV.x + 0.5);
	int jj = int(UV.y + 0.5);
	int b = jj / NY;
	int j = jj - b * NY;
	float rod = tk_rod(b);
	vec3 P = tk_node(i, j, b, rod);
	nv = tk_normal(i, j, b, rod);
	tuv = vec2(tk_u(i), tk_v(j));
	bi = b;
	pg = vec3(bx[b] + P.x, CT + P.y, P.z);
	VERTEX = vec3(pg.x, -pg.y, pg.z);
}

float quant(float c, ivec2 p, bool whole) {
	float lv0 = c / QSTEP;
	if (whole) {
		return floor(lv0 + 0.5) * QSTEP;
	}
	float lo = floor(lv0);
	float f = clamp((lv0 - lo - 0.5) * 6.0 + 0.5, 0.0, 1.0);
	return (lo + (f > tk_bay(p) ? 1.0 : 0.0)) * QSTEP;
}

// the page's lightAt: (light, glint); q 1 stepped with dither, 2 whole steps
vec4 light_at(vec3 w, vec3 n, float v, ivec2 p, int q) {
	vec3 col = amb;
	float glint = -1.0;
	for (int k = 0; k < nl; k++) {
		vec3 l = lp[k].xyz;
		float att = 1.0;
		if (lp[k].w > 0.5) {
			l = lp[k].xyz - w;
			float d2 = dot(l, l);
			l *= inversesqrt(d2);
			att = 1.0 / (1.0 + d2 * lk[k].z);
		}
		att *= lv[k].x + lv[k].y * v / CH;
		float nl0 = dot(n, l);
		float wr = min(0.9, lk[k].x + WRAP);
		float c = max(0.0, (nl0 + wr) / (1.0 + wr)) + lk[k].y * max(0.0, -nl0);
		col += lc[k].rgb * (c * att * lc[k].w * lv[k].z);
		if (lk[k].w > 0.5 && att > 0.2) {
			float hz = l.z + 1.0;
			float hl = sqrt(l.x * l.x + l.y * l.y + hz * hz);
			glint = max(glint, (n.x * l.x + n.y * l.y + n.z * hz - hz) / hl);
		}
	}
	float e = expo;
	float Y = 0.3 * col.r + 0.59 * col.g + 0.11 * col.b;
	float Ye = Y * expo;
	if (Y > 1e-4) {
		// a mark (whole steps) keeps its level; the cloth's darks deepen
		e *= quant(q == 2 ? Ye : pow(Ye, GAMMA), p, q == 2) / Ye;
	}
	return vec4(col * e, glint);
}

void fragment() {
	int tu = clamp(int(floor(tuv.x)), 0, 47);
	int tv = clamp(int(floor(tuv.y)), 0, 99);
	vec4 tx = texelFetch(atlas, ivec2(tu + 48 * bi, tv), 0);
	if (tx.a < 0.25) {
		discard;
	}
	if (mode == 1) {
		ALBEDO = texelFetch(field, ivec2(tu + 48 * bi, tv), 0).rgb;
	} else {
		float a = tx.a * 255.0;
		bool ink = abs(a - 128.0) < 20.0;
		bool gold = abs(a - 192.0) < 20.0;
		vec3 n = nv;
		if (n.z < 0.0) {
			n = -n;
		}
		n.xy *= NEX;
		float ln = length(n);
		n = ln > 0.0 ? n / ln : n;
		ivec2 p = ivec2(floor(pg.xy));
		vec4 L = light_at(vec3(vec2(p) + 0.5, pg.z), n, float(tv), p, ink ? 2 : 1);
		vec3 c = tx.rgb * L.rgb;
		if (gold && L.a > SPEC) {
			// the accent thread flashes
			c += (vec3(1.0, 244.0 / 255.0, 225.0 / 255.0) - c) * vec3(0.35, 0.3, 0.25);
		} else if (ink && L.a > SPEC) {
			// the mark catches the lamp
			c += (vec3(1.0, 235.0 / 255.0, 200.0 / 255.0) - c) * vec3(0.34, 0.34 * 0.76, 0.34 * 0.4);
		}
		ALBEDO = clamp(c, 0.0, 1.0);
	}
}
