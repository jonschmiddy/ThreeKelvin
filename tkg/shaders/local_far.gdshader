shader_type canvas_item;
render_mode unshaded, blend_disabled;

// LOCAL'S FAR SKY (`LocalSky`): what is behind the system seen side on, at
// infinity -- the distant galaxies and three depths of stars every chart style
// keeps (`chart_bg.gdshaderinc`), sliding on the LOCAL camera's moves each by
// its own depth (`u_skyPan`: the camera's travel in game px, never anything
// else); in a clear sky the system's own star's light round it, breathing, and
// the galaxy's band as a crowd of faint stars (the sector map's clear sky).
// Drawn in 2x2 blocks: one fragment a block, its centre in game px.
//
// LEGACY: LOCAL's sky as it was -- the view's wash, tinted toward the right by
// the system's star, and a plain starfield of greys -- with the far galaxies.

#include "res://shaders/chart_kit.gdshaderinc"
#include "res://shaders/chart_bg.gdshaderinc"

// the frame's centre in game px (the sky's own origin)
uniform vec2 centre = vec2(480.0, 270.0);
uniform vec3 void_lin = vec3(0.0018, 0.0022, 0.0042);
uniform float expo = 1.0;
uniform bool legacy = false;
// LEGACY's wash: the view's left edge and width (game px), its tint (sRGB), and
// the near stars' tint
uniform vec2 wash = vec2(8.0, 944.0);
uniform vec3 wash_tint = vec3(0.1, 0.06, 0.05);
uniform vec3 old_tint = vec3(0.96, 0.95, 0.89);
// stars at all (a thick cloud in front hides them anyway; it is drawn over this)
uniform float stars_seen = 1.0;
// A CLEAR SKY'S SUN: its light round it (linear colour, brightest channel 1),
// where it is (game px), how strong and how far, its breath
uniform vec3 star_light = vec3(1.0, 0.72, 0.36);
uniform vec2 star_at = vec2(480.0, 80.0);
uniform float glow_k = 0.0;
uniform float glow_r = 90.0;
uniform float breath = 1.0;
// THE GALAXY'S BAND, a crowd of faint stars along a line through the frame:
// its direction, its distance from the centre, its half width (px); 0: none
uniform vec2 band_n = vec2(0.2, 0.98);
uniform float band_off = 0.0;
uniform float band_w = 0.0;

void fragment() {
	vec2 g = (floor(SCREEN_UV * vec2(480.0, 270.0)) + 0.5) * 2.0;
	vec2 sp = g - centre;
	if (legacy) {
		// THE VIEW AS IT WAS (`EncounterView._draw`, `SpaceBackdrop._stars`): the
		// void, five bands of the star's tint stepping in from right of the
		// middle, plain grey stars and the near ones in the star's colour
		vec3 c = vec3(0.027, 0.039, 0.063);
		float fx = (g.x - wash.x) / max(wash.y, 1.0);
		// (its five steps dithered from one to the next in an ordered pattern, a
		// block at a time: hard-edged, the palette cut them to one step at 0.45 of
		// the view, and with the play's tone evening out everything below the top
		// band it stood as a dark rectangle in the top left corner)
		// ONE GENTLE RISE, NOT FIVE STEPS (Jon: "soften LEGACY's band" -- the
		// steps between came out of the palette's cut as a lighter band with a
		// stepped edge, here and on the field under the map and the chart): two
		// colours only, the void and the wash at its full five steps, each block
		// one or the other, as many of the wash as the rise asks for, in an
		// ordered pattern -- the palette keeps both whole, so the rise reads as a
		// dither across nearly half the view, never a line
		ivec2 blk = ivec2(floor(SCREEN_UV * vec2(480.0, 270.0)));
		float th = kitBayer4(blk);
		// (each block's share nudged by up to a step of the pattern, so where the
		// rise passes from one step of it to the next is no straight line down)
		float rise = smoothstep(0.26, 0.74, fx) + (kitHash1(blk + ivec2(17, 3)) - 0.5) / 16.0;
		if (rise > th) {
			c = mix(c, wash_tint, 1.0 - pow(0.9, 5.0));
		}
		vec4 gx = bgGalaxy(sp);
		vec3 warm = vec3(1.0, 0.78, 0.52), blue = vec3(0.55, 0.68, 1.0);
		c += kitToSrgb((warm * gx.x * 0.16 + mix(warm, blue, gx.z) * gx.y * 0.08) * gx.w * expo * 2.0);
		for (int l = 0; l < 3; l++) {
			vec4 s = bgStar(sp, l);
			if (s.x > 0.5 && stars_seen > 0.5) {
				c = l == 0 ? vec3(0.137, 0.176, 0.224) : (l == 1 ? vec3(0.302, 0.373, 0.451) : (s.w < 0.5 ? old_tint : vec3(0.624, 0.753, 0.878)));
			}
		}
		COLOR = vec4(c, 1.0);
	} else {
		vec3 c = void_lin + bgLight(sp, stars_seen) * expo;
		if (band_w > 0.0) {
			// (sliding with the mid stars' depth)
			vec2 q = sp - u_skyPan * 0.10;
			float d = dot(q, band_n) - band_off;
			float w = exp(-d * d / (band_w * band_w));
			float lump = 0.6 + 0.4 * kitFbm2(q / 260.0 + vec2(u_skySeed, 3.0), 3);
			vec4 s = kitStar(bgAt(sp, 0.10), 2.0, 6.0, 0.28 * w * lump, 97);
			if (s.x > 0.5) {
				c += kitStarTint(s.z) * (0.006 + 0.02 * s.y * s.y);
			}
			c += vec3(0.0016, 0.0016, 0.0024) * w * lump;
		}
		float gf = 0.0;
		if (glow_k > 0.0) {
			// (gone to nothing at its edge: a long faint tail was set by the palette
			// into flat plates of the star's darkest step)
			float r = length(g - star_at) / (glow_r * breath);
			float f = max(1.0 - r, 0.0);
			c += star_light * glow_k * f * f * 0.05;
			gf = glow_k * smoothstep(0.0, 0.2, f);
		}
		vec3 o = kitToSrgb(kitTone(c * 1.0, 3.0));
		if (gf > 0.0) {
			// THE GLOW'S STEPS DITHERED: the palette cut after this keeps its dark
			// steps flat, so the star's glow came out as three hard-edged plates
			// round it (a red star's most of all, read as a flat red disc). A step's
			// worth of ordered dither across it, in the star's own colour, lets the
			// palette fall from one plate to the next in a pattern (only in the glow:
			// the void round it stays clean)
			float th = kitBayer4(ivec2(floor(SCREEN_UV * vec2(480.0, 270.0))));
			o += (th - 0.5) * 0.045 * gf * (star_light / max(star_light.r, max(star_light.g, star_light.b)));
		}
		COLOR = vec4(o, 1.0);
	}
}
