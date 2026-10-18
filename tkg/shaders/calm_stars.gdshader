shader_type canvas_item;

// THE STARS WHERE THE SIDE PANEL GOES (`ZoomLadder`'s calm move; Jon, Oct 17,
// "A · Stars fill it"): while a hop between LOCAL and the map or the chart has
// the side panel and toolbar out of the way, the space they stand in is open
// space -- the map's own dark and a field of stars like its own -- never a dark
// box beside the picture. The stars sit on a plane the move carries: a point
// `u` of it is drawn at `anchor + (u - rest) * scl`, the same scale about your
// ship as the screen they stand beside. The picture itself (`hole`) is left to
// the screen.
//
// LIKE THE MAP'S OWN (`SystemView._Field`, `FIELDS`): each star a 2x2 block on
// the game's even pixels whatever the scale, its colour the ground lerped to a
// star's temperature (`SkyBake.TEMPS`) by its brightness, the brighter ones
// with a dim plus round them; layers from many faint to few bright, about as
// many to the area as the map shows.

uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(960.0, 540.0);
uniform vec4 hole = vec4(0.0);
uniform vec2 anchor = vec2(480.0, 270.0);
uniform vec2 rest = vec2(480.0, 270.0);
uniform float scl = 1.0;
uniform vec3 bg = vec3(0.03, 0.043, 0.082);
uniform float alpha = 1.0;

float hash(vec2 q) {
	q = fract(q * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

vec3 temp(float u) {
	if (u < 0.12) return vec3(0.62, 0.74, 1.0);
	if (u < 0.42) return vec3(0.86, 0.9, 1.0);
	if (u < 0.72) return vec3(1.0, 0.96, 0.9);
	if (u < 0.9) return vec3(1.0, 0.84, 0.64);
	return vec3(1.0, 0.66, 0.46);
}

// One layer: a star a `cell` of the plane (px at rest), brightness `lo`..`hi`
// (most near `lo`), a share `plus` with a plus. Adds what it draws at `p` to
// `col`/`cov` (the brightest wins).
void layer(vec2 p, vec2 u, float cell, float lo, float hi, float plus, float seed, inout vec3 col, inout float best) {
	vec2 c0 = floor(u / cell);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = c0 + vec2(float(i), float(j));
			vec2 at = (c + vec2(hash(c + seed + 7.1), hash(c + seed + 3.7))) * cell;
			vec2 s = anchor + (at - rest) * scl;
			vec2 q = floor(s / 2.0) * 2.0;
			vec2 d = floor((p - q) / 2.0);
			float h = hash(c + seed + 1.9);
			float I = lo + (hi - lo) * h * h;
			float k = 0.0;
			if (d.x == 0.0 && d.y == 0.0) {
				k = 1.0;
			} else if (hash(c + seed + 5.3) < plus && abs(d.x) + abs(d.y) == 1.0) {
				k = 0.45;
			}
			if (k > 0.0 && I * k > best) {
				best = I * k;
				vec3 sc = mix(bg, temp(hash(c + seed + 9.7)), I);
				col = mix(bg, sc, k);
			}
		}
	}
}

void fragment() {
	vec2 p = floor(rect_pos + UV * rect_size);
	if (hole.z > 0.0 && p.x >= hole.x && p.y >= hole.y && p.x < hole.x + hole.z && p.y < hole.y + hole.w) {
		COLOR = vec4(0.0);
	} else {
		vec2 u = rest + (p - anchor) / max(scl, 0.0001);
		vec3 col = bg;
		float best = 0.0;
		layer(p, u, 18.0, 0.12, 0.4, 0.0, 0.0, col, best);
		layer(p, u, 34.0, 0.25, 0.65, 0.02, 29.0, col, best);
		layer(p, u, 63.0, 0.15, 0.45, 0.03, 17.0, col, best);
		layer(p, u, 86.0, 0.3, 0.7, 0.08, 41.0, col, best);
		layer(p, u, 143.0, 0.5, 1.0, 0.2, 73.0, col, best);
		layer(p, u, 216.0, 0.6, 1.0, 0.7, 97.0, col, best);
		COLOR = vec4(col, alpha);
	}
}
