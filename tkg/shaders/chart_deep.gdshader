shader_type canvas_item;
render_mode blend_mix;

// THE DEEP FIELD: other galaxies, very far away, in shells at their own
// parallax rates (`StarchartScreen.MapChart`, the DeepField layer;
// `_push_deep` sets the shells up).
//
// Field stars alone say "we are somewhere in a galaxy"; these say "and it is
// one of many". Nothing here is stored. The sky is tiled by position and every
// tile is a pure function of its coordinates and the run seed -- a hash picks
// whether a tile holds anything, what kind of object, how big, which palette,
// and seeds the run of random numbers its pixels are drawn from -- so this
// shader rebuilds exactly the pixels the old GDScript loop did, from the tile
// coordinates alone. Which tiles are on screen moves with the view, so a stored
// mesh would have to be rebuilt as you drag; computing them costs nothing.
//
// The mesh is a fixed number of quad SLOTS: for each shell, enough tiles to
// cover the chart (`lay_s.y` across, `lay_s.z` down), and PER_TILE slots per
// tile, which is the most pixels any object here can have. Slot g of a tile is
// that object's g-th pixel. The CPU says which tiles are in view this frame
// (`lay_r`, the old loop's own i0..i1, j0..j1); everything else is hidden.
// Slots are in the old loop's order -- shell, then i, then j, then pixel -- so
// where two pixels land on one, the same one wins.
//
// Why each rule is what it is:
// - not scaled by zoom. Scaling each shell by pow(zoom, parallax) is textbook
//   depth, and it looked like the scene being redrawn: every pixel re-rounded
//   to a new integer, and a pixel-art starfield has no sub-pixel motion to
//   absorb that -- it just crawls. Distance is carried by pan alone;
// - the deep field is behind the black hole, so it is lensed round it (see
//   `lens`) and swallowed inside it;
// - nothing is culled outright near our own disc: the disc travels at full
//   rate while a shell travels at its parallax, so a hard cull made objects
//   pop in and out as the two slid past each other. They thin instead, by
//   `fade`, and a pixel's own third roll decides whether it survives, so the
//   same pixels drop out at the same distance;
// - each tile rolls a KIND: 0-1 elliptical, 2 spiral, 3 edge-on, 4 nebula,
//   5 cluster. A deep field of identical blobs is wallpaper. Nebulae are the
//   big diffuse things -- "another blob, slightly larger" made the whole field
//   read as one size -- gas rather than stars, so no bright cores and holes in
//   them, or a big one is a solid lump.

#include "res://shaders/chart_sky.gdshaderinc"

const int PER_TILE = 350;

// per shell: centre x, y (`size * 0.5 + sky_pan * parallax`), cell, darkening
uniform vec4 lay_c[16];
// per shell: i0, j0, i1, j1 of the tiles in view
uniform vec4 lay_r[16];
// per shell: first tile slot, tiles across, tiles down, hash salt
uniform vec4 lay_s[16];
// per shell: rad_min, rad_span, bright, and the density as the highest roll in
// thousandths that still keeps a tile (see `MapChart._milli`)
uniform vec4 lay_k[16];
uniform int layers = 0;
uniform int slots = 0;

uniform vec2 here = vec2(0.0);
uniform float guard = 1.0;
uniform float r_s = 0.0;
uniform vec2 size = vec2(0.0);
// six palettes, bright / mid / dim each
uniform vec4 pal[18];

void vertex() {
	int quad = VERTEX_ID / 6;
	int tile = quad / PER_TILE;
	int gi = quad - tile * PER_TILE;
	int k = 0;
	for (int m = 1; m < layers; m++) {
		if (tile >= int(lay_s[m].x)) {
			k = m;
		}
	}
	vec4 C = lay_c[k];
	vec4 R = lay_r[k];
	vec4 S = lay_s[k];
	vec4 K = lay_k[k];
	int ny = int(S.z);
	int own = tile - int(S.x);
	int a = own / ny;
	int b = own - a * ny;
	int i = int(R.x) + a;
	int j = int(R.y) + b;
	bool ok = quad < slots && own < int(S.y) * ny && i <= int(R.z) && j <= int(R.w);

	uint h = hash2(i, j, int(S.w));
	float u = float(h % 1000u) / 1000.0;
	float v = float((h / 1000u) % 1000u) / 1000.0;
	float w = float((h / 1000000u) % 1000u) / 1000.0;
	float kk = float((h / 7u) % 1000u) / 1000.0;
	if (int((h / 13u) % 1000u) > int(K.w)) {
		ok = false;
	}
	uint kind = (h / 17u) % 6u;
	float cell = C.z;
	vec2 q = C.xy + vec2(mul(float(i) + u, cell), mul(float(j) + v, cell));
	float rad = K.x + w * K.y;
	if (kind == 4u) {
		rad *= 2.2 + w * 2.4;
	} else if (kind == 2u) {
		rad *= 1.5;
	}
	if (q.x < -rad * 3.0 || q.y < -rad * 3.0 || q.x > size.x + rad * 3.0 || q.y > size.y + rad * 3.0) {
		ok = false;
	}
	float fade = clamp(len(q - here) / max(1.0, guard), 0.0, 1.0);
	if (fade <= 0.02) {
		ok = false;
	}
	float bright = K.z;
	float tilt = kk * PI;
	float flat_ = 0.16 + w * 0.62;
	int n = int((22.0 + w * 58.0) * bright);
	if (kind == 4u) {
		n = int((150.0 + w * 200.0) * bright);
	} else if (kind == 2u) {
		n = int((90.0 + w * 90.0) * bright);
	} else if (kind == 5u) {
		n = int((28.0 + w * 40.0) * bright);
	}
	if (gi >= n) {
		ok = false;
	}

	uint s1 = lcg_jump(h, uint(3 * gi + 1));
	uint s2 = lcg(s1);
	uint s3 = lcg(s2);
	float t = roll(s1);
	float t2 = roll(s2);
	// The third roll meets fixed thresholds, so it is kept as the integer too.
	uint x3 = roll_i(s3);
	float t3 = float(x3) / 10000.0;

	float rr = 0.0;
	vec2 loc = vec2(0.0);
	if (kind == 2u) {
		// Spiral: two arms wound out of a bright middle.
		rr = pow(t, 0.75) * rad;
		float arm = (gi % 2 == 0) ? 0.0 : PI;
		float ang = arm + t * 3.4 + (t2 - 0.5) * 0.7;
		loc = vec2(cos(ang) * rr, sin(ang) * rr * flat_);
	} else if (kind == 3u) {
		// Edge-on: a sliver with a dust lane down the middle.
		float along = (t - 0.5) * 2.0 * rad;
		float across = (t2 - 0.5) * rad * 0.30 * (1.0 - abs(along) / max(1.0, rad) * 0.7);
		if (abs(across) < rad * 0.035 && abs(along) > rad * 0.2) {
			ok = false;
		}
		rr = abs(along);
		loc = vec2(along, across);
	} else if (kind == 4u) {
		// Nebula: a few overlapping clumps, ragged edges.
		uint lobe = uint(gi % 3);
		float lx = (float((h / (37u + lobe)) % 100u) / 100.0 - 0.5) * rad * 0.9;
		float ly = (float((h / (53u + lobe)) % 100u) / 100.0 - 0.5) * rad * 0.7;
		rr = pow(t, 0.6) * rad * 0.62;
		float na = t2 * TAU;
		loc = vec2(lx + cos(na) * rr, ly + sin(na) * rr * 0.8);
		rr = length(loc);
	} else if (kind == 5u) {
		// Cluster: a loose knot of individual stars.
		rr = pow(t, 2.2) * rad;
		float ca = t2 * TAU;
		loc = vec2(cos(ca) * rr, sin(ca) * rr * 0.9);
	} else {
		rr = pow(t, 1.9) * rad;
		float ea = t2 * TAU;
		loc = vec2(cos(ea) * rr, sin(ea) * rr * flat_);
	}
	float ct = cos(tilt);
	float st = sin(tilt);
	loc = vec2(mul(loc.x, ct) - mul(loc.y, st), mul(loc.x, st) + mul(loc.y, ct));

	vec2 pt = q + loc;
	vec2 bent;
	if (!lens(pt, here, r_s, bent)) {
		ok = false;
	}
	pt = snap(bent);
	if (pt.x < 0.0 || pt.y < 0.0 || pt.x > size.x || pt.y > size.y) {
		ok = false;
	}
	if (t3 > fade) {
		ok = false;
	}
	// t3 > 0.62
	if (kind == 4u && x3 > 6200u) {
		ok = false;
	}

	float near = 1.0 - clamp(rr / max(1.0, rad), 0.0, 1.0);
	int p0 = int((h / 23u) % 6u) * 3;
	vec4 col = pal[p0 + 2];
	// t3 > 0.34, t3 > 0.55, t3 > 0.86
	if (kind == 4u) {
		col = x3 > 3400u ? pal[p0 + 1] : pal[p0 + 2];
	} else if (kind == 5u) {
		col = x3 > 5500u ? pal[p0] : pal[p0 + 1];
	} else if (near > 0.82) {
		col = pal[p0];
	} else if (near > 0.52) {
		col = pal[p0 + 1];
	} else if (x3 > 8600u) {
		col = pal[p0 + 1];
	}
	if (bright < 1.0) {
		col = darkened(col, C.w);
	}
	VERTEX = ok ? quad_corner(VERTEX_ID, pt, vec2(1.0)) : HIDE;
	COLOR = col;
}
