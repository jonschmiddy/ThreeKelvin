shader_type canvas_item;
render_mode unshaded, blend_add;

// THE GALAXY'S POINTS, ADDED UP, once a galaxy (`ChartSky`'s bake). Every star,
// gas block and dust pixel `_build_stars` made, plus the core's, lands on one
// texel of the bake's window (the chart's opening view, in its own pixels) and
// adds into a float picture that the blur passes then spread:
//   mode 0, the light: colour times weight;
//   mode 1, in R the part of the light that belongs to the bulge, in G the
//           dark dust, counted;
//   mode 2, the lit gas of the clouds, in its colours.
// Alpha is always 1: an additive canvas multiplies colour by it.
// RE-TILTED ON THE WAY IN, to the sector map's angle: x stays, y goes from the
// galaxy's own squash to the disc's (`eff`), a bulge star is lifted onto a
// sphere of its own radius so the bulge is a ball, a cloud keeps its shape
// round its own re-tilted centre, and a globular cluster is left out (they are
// drawn as stars, `chart_galaxy_stars.gdshader`).

#include "res://shaders/chart_l_galaxy.gdshaderinc"

uniform sampler2D star_pos : filter_nearest;
uniform sampler2D star_col : filter_nearest;
uniform sampler2D star_big : filter_nearest;
uniform sampler2D core_r : filter_nearest;
uniform sampler2D core_a : filter_nearest;
uniform sampler2D core_col : filter_nearest;
uniform int tex_w = 2048;
uniform int n_star = 0;
uniform int n_core = 0;
uniform int mode = 0;
// drawn pixels to the bake's pixels
uniform float to_base = 1.0;
uniform float sq = 0.62;
uniform float eff = 0.38;
uniform float dk = 1.0;
uniform float bul_r = 10.0;
uniform vec2 origin = vec2(448.0, 308.0);
// the clouds, in the bake's pixels: x, y, radius, 1 when dark
uniform vec4 clouds[16];
uniform int n_clouds = 0;
// the globular clusters' stars, as index ranges of the star field
uniform ivec2 glob[32];
uniform int n_glob = 0;

varying vec4 v_col;

const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

void vertex() {
	int id = VERTEX_ID / 6;
	vec2 hide = vec2(-100000.0);
	vec2 p;
	vec3 c;
	int k;
	if (id < n_star) {
		ivec2 at = ivec2(id % tex_w, id / tex_w);
		p = texelFetch(star_pos, at, 0).xy * to_base;
		c = texelFetch(star_col, at, 0).rgb;
		int big = int(floor(texelFetch(star_big, at, 0).r * 255.0 + 0.5));
		float val = max(c.r, max(c.g, c.b));
		if (big == 2) {
			k = val < 0.12 ? 3 : 2;
		} else if (big == 1) {
			k = 1;
		} else {
			k = val >= 0.075 ? 0 : 3;
		}
	} else {
		int j = id - n_star;
		ivec2 at = ivec2(j % tex_w, j / tex_w);
		float r = texelFetch(core_r, at, 0).r;
		float a = texelFetch(core_a, at, 0).r;
		p = vec2(cos(a), sin(a)) * r * to_base;
		c = texelFetch(core_col, at, 0).rgb;
		k = 4;
	}
	bool glob_star = false;
	if (id < n_star) {
		for (int g = 0; g < 32; g++) {
			if (g >= n_glob) {
				break;
			}
			if (id >= glob[g].x && id < glob[g].y) {
				glob_star = true;
				break;
			}
		}
	}
	vec2 at_px = hide;
	vec4 out_c = vec4(0.0);
	float xd = p.x, yd = p.y / sq;
	if (k == 2 || k == 3) {
		int best = -1;
		float bd = 1e9;
		for (int q = 0; q < 16; q++) {
			if (q >= n_clouds) {
				break;
			}
			float d = length(p - clouds[q].xy) / max(1.0, clouds[q].z);
			if (d < bd) {
				bd = d;
				best = q;
			}
		}
		float y;
		bool dust = false;
		bool drop = false;
		if (best >= 0 && bd < 1.6) {
			vec4 cl = clouds[best];
			float flat_k = max(0.3, eff / 0.82);
			y = cl.y / sq * eff + (p.y - cl.y) * flat_k;
			dust = cl.w > 0.5 || k == 3;
		} else {
			y = yd * eff;
			drop = k == 3;
		}
		if ((mode == 1 && dust && !drop) || (mode == 2 && !dust && !drop)) {
			at_px = vec2(floor(xd + 0.5), floor(y + 0.5)) + origin;
			out_c = mode == 1 ? vec4(0.0, 1.0, 0.0, 1.0) : vec4(c, 1.0);
		}
	} else if (!glob_star && mode < 2) {
		float r = length(vec2(xd, yd));
		float b = exp(-(r / bul_r) * (r / bul_r)) * dk;
		int i = id;
		float ct = g_hash(i, 71) * 2.0 - 1.0;
		float stt = sqrt(max(0.0, 1.0 - ct * ct));
		float g2 = g_hash(i, 74) + g_hash(i, 75) - 1.0;
		float xb = xd + (xd * stt - xd) * b;
		float yb = yd + (yd * stt - yd) * b;
		float zz = r * ct * b + g2 * 1.4 * dk;
		vec2 q = vec2(xb, yb * eff - zz * SIN_I);
		float w = k == 1 ? 2.2 : (k == 4 ? 0.7 : 1.0);
		float l = w * g_lum(c);
		at_px = vec2(floor(q.x + 0.5), floor(q.y + 0.5)) + origin;
		out_c = mode == 0 ? vec4(c * w, 1.0) : vec4(l * b, 0.0, 0.0, 1.0);
	}
	if (id >= n_star + n_core) {
		at_px = hide;
	}
	VERTEX = at_px + CORNER[VERTEX_ID % 6];
	v_col = out_c;
}

void fragment() {
	COLOR = v_col;
}
