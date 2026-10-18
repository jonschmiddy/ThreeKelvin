shader_type canvas_item;

// THE STARS WHERE THE SIDE PANEL GOES (`ZoomLadder`'s calm move; Jon, Oct 17,
// "A · Stars fill it"): while a hop between LOCAL and the map or the chart has
// the side panel and toolbar out of the way, the space they stand in is open
// space -- the map's own dark and a field of stars like its own -- never a dark
// box beside the picture. The stars sit on a plane the move carries: a point
// `u` of it is drawn at `anchor + (u - rest) * scl`, the same scale about your
// ship as the screen they stand beside. The picture itself (`hole`) is left to
// the screen.

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

// one layer of stars on a grid of `cell` px of the plane: at most one star a
// cell, `odds` of the cells lit, a whole game pixel each
float layer(vec2 u, float cell, float odds, float seed) {
	vec2 c = floor(u / cell);
	float h = hash(c + seed);
	if (h > odds) {
		return 0.0;
	}
	vec2 at = (c + vec2(hash(c + seed + 7.1), hash(c + seed + 3.7)) * 0.8 + 0.1) * cell;
	vec2 d = abs(u - at) * scl;
	float on = step(d.x, 0.5) * step(d.y, 0.5);
	return on * (0.35 + 0.65 * hash(c + seed + 1.9));
}

void fragment() {
	vec2 p = rect_pos + UV * rect_size;
	if (hole.z > 0.0 && p.x >= hole.x && p.y >= hole.y && p.x < hole.x + hole.z && p.y < hole.y + hole.w) {
		COLOR = vec4(0.0);
	} else {
		vec2 u = rest + (p - anchor) / max(scl, 0.0001);
		float s = layer(u, 9.0, 0.10, 0.0) * 0.55 + layer(u, 23.0, 0.22, 17.0) * 0.8 + layer(u, 61.0, 0.35, 41.0);
		vec3 star = mix(vec3(0.72, 0.78, 0.92), vec3(1.0, 0.95, 0.85), step(0.6, hash(floor(u / 61.0) + 5.0)));
		COLOR = vec4(mix(bg, star, clamp(s, 0.0, 1.0)), alpha);
	}
}
