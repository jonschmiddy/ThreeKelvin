shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE GALAXY'S BRIGHT STARS, one 2x2 block each (`ChartSky`). The chart's own
// star field (`_build_stars`), re-tilted as the bake re-tilts it, but only the
// stars bright enough to be seen one at a time, and only where they stand out
// from the light under them -- so the arms are made of their own stars rather
// than of a wash with a sprinkle laid over it.
//
// Each turns at its own radius by the galaxy's one law: rigidly with the disc
// and every system on it, faster only inside the innermost ring. A globular
// cluster is a ball in the halo, so it turns as one, round its own centre.
// The colour is written as it should look; the palette pass gives it the
// nearest of the galaxy's own colours.

#include "res://shaders/chart_l_galaxy.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D star_pos : filter_nearest;
uniform sampler2D star_col : filter_nearest;
uniform sampler2D star_big : filter_nearest;
uniform sampler2D core_r : filter_nearest;
uniform sampler2D core_a : filter_nearest;
uniform sampler2D core_col : filter_nearest;
uniform int tex_w = 2048;
uniform int n_star = 0;
uniform int n_core = 0;
uniform float to_base = 1.0;
uniform float sq = 0.62;
uniform float eff = 0.38;
uniform float dk = 1.0;
uniform float bul_r = 10.0;
// the disc's rim (bake pixels): its stars thin out over the last quarter, as the
// field's light does (`chart_field`'s `rim_fade`)
uniform float rim_r = 1e6;
uniform ivec2 glob[32];
uniform vec2 glob_c[32];
uniform int n_glob = 0;
// 1: the clusters are drawn as glows (`chart_field`), only a couple of their
// stars at the edge when close; 0: every star a block
uniform int cluster_look = 0;

uniform vec2 vp_origin = vec2(-2.0);
uniform vec2 cpix = vec2(327.0, 217.0);
uniform float z = 1.0;
uniform float phi = 0.0;
uniform float t = 0.0;
uniform float rin_p = 10.0;
uniform float rb = 30.0;
// how many stars (`ChartSky.star_level`): the dimmest go first
uniform int star_level = 1;
// within this many screen pixels of the hole a star is drawn whether or not
// it outshines the light under it (`chart_field`'s `near_r`), one in ten of
// those that would otherwise be hidden
uniform float near_r = 0.0;

varying vec4 v_col;
varying float v_near;

const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

float wk(float r) {
	if (r >= rb) {
		return 0.0;
	}
	// (at 0.4 of the disc's own law: "have the stars around the black hole
	// move a bit slower", Jon -- the disc keeps its spin, what is round it calms)
	return 0.4 * 1.1 * pow(max(r, rin_p) / rin_p, -1.5) * (1.0 - g_sm(0.5 * rb, rb, r));
}

void vertex() {
	int id = VERTEX_ID / 6;
	vec2 p;
	vec3 c;
	int k;
	if (id < n_star) {
		ivec2 at = ivec2(id % tex_w, id / tex_w);
		p = texelFetch(star_pos, at, 0).xy * to_base;
		c = texelFetch(star_col, at, 0).rgb;
		int big = int(floor(texelFetch(star_big, at, 0).r * 255.0 + 0.5));
		float val = max(c.r, max(c.g, c.b));
		k = big == 2 ? 2 : (big == 1 ? 1 : (val >= 0.075 ? 0 : 3));
	} else {
		int j = id - n_star;
		ivec2 at = ivec2(j % tex_w, j / tex_w);
		float r = texelFetch(core_r, at, 0).r;
		float a = texelFetch(core_a, at, 0).r;
		p = vec2(cos(a), sin(a)) * r * to_base;
		c = texelFetch(core_col, at, 0).rgb;
		k = 4;
	}
	float lm = g_lum(c * 255.0);
	float disc_min = star_level >= 4 ? 178.0 : (star_level >= 3 ? 150.0 : (star_level == 2 ? 80.0 : 60.0));
	float core_min = star_level >= 4 ? 192.0 : (star_level >= 3 ? 170.0 : 150.0);
	bool show = id < n_star + n_core
		&& (((k == 0 || k == 1) && lm >= disc_min) || (k == 4 && lm >= core_min));
	int gi = -1;
	if (id < n_star) {
		for (int g = 0; g < 32; g++) {
			if (g >= n_glob) {
				break;
			}
			if (id >= glob[g].x && id < glob[g].y) {
				gi = g;
				break;
			}
		}
	}
	// a globular cluster keeps every star: it is one object
	if (gi >= 0 && id < n_star + n_core && (k == 0 || k == 1) && lm >= 60.0) {
		show = true;
		if (cluster_look >= 1) {
			// a couple of its stars, out at its edge, once you are close
			float off = length(p - glob_c[gi]);
			show = z >= 2.5 && off > 1.2 && g_hash(id, 401) < 0.05;
		}
	}
	vec2 rel;
	if (gi >= 0) {
		vec2 cc = glob_c[gi];
		float xd = cc.x, yd = cc.y / eff;
		float r = length(vec2(xd, yd));
		float ang = atan(yd, xd) - phi;
		vec2 off = p - cc;
		rel = vec2(cos(ang) * r + off.x, sin(ang) * r * eff + off.y) * z;
	} else {
		float xd = p.x, yd = p.y / sq;
		float r = length(vec2(xd, yd));
		float b = exp(-(r / bul_r) * (r / bul_r)) * dk;
		float ct = g_hash(id, 71) * 2.0 - 1.0;
		float stt = sqrt(max(0.0, 1.0 - ct * ct));
		float g2 = g_hash(id, 74) + g_hash(id, 75) - 1.0;
		float xb = xd + (xd * stt - xd) * b;
		float yb = yd + (yd * stt - yd) * b;
		float zz = r * ct * b + g2 * 1.4 * dk;
		float rs = length(vec2(xb, yb));
		// (thinning as the disc's light does, by about e every half radius past
		// half of it)
		if (rs > rim_r * 0.55 && g_hash(id, 503) > exp(-(rs / rim_r - 0.55) / 0.5)) {
			show = false;
		}
		float ang = atan(yb, xb) - (phi + mod(wk(rs) * t, TAU_G));
		rel = vec2(cos(ang) * rs, sin(ang) * rs * eff - zz * SIN_I) * z;
	}
	vec2 spx = floor(cpix + rel + 0.5);
	vec2 blk = floor((spx - vp_origin) * 0.5);
	VERTEX = show ? blk + CORNER[VERTEX_ID % 6] : vec2(-100000.0);
	// TRUE WHITE ONLY FOR THE FEW BRIGHTEST (level 4): a near-white star a
	// step down from the top is drawn at the dimmer shade every palette
	// keeps, a tinted star colour instead of a white speck
	if (star_level >= 4 && lm < 225.0 && min(c.r, min(c.g, c.b)) > 0.78) {
		c *= 0.72;
	}
	v_col = vec4(c * 255.0, lm);
	// (one in ten of the stars the light would hide: accents, not speckle)
	v_near = (length(spx - cpix) < near_r && g_hash(id, 93) < 0.1) ? 1.0 : 0.0;
}

void fragment() {
	vec4 under = texture(screen_tex, SCREEN_UV);
	if (v_near < 0.5 && v_col.a < g_lum(under.rgb * 255.0) * 1.12 + 6.0) {
		discard;
	}
	bool keep = abs(under.a - 0.75) < 0.1 || abs(under.a - 0.25) < 0.1;
	COLOR = vec4(v_col.rgb / 255.0, keep ? 0.25 : 0.5);
}
