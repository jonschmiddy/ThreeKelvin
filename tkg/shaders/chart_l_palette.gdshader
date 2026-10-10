shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE GALAXY'S OWN SHORT PALETTE (`ChartSky`), the sector map's rule
// (`map_palette.gdshader`): every block set to its nearest colour, and a
// block of the field dithered with the next nearest only where it truly falls
// between two colours that are near each other and not both dark, in a 4x4
// pattern anchored to the galaxy so it moves with it. Points -- stars, the
// sky behind, the hole -- take their nearest colour and are never dithered.
// The nearest pair for every colour is looked up (`lut`, made once per
// palette by `chart_palette_lut.gdshader`) rather than searched for here.

#include "res://shaders/chart_l_galaxy.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D lut : filter_nearest;
uniform sampler2D pal : filter_nearest;
// the next zoom level's palette, and how far toward it (`ChartSky`): between
// two levels each block goes over to the next one's colours at its own fixed
// point of the zoom, so a level's change is a slow dissolve, not every
// block of the gas recoloured at once ("these stars and gas ... the same at
// every magnification", Jon)
uniform sampler2D lut2 : filter_nearest;
uniform sampler2D pal2 : filter_nearest;
uniform float pal_mix = 0.0;
uniform bool has_pal = false;
uniform vec2 vp_size = vec2(330.0, 220.0);
// this viewport's first block, counted from the galaxy's centre
uniform vec2 block0 = vec2(0.0);
// how strict the dither's gates are (`ChartLegacy`): none at the opening view,
// where a zoom moves the picture little; in full from zoom 0.7
uniform float aa_k = 1.0;
// THE COLOUR HELD (Oct 10 polish; SIMPLIFIED's composite, `chart_c_comp`): the
// picture last frame (`ChartLegacy._hvp`). A block of the field keeps the colour
// it had while its light is still nearly as close to that colour as to the one
// it would now take (`hyst`, sRGB), so a gradient or a grain sliding under the
// blocks as the zoom moves no longer flips a block between two neighbouring
// colours and back -- this chart flickered most of the four on a slow zoom.
// `hyst` 0 holds nothing. What is held moves with the picture: a block is
// compared with the block that drew its piece of the galaxy last frame, through
// last frame's view (`prev_c`, `prev_o`, `prev_k`), within the two limits below --
// see `chart_c_comp` (held to the same place on the screen, colours trailed
// behind a zoom: 8.4% of the pixels a frame on the 8 s zoom into the arms).
uniform sampler2D prev_tex : filter_nearest;
uniform vec2 cur_c = vec2(0.0);
uniform vec2 cur_o = vec2(0.0);
uniform vec2 prev_c = vec2(0.0);
uniform vec2 prev_o = vec2(0.0);
uniform float prev_k = 1.0;
uniform float hyst = 0.0;
// how far (blocks) a piece of the galaxy may have moved since last frame and keep
// its colour: faster than that the zoom is changing it anyway, and a held colour
// only lags
const float MOVE_MAX = 1.0;
// and how far behind its light a held colour may lag, as a share of the local
// slope (a block's worth of change): on a shallow gradient a fixed band let a
// colour boundary trail many blocks behind the light that drew it
const float LAG_MAX = 0.5;

void fragment() {
	vec4 s = texture(screen_tex, SCREEN_UV);
	if (!has_pal) {
		COLOR = vec4(s.rgb, 1.0);
	} else {
		ivec3 q = ivec3(clamp(floor(s.rgb * 255.0 + 0.5), 0.0, 255.0)) >> ivec3(3);
		int key = (q.r << 10) | (q.g << 5) | q.b;
		ivec2 bk = ivec2(floor(UV * vp_size) + block0);
		bool second = pal_mix > 0.0 && g_hash(bk.x * 7 + 3, bk.y * 13 - 5) < pal_mix;
		vec4 e = second ? texelFetch(lut2, ivec2(key % 256, key / 256), 0) : texelFetch(lut, ivec2(key % 256, key / 256), 0);
		int a = int(floor(e.r * 255.0 + 0.5));
		int sx = int(floor(e.g * 255.0 + 0.5));
		float fq = floor(e.b * 255.0 + 0.5) / 32.0;
		float rawf = floor(e.a * 255.0 + 0.5) / 63.0;
		int ci = a;
		// DITHERED ONLY ON A SMOOTH SLOPE (the zoom's flicker): a block in
		// texture -- dark haze, an arm's filaments -- takes its nearest colour,
		// as the slope's own grain is texture enough; dithered, the texture
		// sliding under the pattern as the zoom moved flipped blocks back and
		// forth. Nor in the dark, where the palette's faint steps lie close.
		float lc = g_lum(s.rgb) * 255.0;
		vec2 px = 1.0 / vp_size;
		float tex = max(max(abs(g_lum(texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb) * 255.0 - lc),
			abs(g_lum(texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb) * 255.0 - lc)),
			max(abs(g_lum(texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb) * 255.0 - lc),
			abs(g_lum(texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb) * 255.0 - lc)));
		if (s.a > 0.6 && lc > 64.0 * aa_k && tex < mix(999.0, 9.0, aa_k)) {
			ivec2 b = ivec2(floor(UV * vp_size) + block0);
			float dv = fq > 0.0 ? fq - (g_bayer(b) + 0.5) / 16.0 : rawf - 0.5;
			ci = (dv > 0.0 && fq > 0.0) ? sx : a;
		}
		vec3 outc = (second ? texelFetch(pal2, ivec2(ci, 0), 0) : texelFetch(pal, ivec2(ci, 0), 0)).rgb;
		if (hyst > 0.0 && s.a > 0.6) {
			vec2 q = (prev_c + (cur_o + (floor(UV * vp_size) + 0.5) * 2.0 - cur_c) * prev_k - prev_o) * 0.5;
			ivec2 pb = ivec2(floor(q));
			if (length(q - floor(UV * vp_size) - 0.5) < MOVE_MAX && pb.x >= 0 && pb.y >= 0 && pb.x < int(vp_size.x) && pb.y < int(vp_size.y)) {
				vec3 was = texelFetch(prev_tex, pb, 0).rgb;
				// held only if it is a colour this light could take (its nearest or its
				// partner), never another palette's or a star's
				vec3 cA = (second ? texelFetch(pal2, ivec2(a, 0), 0) : texelFetch(pal, ivec2(a, 0), 0)).rgb;
				vec3 cB = (second ? texelFetch(pal2, ivec2(sx, 0), 0) : texelFetch(pal, ivec2(sx, 0), 0)).rgb;
				bool ok = length(was - cA) < 0.004 || length(was - cB) < 0.004;
				if (ok && length(was - outc) > 1e-3 && length(s.rgb - was) < length(s.rgb - outc) + min(hyst, LAG_MAX * tex / 255.0)) {
					outc = was;
				}
			}
		}
		COLOR = vec4(outc, 1.0);
	}
}
