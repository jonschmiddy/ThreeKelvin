shader_type canvas_item;
// (premultiplied onto a cleared picture: what is written is stored exactly --
// the alpha below is a count as well as a coverage)
render_mode unshaded, blend_premul_alpha;

// A PIXEL-ART PICTURE TURNED, pixel for pixel (`PixelTurn.Turner`): every pixel
// of the turned box looks back into the original at `ss` x `ss` points across
// itself and takes the colour most of them land on -- the original's own
// colours, never a blend -- with the point at its middle breaking a tie, so a
// line one pixel wide stays one pixel wide. That alone makes a pixel change
// where the art under it has mostly moved, not where one point happened to
// cross an edge. (`ss` 1: the plain nearest pixel, as `LocalSubject.turned`.)
//
// THE HOLD (`memory`): `prev` is this picture last frame, and a pixel keeps
// the colour it had while that colour still covers at least `margin` fewer of
// its points than the commonest one -- an edge crossing a pixel changes it
// once, when it has clearly crossed, and a turn that wavers back does not
// flip it back. A pixel held `release` frames lets go, so nothing freezes.
// How long a pixel has been held rides in its alpha: an opaque pixel's alpha
// is 255 - frames, a clear one's is frames, so whatever shows the picture
// snaps alpha at a half.

uniform sampler2D src : filter_nearest, repeat_disable;
uniform vec2 src_size = vec2(1.0);
uniform vec2 out_size = vec2(1.0);
// screen pixels a texel of the original
uniform float scl = 1.0;
// radians, clockwise on screen (as `Node2D.rotation`)
uniform float angle = 0.0;
// mirrored left to right before it is turned (as `Sprite2D.flip_h`)
uniform bool flip = false;
// where the piece's middle is from the box's, px (its drift, any fraction)
uniform vec2 shift = vec2(0.0);
uniform int ss = 4;
uniform bool memory = false;
uniform sampler2D prev : filter_nearest, repeat_disable;
// nothing held: the first frames, before `prev` holds this picture
uniform bool fresh = true;
uniform int margin = 4;
uniform int release = 40;
// SOFT (`PixelTurn` SOFT, a trial): the points averaged in linear light, the
// edge as much clear as its points are -- nothing picked, so nothing flips
// (premultiplied, as the picture is stored)
uniform bool soft = false;
// FADE (a trial): two whole pictures, this step (`angle`, `shift`) and the one
// before (`angle_b`, `shift_b`), each picked as above, dissolved `fade` of the
// way to this one in linear light
uniform bool fade_on = false;
uniform float angle_b = 0.0;
uniform vec2 shift_b = vec2(0.0);
uniform float fade = 1.0;

// the original's colour under point `p` (screen px from the box's middle):
// opaque, or clear as (0, 0, 0, 0)
vec4 at_a(vec2 p, float ang) {
	float c = cos(ang), s = sin(ang);
	vec2 q = vec2(p.x * c + p.y * s, -p.x * s + p.y * c) / scl;
	if (flip) {
		q.x = -q.x;
	}
	vec2 t = floor(q + src_size * 0.5);
	if (t.x < 0.0 || t.y < 0.0 || t.x >= src_size.x || t.y >= src_size.y) {
		return vec4(0.0);
	}
	vec4 k = texture(src, (t + 0.5) / src_size);
	return k.a < 0.5 ? vec4(0.0) : vec4(k.rgb, 1.0);
}

vec4 at(vec2 p) {
	return at_a(p, angle);
}

bool same(vec4 a, vec4 b) {
	return a.a == b.a && all(lessThan(abs(a.rgb - b.rgb), vec3(0.002)));
}

// the commonest of 16 points across the pixel `o` (box px) turned `ang` and
// moved `sh`, a tie to the middle's (FADE's pictures)
vec4 pick(vec2 o, float ang, vec2 sh) {
	vec2 p0 = o + 0.5 - out_size * 0.5 - sh;
	vec4 cs[16];
	for (int i = 0; i < 4; i++) {
		for (int j = 0; j < 4; j++) {
			cs[i * 4 + j] = at_a(p0 + (vec2(float(j), float(i)) + 0.5) / 4.0 - 0.5, ang);
		}
	}
	vec4 cen = at_a(p0, ang);
	int best = -1, bi = 0;
	for (int i = 0; i < 16; i++) {
		int c = 0;
		for (int j = 0; j < 16; j++) {
			if (same(cs[i], cs[j])) c++;
		}
		int score = c * 2 + (same(cs[i], cen) ? 1 : 0);
		if (score > best) {
			best = score;
			bi = i;
		}
	}
	return cs[bi];
}

void fragment() {
	vec2 o = floor(UV * out_size);
	if (fade_on) {
		vec4 A = pick(o, angle, shift);
		vec4 B = fade < 1.0 ? pick(o, angle_b, shift_b) : A;
		float a = mix(B.a, A.a, fade);
		vec3 lin = pow(A.rgb, vec3(2.2)) * A.a * fade + pow(B.rgb, vec3(2.2)) * B.a * (1.0 - fade);
		vec3 c = a > 0.0 ? pow(lin / a, vec3(1.0 / 2.2)) : vec3(0.0);
		COLOR = vec4(c * a, a);
	} else {
	vec2 p0 = o + 0.5 - out_size * 0.5 - shift;
	int n = clamp(ss, 1, 4);
	int m = n * n;
	vec4 cols[16];
	for (int i = 0; i < 4; i++) {
		if (i >= n) break;
		for (int j = 0; j < 4; j++) {
			if (j >= n) break;
			cols[i * n + j] = at(p0 + (vec2(float(j), float(i)) + 0.5) / float(n) - 0.5);
		}
	}
	if (soft) {
		vec3 acc = vec3(0.0);
		float cov = 0.0;
		for (int i = 0; i < 16; i++) {
			if (i >= m) break;
			acc += pow(cols[i].rgb, vec3(2.2)) * cols[i].a;
			cov += cols[i].a;
		}
		float a = cov / float(m);
		vec3 c = cov > 0.0 ? pow(acc / cov, vec3(1.0 / 2.2)) : vec3(0.0);
		COLOR = vec4(c * a, a);
	} else {
	vec4 cen = n == 1 ? cols[0] : at(p0);
	// the commonest colour; a tie goes to the one under the middle
	int best = -1, cnt = 0, bi = 0;
	for (int i = 0; i < 16; i++) {
		if (i >= m) break;
		int c = 0;
		for (int j = 0; j < 16; j++) {
			if (j >= m) break;
			if (same(cols[i], cols[j])) c++;
		}
		int score = c * 2 + (same(cols[i], cen) ? 1 : 0);
		if (score > best) {
			best = score;
			cnt = c;
			bi = i;
		}
	}
	vec4 win = cols[bi];
	vec4 outc = win;
	int held = 0;
	if (memory && !fresh) {
		vec4 P = texture(prev, UV);
		bool p_op = P.a >= 0.5;
		int pc = p_op ? int(round((1.0 - P.a) * 255.0)) : int(round(P.a * 255.0));
		vec4 pcol = p_op ? vec4(P.rgb, 1.0) : vec4(0.0);
		if (!same(pcol, win)) {
			int cp = 0;
			for (int j = 0; j < 16; j++) {
				if (j >= m) break;
				if (same(cols[j], pcol)) cp++;
			}
			if (cp > 0 && cnt - cp < margin && pc + 1 < release) {
				outc = pcol;
				held = pc + 1;
			}
		}
	}
	if (outc.a > 0.5) {
		COLOR = vec4(outc.rgb, memory ? float(255 - held) / 255.0 : 1.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, memory ? float(held) / 255.0 : 0.0);
	}
	}
	}
}
