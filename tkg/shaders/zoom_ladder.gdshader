shader_type canvas_item;

// THE ZOOM LADDER'S HANDOFF (`ZoomLadder`): the screen being left, held as the
// last picture it drew, carried through the move over the screen arriving,
// which is live underneath and moving its own camera. Everything here is in
// game pixels (the 960x540 picture), and every edge is an ordered dither in
// 2x2 cells, the grid the map's and LOCAL's skies are drawn on -- never a soft
// alpha, which reads as a fade.
//
// The old picture is placed by one affine map: the point `to_pt` on screen shows
// the old picture's `from_pt`, scaled by `scl` (x and y apart, so the map can be
// laid down into LOCAL's plane). Only its picture rect (`pic`) moves; what is
// round it -- panels, strips -- is chrome, and goes where it stood.
//
// MODES, what decides which old pixels are still up at progress `t`:
//   0 DIVE: from the anchor outward (spread > 0) or inward (< 0), measured
//     in the held picture (`reach` its own px)
//   1 IRIS: a hole round `c` grows (an ellipse by `axis`), its rim dithered
//   2 STARS: the dark of the old goes first, its bright points last
//   3 MOSAIC: blocks of `block` px; the old to half way, the new after it

uniform sampler2D old_tex : filter_nearest;
// the same picture filtered, for `sharp`: sampled between its pixels so it
// slides by fractions of a pixel, its pixels still square (a sharp bilinear)
uniform sampler2D old_lin : filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 vp = vec2(960.0, 540.0);
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(960.0, 540.0);
uniform vec4 pic = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec2 from_pt = vec2(480.0, 270.0);
uniform vec2 to_pt = vec2(480.0, 270.0);
uniform vec2 scl = vec2(1.0);
uniform int mode = 0;
uniform float t = 0.0;
uniform vec2 c = vec2(480.0, 270.0);
uniform float reach = 600.0;
uniform float spread = 0.6;
uniform vec2 axis = vec2(1.0, 1.0);
uniform float rim = 10.0;
uniform float chrome_t = 0.0;
uniform float block = 1.0;
uniform float cell = 2.0;
uniform float edge = 0.0;
// SOFT: the held picture leaves by how much of it is kept (an alpha), with no
// dither -- what Jon asked of the smoother moves -- instead of by the threshold
uniform float soft = 0.0;
uniform float sharp = 0.0;
// a hole in the held picture (its own px: centre, radius; 0 for none) where
// the live screen draws the same thing -- the world handed over in 2C
uniform vec3 hole = vec3(0.0);

float bayer4(vec2 q) {
	ivec2 i = ivec2(mod(q, 4.0));
	int x = i.x;
	int y = i.y;
	int v = ((x ^ y) & 1) * 8 + (y & 1) * 4 + (((x ^ y) >> 1) & 1) * 2 + ((y >> 1) & 1);
	return (float(v) + 0.5) / 16.0;
}

vec4 old_at(vec2 q) {
	if (sharp > 0.5) {
		// sharp bilinear: whole texels, blended only across their own edges,
		// over as much of a texel as one screen pixel covers
		vec2 w = max(fwidth(q), vec2(0.0001));
		vec2 f = fract(q - 0.5);
		vec2 g = clamp((f - 0.5) / min(w, vec2(1.0)) + 0.5, 0.0, 1.0);
		return texture(old_lin, (floor(q - 0.5) + 0.5 + g) / vp);
	}
	return texture(old_tex, q / vp);
}

// The old picture minified smoothly (a 2x2 box) when it shrinks, so it does not
// drop whole rows of pixels on the way down.
vec4 old_pic(vec2 q) {
	if (scl.x < 0.85) {
		vec2 h = 0.25 / scl;
		vec4 a = old_at(q + vec2(-h.x, -h.y)) + old_at(q + vec2(h.x, -h.y))
			+ old_at(q + vec2(-h.x, h.y)) + old_at(q + vec2(h.x, h.y));
		return a * 0.25;
	}
	return old_at(q);
}

bool in_rect(vec2 q, vec4 r) {
	return q.x >= r.x && q.y >= r.y && q.x < r.x + r.z && q.y < r.y + r.w;
}

void fragment() {
	vec2 p = rect_pos + UV * rect_size;
	vec2 pc = (floor(p / cell) + 0.5) * cell;
	float thr = bayer4(floor(p / cell));
	if (mode == 3) {
		// blocks on the 2x2 grid, both pictures
		float b = max(block, 1.0);
		vec2 pb = (floor(p / b) + 0.5) * b;
		if (t < 0.5) {
			vec2 q = from_pt + (pb - to_pt) / scl;
			if (in_rect(q, pic)) {
				COLOR = vec4(old_pic(q).rgb, 1.0);
			} else if (!in_rect(pb, pic) && chrome_t < thr) {
				COLOR = vec4(old_at(pb).rgb, 1.0);
			} else {
				COLOR = vec4(texture(screen_tex, pb / vp).rgb, 1.0);
			}
		} else if (b > 1.0) {
			COLOR = vec4(texture(screen_tex, pb / vp).rgb, 1.0);
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		vec2 q = from_pt + (p - to_pt) / scl;
		float keep = 0.0;
		bool picture = in_rect(q, pic);
		bool in_hole = hole.z > 0.0 && length(q - hole.xy) < hole.z;
		if (in_hole) {
			picture = false;
		}
		if (picture) {
			if (mode == 0) {
				// measured in the held picture's own pixels, so its far edges go
				// first however small it has been made
				vec2 qc = from_pt + (pc - to_pt) / scl;
				float d = length((qc - from_pt) / axis) / reach;
				if (spread < 0.0) {
					d = 1.0 - clamp(d, 0.0, 1.0);
				}
				float s = abs(spread);
				keep = 1.0 - clamp(t * (1.0 + s) - s * clamp(d, 0.0, 1.0), 0.0, 1.0);
			} else if (mode == 1) {
				float d = length((pc - c) / axis);
				float r = t * reach;
				keep = clamp((d - r) / rim + 0.5, 0.0, 1.0);
			} else {
				vec3 o = old_pic(q).rgb;
				float l = max(max(o.r, o.g), o.b);
				keep = clamp((l + 0.18 - t * 1.25) * 5.0, 0.0, 1.0);
			}
		}
		if (picture && edge > 0.0) {
			// THE HELD PICTURE'S OWN EDGE is eaten first, so a picture made small
			// never shows as a rectangle laid on the other
			vec2 lo = q - pic.xy;
			vec2 hi = pic.xy + pic.zw - q;
			float e = min(min(lo.x, lo.y), min(hi.x, hi.y)) / (0.5 * min(pic.z, pic.w));
			keep = min(keep, clamp((e - t * edge) * 6.0, 0.0, 1.0));
		}
		if (picture && soft > 0.5) {
			// and its own edge feathered, wider as it goes, so a held picture
			// made smaller never shows as a card laid on the other
			vec2 lo = q - pic.xy;
			vec2 hi = pic.xy + pic.zw - q;
			float ep = min(min(lo.x, lo.y), min(hi.x, hi.y)) * scl.x;
			if (t > 0.0) {
				keep *= clamp(ep / (140.0 * t), 0.0, 1.0);
			}
			COLOR = vec4(old_pic(q).rgb, smoothstep(0.0, 1.0, keep));
		} else if (picture && keep > thr) {
			COLOR = vec4(old_pic(q).rgb, 1.0);
		} else if (!in_hole && !in_rect(p, pic) && !picture && (1.0 - chrome_t) > thr) {
			COLOR = vec4(old_at(p).rgb, 1.0);
		} else {
			COLOR = vec4(0.0);
		}
	}
}
