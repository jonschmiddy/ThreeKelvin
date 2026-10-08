shader_type canvas_item;
render_mode unshaded, blend_disabled;

// ONE PALETTE FOR THE WHOLE VIEW (Jon: "kinda lost the pixel game aesthetic
// ... the stars, planets, starfield behind all need to have that same type of
// pixelated vibe"; then "even more pixelated"). Everything drawn so far -- the
// sky, the gas, the star's light, the belts, the shadows, the star -- is set to
// its nearest colour in the system's own short palette (`SystemPalette.gd`
// finds it from the system's own picture), and dithered in 2x2 cells with the
// next nearest only where it truly falls between two colours that are near
// each other and not both dark: a flat area stays flat, dark sky stays clean
// (a grid of near-blacks read as "a grid like pattern all over the whole
// background"), a gradient becomes steps with a pattern at each step.
//
// Drawn before the worlds and the lines, which keep their own colours.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec3 pal[72];
uniform int pal_n = 0;
uniform float x0 = 264.0;
// a cell of the dither is this many game pixels across
uniform int cell = 2;
// THE COLOUR READ WHOLE, not first cut to 32 steps a channel (round a pulsar).
// Its remnant shell grows with the map on every frame of a zoom, so most of the
// sky drifts by a fraction of a level a frame, and the layers over it (the dust
// sheets) drift their own way; each is stored to a whole level, so their sum
// wobbles by one level as it goes. Cut to steps of eight first, a wobble at a
// step's edge became a jump of eight, enough to tip its dither pixel and tip it
// back on the next frame (the pulsar's slow zoom: 0.0042 of the map flipping
// back a frame in SIMPLIFIED, 0.0046 in RADIANT, against the 0.0035 budget).
// Read whole, a one-level wobble moves the pair's mix by a sliver, which tips a
// pixel only where it already sat on its threshold. Same palette, same pairs;
// a dither pixel here and there lands differently at rest.
uniform bool fine = false;
// AND HELD (round a pulsar, with `fine`): `prev` is the place's picture last
// frame (`SystemView` copies it), and a pixel keeps the colour it had while that
// is still one of its pair and the light has not moved past the choice by a
// margin -- a dither pixel's threshold `hold_t` lower while it is lit and higher
// while not, the nearer of two near colours kept until the light is `hold_d`
// nearer the other. The pixels left sitting on a threshold (the ones a wobble
// still tipped) stop tipping back. Off (`hold_k` 0) everywhere else: nothing is
// held on the first frame or under a new palette, since what was there is not
// one of the pair, so a still is the stateless picture.
uniform sampler2D prev : filter_nearest, repeat_disable;
uniform float hold_k = 0.0;
uniform float hold_d = 3.0;
uniform float hold_t = 0.06;

const float BAYER4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 src = texture(screen, SCREEN_UV);
	vec2 px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	if (pal_n == 0 || px.x < x0) {
		COLOR = src;
	} else {
		vec3 c = fine ? src.rgb * 255.0 : floor(src.rgb * 255.0 / 8.0) * 8.226;
		int a = 0, s = 0;
		float ad = 1e9, sdd = 1e9;
		for (int k = 0; k < pal_n; k++) {
			vec3 p = pal[k] * 255.0, dv = c - p;
			float d = dv.r * dv.r * 2.0 + dv.g * dv.g * 4.0 + dv.b * dv.b * 3.0;
			if (d < ad) { s = a; sdd = ad; a = k; ad = d; } else if (d < sdd) { s = k; sdd = d; }
		}
		vec3 A = pal[a] * 255.0, S = pal[s] * 255.0, v = S - A;
		float vv = dot(v, v);
		float f = vv > 0.0 ? dot(c - A, v) / vv : 0.0;
		f = clamp(f, 0.0, 0.5);
		bool plain = vv < 26.0 * 26.0 || max(A.r, max(A.g, A.b)) + max(S.r, max(S.g, S.b)) < 90.0;
		ivec2 q = ivec2(px) / cell;
		float thr = (BAYER4[(q.y & 3) * 4 + (q.x & 3)] + 0.5) / 16.0;
		// THE PAIR IN ONE ORDER, whichever of the two is nearer (the lower palette
		// entry first): a colour drifting from one to the other across the midpoint
		// keeps every dither pixel it has already switched. Taken nearest-first,
		// the pattern turned inside out at the midpoint, and every pixel of a slow
		// fade went A, B, A, B -- a sky zoomed or lit by a moving sun shimmered
		// (the dark cloud's sheets: 0.0055 of its pixels flipping back a frame)
		float t = a < s ? f : 1.0 - f;
		vec3 lo = a < s ? A : S, hi = a < s ? S : A;
		vec3 o = plain ? A : (t > thr ? hi : lo);
		if (hold_k > 0.0) {
			vec3 was = texture(prev, SCREEN_UV).rgb * 255.0;
			bool wa = all(lessThan(abs(was - A), vec3(1.5))), ws = all(lessThan(abs(was - S), vec3(1.5)));
			if (plain) {
				// the nearer of two near colours: the one it had, until the light is
				// `hold_d` nearer the other
				vec3 da = c - A, ds = c - S;
				float ea = sqrt(da.r * da.r * 2.0 + da.g * da.g * 4.0 + da.b * da.b * 3.0);
				float es = sqrt(ds.r * ds.r * 2.0 + ds.g * ds.g * 4.0 + ds.b * ds.b * 3.0);
				if (ws && es < ea + hold_d * hold_k) o = S;
			} else if (wa || ws) {
				// a dither pixel: its threshold `hold_t` lower while it is lit, higher while not
				bool was_hi = all(lessThan(abs(was - hi), vec3(1.5)));
				o = (t > thr + (was_hi ? -hold_t : hold_t) * hold_k) ? hi : lo;
			}
		}
		COLOR = vec4(o / 255.0, 1.0);
	}
}
