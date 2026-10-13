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
// SOFT's narrowest feather, px on screen (0: from nothing, as `t` grows)
uniform float feather = 0.0;
// SOFT: where the held picture's focus object stood (screen px: centre, radius;
// 0 for none), kept out of its standing copy
uniform vec3 focus_hole = vec3(0.0);
// SOFT: the disc that carries the moving picture (Jon: "the circle is better....
// but it's still WAYYY too big"), screen px at the swap -- shrinking with a
// picture made smaller, never growing with one made bigger -- and the focus
// object's own radius in the held picture's px; the disc is never smaller than
// the object with a little rim, nor bigger than fits inside the frame
uniform float disc_r0 = 42.0;
uniform float focus_r = 0.0;
// SOFT: where the arriving screen draws the same thing the disc carries
// (screen px: centre, radius; 0 for none), covered by the held picture too
uniform vec3 cover = vec3(0.0);
// a hole in the held picture (its own px: centre, radius; 0 for none) where
// the live screen draws the same thing -- the world handed over in 2C
uniform vec3 hole = vec3(0.0);
// THE SIDE BAR'S RECT (screen px; z 0 for none), drawn by `SideSwap` from the
// swap on: the held picture leaves it alone
uniform vec4 side = vec4(0.0);

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
		// SOFT (1A, 2C): the whole held picture, its frame and what stood round
		// it carried as one, its design's keep measured everywhere in it
		// (the screens' own area only: the HUD above them is never carried)
		bool in_img = in_rect(q, vec4(rect_pos, rect_size));
		if (soft > 0.5 && in_img && !in_hole) {
			picture = true;
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
		if (soft > 0.5) {
			// NEVER A BOX (Jon: "The square is kinda weird and harsh"). Two
			// layers, neither with an edge of its own on screen:
			//  A, THE MOVING PICTURE, kept only inside a soft disc round the
			//    focus (your star, the world you orbit) no bigger than the
			//    largest circle that fits inside the picture's own frame where
			//    it is now -- so its frame, the panel's place beside it and the
			//    HUD are never carried into view;
			//  B, THE PICTURE AS IT WAS, standing exactly where it stood and
			//    fading out over the first stretch of the move -- so the swap's
			//    frame is the last one drawn, whole, and the corners go by fading,
			//    not by a straight edge sweeping across.
			vec2 lo = to_pt + (pic.xy - from_pt) * scl;
			vec2 hi = to_pt + (pic.xy + pic.zw - from_pt) * scl;
			float rfit = max(min(min(to_pt.x - lo.x, to_pt.y - lo.y), min(hi.x - to_pt.x, hi.y - to_pt.y)), 24.0);
			float aA = 0.0;
			if (picture) {
				float fobj = focus_r * scl.x;
				float R = min(max(disc_r0 * min(scl.x, 1.0), fobj * 1.2 + 4.0), rfit);
				// (solid over the object itself, the soft edge outside it)
				float inner = max(R * 0.5, min(fobj + 1.0, R - 3.0));
				float focus = 1.0 - smoothstep(inner, R, length(p - to_pt));
				if (cover.z > 0.0) {
					focus = max(focus, 1.0 - smoothstep(cover.z, cover.z + 3.0, length(p - cover.xy)));
				}
				aA = smoothstep(0.0, 1.0, keep) * focus;
			}
			bool hole_b = hole.z > 0.0 && length(p - hole.xy) < hole.z;
			float aB = hole_b ? 0.0 : 1.0 - smoothstep(0.0, 0.2, t);
			vec3 cA = old_pic(q).rgb;
			vec3 cB = old_at(p).rgb;
			// (and never the thing the move is about -- the world you orbit, your
			// star -- where it stood: A carries it, and a second one left behind
			// read as two worlds. Its place in the standing copy is filled with
			// the sky round it, the average of a ring just outside it, so neither
			// it nor the screen arriving shows through there)
			if (focus_hole.z > 0.0 && length(p - focus_hole.xy) < focus_hole.z + 3.0) {
				vec3 ring = vec3(0.0);
				for (int i = 0; i < 12; i++) {
					float an = float(i) * 0.5236;
					ring += old_at(focus_hole.xy + vec2(cos(an), sin(an)) * (focus_hole.z + 6.0)).rgb;
				}
				float m = smoothstep(focus_hole.z + 3.0, focus_hole.z - 1.0, length(p - focus_hole.xy));
				cB = mix(cB, ring / 12.0, m);
			}
			float a = aA + aB * (1.0 - aA);
			COLOR = a > 0.0 ? vec4((cA * aA + cB * aB * (1.0 - aA)) / a, a) : vec4(0.0);
		} else if (picture && keep > thr) {
			COLOR = vec4(old_pic(q).rgb, 1.0);
		} else if (!in_hole && !in_rect(p, pic) && !picture && soft > 0.5) {
			// (round the picture, where the old screen's UI stood -- gone before
			// the move, `ZoomLadder.ladder_chrome` -- an even fade, not a checker)
			COLOR = vec4(old_at(p).rgb, 1.0 - smoothstep(0.0, 1.0, chrome_t));
		} else if (!in_hole && !in_rect(p, pic) && !picture && (1.0 - chrome_t) > thr) {
			COLOR = vec4(old_at(p).rgb, 1.0);
		} else {
			COLOR = vec4(0.0);
		}
	}
	if (side.z > 0.0 && in_rect(rect_pos + UV * rect_size, side)) {
		COLOR = vec4(0.0);
	}
}
