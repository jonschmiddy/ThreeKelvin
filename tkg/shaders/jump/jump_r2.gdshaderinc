// R2 THE FOURTH DIMENSION, shared by its world pass and its hypercube: the hull as a 4D solid
// (the picture thickened along W by its own inner distance) cut at w = w0 after a turn in the
// XW and YW planes, as the approved film's r2.py `slice_hull` did it.
// Why: docs/why/SeqFourth.md#the-4d-hull

uniform sampler2D hull : filter_nearest, repeat_disable;
// JumpHull's: g is the inner distance / 32, whose most is d_in_max
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform float d_in_max = 34.0;
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
// the turn's axis on screen, the thickness at the spine, the hull's cut (gone: none)
uniform vec2 sc = vec2(203.0, 282.0);
uniform float tmax = 70.0;
uniform float hull_cut = 0.0;
// the inverse turn's rows that matter (screen x, y to the hull's u, v and w): the hull, then its echoes
uniform vec2 ru[3];
uniform vec2 rv[3];
uniform vec2 rw[3];
// each cut's offset on screen, its W perspective scale and its w0
uniform vec4 cut_p[3];

const vec3 R2_MAG = vec3(1.00, 0.28, 0.78);
const vec3 R2_MINT = vec3(0.42, 1.00, 0.55);
const vec3 R2_LIL = vec3(0.86, 0.78, 1.00);
const vec3 R2_HOT = vec3(1.00, 0.94, 1.00);

// a place's colour by where it lies along W: mint behind, lilac here, magenta ahead
vec3 r2_wcol(float w) {
	w = clamp(w, -1.0, 1.0);
	float a = clamp(w, 0.0, 1.0);
	float b = clamp(-w, 0.0, 1.0);
	return R2_LIL * (1.0 - a - b) + R2_MAG * a + R2_MINT * b;
}

// cut i at screen point X: rgb in .rgb, 1 where the hull is in .a; where it lies along its
// thickness, -1..1, in rel
vec4 r2_slice(int i, vec2 X, out float rel) {
	rel = 0.0;
	vec2 xy = (X - cut_p[i].xy - sc) / cut_p[i].z;
	float u = dot(ru[i], xy);
	float v = dot(rv[i], xy);
	float w = dot(rw[i], xy);
	vec2 h = floor(vec2(u, v) + sc + 0.5) - ship.xy;
	if (h.x < 0.0 || h.y < 0.0 || h.x >= ship.z || h.y >= ship.w) {
		return vec4(0.0);
	}
	vec4 px = textureLod(hull, (h + 0.5) / ship.zw, 0.0);
	// the thickness along W at the spine is tmax, rounded off toward the edge as (d / dmax)^0.55
	float th = tmax * pow(clamp(textureLod(aux, (h + 0.5) / ship.zw, 0.0).g * 32.0 / d_in_max, 0.0, 1.0), 0.55);
	float wr = w - cut_p[i].w;
	if (px.a <= 0.0 || abs(wr) > th) {
		return vec4(0.0);
	}
	rel = wr / max(th, 1.0);
	return vec4(px.rgb, 1.0);
}

// the main cut's coverage at a whole pixel (what hides the hypercube's far side)
bool r2_hull_at(vec2 pix) {
	if (hull_cut < 0.5) {
		return false;
	}
	float rel;
	return r2_slice(0, pix, rel).a > 0.5;
}
