shader_type canvas_item;
render_mode blend_mix;

// THE HALO: field stars at many depths, over the galaxy, the sky our galaxy is
// seen THROUGH (`StarchartScreen.MapChart`, the Halo layer; `_push_halo` sets
// the depths up).
//
// Two depths meant every star moved at one of two speeds, and the eye finds
// that instantly -- two sheets of glass sliding over each other. With many, no
// two neighbouring stars quite agree about how fast to move, which is what
// parallax looks like. Each depth is tiled by position, at most one star a
// tile, and the tile hash decides everything about it, so like the deep field
// this is computed rather than stored: one quad slot per tile in view, in the
// old loop's order (depth, then i, then j).
//
// Why each rule is what it is:
// - lensed round the black hole and swallowed inside it, like the deep field;
// - thinned over the disc so the halo never competes with the arms, and
//   GRADUALLY: a binary test inside a radius draws a circle, a dark moat round
//   the galaxy with a hard rim. `fade` runs from 1 at the centre to 0 at
//   `disc` over the outer `feather` of it, and a star survives if its own roll
//   clears 0.88 of it. `disc` is the galaxy's drawn extent times 1.1 -- without
//   the DISC factor the thinned region fell inside the systems and read as a
//   ring drawn across the disc;
// - blocked by dark clouds. These were drawn straight through the galaxy, so
//   the brightest twelve percent that survive the thinning shone out of the
//   middle of every dark nebula. Faded by the same shoulder, or the extinction
//   puts a second hard rim back where the first one left;
// - nothing at all over the turning core: a static star near a moving one is
//   the thing that gives the whole effect away, whichever layer it is in.

#include "res://shaders/chart_sky.gdshaderinc"

// per depth: centre x, y (`size * 0.5 + sky_pan * parallax`), cell, darkening
uniform vec4 hl_c[48];
// per depth: i0, j0, i1, j1 of the tiles in view
uniform vec4 hl_r[48];
// per depth: first tile slot, tiles across, tiles down, hash salt
uniform vec4 hl_s[48];
// per depth: bright
uniform float hl_b[48];
uniform int layers = 0;
uniform int slots = 0;

uniform vec2 here = vec2(0.0);
uniform float r_s = 0.0;
uniform float disc = 1.0;
uniform float core_px = 0.0;
uniform float zoom = 1.0;
uniform vec2 size = vec2(0.0);
// a tile holds a star when its roll, in thousandths, is at least this
uniform int empty_m = 340;
uniform float feather = 0.34;
// dark cloud lobes in drawn galaxy space: x, y, radius
uniform vec4 dark[32];
uniform int n_dark = 0;
uniform vec4 col_dim = vec4(0.0);
uniform vec4 col_mid = vec4(0.0);
uniform vec4 col_hi = vec4(0.0);

float extinct(vec2 p) {
	float e = 0.0;
	for (int i = 0; i < n_dark; i++) {
		float d = len(p - dark[i].xy) / max(1.0, dark[i].z);
		if (d < 1.0) {
			float f = 1.0 - d;
			e = max(e, f * f * (3.0 - 2.0 * f));
		}
	}
	return e;
}

void vertex() {
	int tile = VERTEX_ID / 6;
	int k = 0;
	for (int m = 1; m < layers; m++) {
		if (tile >= int(hl_s[m].x)) {
			k = m;
		}
	}
	vec4 C = hl_c[k];
	vec4 R = hl_r[k];
	vec4 S = hl_s[k];
	int ny = int(S.z);
	int own = tile - int(S.x);
	int a = own / ny;
	int b = own - a * ny;
	int i = int(R.x) + a;
	int j = int(R.y) + b;
	bool ok = tile < slots && own < int(S.y) * ny && i <= int(R.z) && j <= int(R.w);

	uint h = hash2(i, j, int(S.w));
	// The tile's roll in thousandths. Its fixed thresholds below are compared
	// as integers: see `roll_i`.
	int mw = int(h % 1000u);
	float w = float(mw) / 1000.0;
	// Most tiles are empty sky.
	if (mw < empty_m) {
		ok = false;
	}
	float u = float((h / 1000u) % 1000u) / 1000.0;
	float v = float((h / 1000000u) % 1000u) / 1000.0;
	float cell = C.z;
	vec2 q = C.xy + vec2(mul(float(i) + u, cell), mul(float(j) + v, cell));
	vec2 bent;
	if (!lens(q, here, r_s, bent)) {
		ok = false;
	}
	q = snap(bent);
	if (q.x < 0.0 || q.y < 0.0 || q.x > size.x || q.y > size.y) {
		ok = false;
	}
	float dr = len(q - here) / max(1.0, disc);
	float fade = clamp((1.0 - dr) / feather, 0.0, 1.0);
	if (w < 0.88 * fade) {
		ok = false;
	}
	if (fade > 0.0 && n_dark > 0) {
		float ex = extinct((q - here) / max(0.001, zoom)) * fade;
		if (ex > 0.02 && float((h / 7u) % 1000u) / 1000.0 < ex) {
			ok = false;
		}
	}
	if (len(q - here) < core_px) {
		ok = false;
	}
	// w > 0.985, w > 0.93
	vec4 col = col_dim;
	if (mw > 985) {
		col = col_hi;
	} else if (mw > 930) {
		col = col_mid;
	}
	if (hl_b[k] < 1.0) {
		col = darkened(col, C.w);
	}
	VERTEX = ok ? quad_corner(VERTEX_ID, q, vec2(1.0)) : HIDE;
	COLOR = col;
}
