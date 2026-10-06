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
		COLOR = vec4((second ? texelFetch(pal2, ivec2(ci, 0), 0) : texelFetch(pal, ivec2(ci, 0), 0)).rgb, 1.0);
	}
}
