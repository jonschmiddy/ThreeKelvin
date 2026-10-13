shader_type canvas_item;

// THE SIDE BAR'S SWAP (`SideSwap`): drawn over the side bar's rect for the
// second half of a move, from the held picture's copy of the panel being left
// (`old_tex`, the whole 960x540 frame the move began its handoff on) to the
// panel arriving, which stands live and whole underneath (`screen_tex`). The
// held picture (`zoom_ladder.gdshader`) leaves this rect alone, so what is
// under it here is the arriving screen and nothing else.
//
// Every edge is on whole pixels and every flicker steps at the game's own 30
// or 60 a second, the vocabulary of the station screens' bad signal (2 px
// rows, bands that slip in 2 px steps, lines of snow).
//
// LOOKS (`look`):
//   0 A CROSSFADE  the old fades as the new comes up, in place
//   1 B SLIDE      the old slides out and the new in, up zooming in, down out
//   2 C CASCADE    the frame stays; its sections cross over top to bottom
//   3 D SCAN       a bright line redraws it top to bottom, a phosphor glow
//                  fading behind it; the old stays below the line
//   4 E DECODE     the frame and layout at once; every line of text scrambles
//                  and resolves left to right, icons pop in on a flicker
//   5 F REBOOT     signal lost for three frames, then the rows print one by
//                  one behind a cursor

uniform sampler2D old_tex : filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 vp = vec2(960.0, 540.0);
// this rect, the old panel's and the new one's (viewport px; z = 0 for none)
uniform vec4 rect = vec4(0.0);
uniform vec4 old_r = vec4(0.0);
uniform vec4 new_r = vec4(0.0);
uniform int look = 0;
// seconds since the swap began, and the look's own progress 0..1
uniform float secs = 0.0;
uniform float u = 0.0;
// +1 zooming in (content goes up), -1 out
uniform float dir = 1.0;
// D: where the line is (viewport y)
uniform float line_y = 0.0;
// F: how long the signal is lost
uniform float lost_s = 0.05;
// rows of text or icons (x, y, w, h) and their times (start, end, kind 0 text
// 1 icon, 0); C's sections (top, start, end, 0)
uniform vec4 rows[64];
uniform vec4 rowt[64];
uniform int nrows = 0;
uniform vec4 secs_y[16];
uniform int nsecs = 0;
// E and F: the glyph cell (px)
uniform vec2 cell = vec2(6.0, 8.0);
uniform vec3 ice = vec3(0.765, 0.824, 0.886);
uniform vec3 line_col = vec3(0.133, 0.188, 0.247);
uniform vec3 cold = vec3(0.420, 0.490, 0.580);
uniform vec3 chill = vec3(0.561, 0.639, 0.729);
// where there was no old panel: the screen's own bare ground (VOID)
uniform vec3 ground = vec3(0.039, 0.055, 0.082);
// and how much of the held picture's standing copy is still drawn (it fades as
// the rest of it does, `ZoomLadder.held_alpha`)
uniform float held_a = 0.0;
// E: how many times a second a scrambled glyph turns over (Jon: "happen slowly
// and not so fast" -- at 30 it was a blur, at 13 each character can be seen
// turning over)
uniform float glyph_hz = 13.0;
// E on the HUD's tabs: what is not yet resolved is the OLD picture -- its
// highlight -- with its letters scrambled, so the highlight hands over to the
// new one as the line resolves (`SideSwap.setup_tabs`)
uniform int hand = 0;

bool inr(vec2 q, vec4 r) {
	return r.z > 0.0 && q.x >= r.x && q.y >= r.y && q.x < r.x + r.z && q.y < r.y + r.w;
}

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 newc(vec2 q) {
	return texture(screen_tex, (floor(q) + 0.5) / vp).rgb;
}

vec3 oldc(vec2 q) {
	return texture(old_tex, (floor(q) + 0.5) / vp).rgb;
}

// a panel's own ground at row y: its left padding (3 px in from its edge)
vec3 bg_new(float y) {
	return newc(vec2(new_r.x + 3.0, y));
}

vec3 bg_old(float y) {
	return oldc(vec2(old_r.x + 3.0, y));
}

// whether a glyph cell `h` tall holds any ink (differs from the ground beside it)
bool ink(vec2 c0, float h, bool from_new, vec3 g) {
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 3; i++) {
			vec2 q = c0 + vec2((float(i) + 0.5) * cell.x / 3.0, (float(j) + 0.5) * h / 4.0);
			vec3 c = from_new ? newc(q) : oldc(q);
			if (distance(c, g) > 0.08) {
				return true;
			}
		}
	}
	return false;
}

// a scrambled glyph: the cell at p shows another cell of the same row, a new
// one `glyph_hz` times a second
vec3 scramble(vec2 p, vec4 r, int i, bool from_new) {
	float n = max(floor(r.z / cell.x), 1.0);
	float ci = floor((p.x - r.x) / cell.x);
	float step = floor(secs * glyph_hz);
	float pick = floor(hash(vec2(ci + float(i) * 17.0, step)) * n);
	vec2 q = vec2(r.x + pick * cell.x + mod(p.x - r.x, cell.x), p.y);
	return from_new ? newc(q) : oldc(q);
}

// STATIC, in the panel's own palette: its ground with 2x2 cells of line colour
// and a few cold ones, a snow line or two, the old picture dim through it
vec3 lost(vec2 p, vec3 gr, vec3 under) {
	vec2 c2 = floor(p / 2.0);
	float f = floor(secs * 60.0);
	float v = hash(c2 + vec2(f * 7.1, f * 3.3));
	vec3 col = mix(gr, under, 0.3);
	col = mix(col, line_col, step(0.5, v) * 0.8);
	col = mix(col, cold, step(0.9, v) * 0.6);
	// snow: two rows of bright cells
	for (int s = 0; s < 2; s++) {
		float ly = rect.y + floor(hash(vec2(f, float(s) * 9.1)) * rect.w / 2.0) * 2.0;
		if (p.y >= ly && p.y < ly + 2.0 && hash(c2 + vec2(f, 3.0)) > 0.45) {
			col = chill;
		}
	}
	return col;
}

void fragment() {
	vec2 p = rect.xy + floor(UV * rect.zw);
	bool hn = new_r.z > 0.0;
	bool ho = old_r.z > 0.0;
	vec3 O = ho ? oldc(p) : mix(ground, oldc(p), held_a);
	vec3 N = newc(p);
	vec3 col = N;
	if (look == 0) {
		float e = smoothstep(0.0, 1.0, u);
		col = mix(O, N, e);
	} else if (look == 1) {
		float e = u * u * u * (u * (u * 6.0 - 15.0) + 10.0);
		float H = rect.w;
		float off = floor(e * H + 0.5);
		vec2 qo = vec2(p.x, p.y + dir * off);
		vec2 qn = vec2(p.x, p.y - dir * (H - off));
		if (ho && hn) {
			col = inr(qo, rect) ? oldc(qo) : newc(qn);
		} else if (ho) {
			// (the old slides away over the live picture arriving)
			col = inr(qo, old_r) ? oldc(qo) : N;
		} else {
			// (the new slides in over the picture that was there)
			col = (inr(qn, new_r) && inr(p, new_r)) ? newc(qn) : O;
		}
	} else if (look == 2) {
		int k = 0;
		for (int i = 0; i < 16; i++) {
			if (i < nsecs && p.y >= secs_y[i].x) {
				k = i;
			}
		}
		vec4 s = secs_y[k];
		float e = smoothstep(s.y, s.z, secs);
		col = mix(O, N, e);
	} else if (look == 3) {
		float g = line_y - p.y;
		if (g > 2.0) {
			// drawn: the phosphor's glow on the rows just behind the line
			float glow = exp(-(g - 2.0) / 9.0) * 0.28;
			col = N + (ice * 0.6 + N * 0.4) * glow;
		} else if (g > 0.0) {
			col = mix(N, ice, 0.8);
		} else {
			col = O;
		}
	} else if (look == 4) {
		bool from_new = hn;
		col = N;
		for (int i = 0; i < 64; i++) {
			if (i >= nrows) {
				break;
			}
			vec4 r = rows[i];
			if (!inr(p, r)) {
				continue;
			}
			vec4 tt = rowt[i];
			if (hand == 1) {
				float fh = r.x + floor(clamp((secs - tt.x) / max(tt.y - tt.x, 0.001), 0.0, 1.0) * r.z / cell.x) * cell.x;
				if (p.x >= fh) {
					col = O;
					float in0 = r.x + 4.0;
					float w = max(r.z - 8.0, cell.x);
					if (p.x >= in0 && p.x < in0 + w) {
						vec2 c0 = vec2(in0 + floor((p.x - in0) / cell.x) * cell.x, r.y);
						if (ink(c0, r.w, false, oldc(vec2(in0, p.y)))) {
							col = scramble(p, vec4(in0, r.y, w, r.w), i, false);
						}
					}
				}
			} else if (tt.z > 0.5 && from_new) {
				// an icon: hidden, then on, off, on a frame each
				float a = secs - tt.x;
				vec3 g = bg_new(p.y);
				col = (a < 0.0 || (a >= 1.0 / 60.0 && a < 2.0 / 60.0)) ? g : N;
			} else {
				float fr = r.x + floor(clamp((secs - tt.x) / max(tt.y - tt.x, 0.001), 0.0, 1.0) * r.z / cell.x) * cell.x;
				if (p.x >= fr) {
					vec2 c0 = vec2(r.x + floor((p.x - r.x) / cell.x) * cell.x, r.y);
					vec3 g = from_new ? bg_new(p.y) : bg_old(p.y);
					if (ink(c0, r.w, from_new, g)) {
						col = scramble(p, r, i, from_new);
					} else {
						col = N;
					}
				}
			}
			break;
		}
	} else {
		if (secs < lost_s) {
			vec3 g = hn ? bg_new(p.y) : (ho ? bg_old(p.y) : O);
			col = lost(p, g, O);
		} else if (hn) {
			for (int i = 0; i < 64; i++) {
				if (i >= nrows) {
					break;
				}
				vec4 r = rows[i];
				if (!inr(p, r)) {
					continue;
				}
				vec4 tt = rowt[i];
				if (tt.z > 0.5) {
					// (pictures are up with the frame; the text prints)
					break;
				}
				float fr = r.x + floor(clamp((secs - tt.x) / max(tt.y - tt.x, 0.001), 0.0, 1.0) * r.z / cell.x) * cell.x;
				col = p.x < fr ? N : bg_new(p.y);
				// the cursor: a block at the write head of the row being
				// written, blinking (a 30th of a second off in every 10th)
				bool typing = secs >= tt.x && secs < tt.y;
				bool on = typing && fract(secs * 10.0) < 0.67;
				if (on && p.x >= fr && p.x < fr + cell.x - 1.0) {
					col = ice;
				}
				break;
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
