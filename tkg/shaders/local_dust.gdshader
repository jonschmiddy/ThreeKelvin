shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// LOCAL'S FOREGROUND DUST (`LocalDust`), one quad a mote (a MultiMesh), drawn
// per GAME PIXEL whatever the dust's own scale: under the cutaway's push-in
// and the zoom ladder the dust is not a picture scaled up -- each mote is drawn
// again at its zoomed size, so zooming in only ever adds detail (a speck grows
// a falloff, a mote a soft rim) and never turns a pixel into a block.
//
// Every pattern is anchored to its own mote (its dither, its grains), so a mote
// that moves a pixel moves whole, the same pixels lit; a mote's visibility
// (`vis`, eased on the CPU) thins or fills it a step at a time, never on or off.
// LIGHT, NOT PAINT: a mote adds its light to what is behind it (premultiplied,
// no cover), so it reads as gathered light over dark sky and bright gas alike.
// Nothing is drawn inside a ship's picture, a label or a gauge (`keep`).
//
// THE KINDS (`INSTANCE_CUSTOM.y`):
//   0 MOTE      gathered light: a core, its light falling off in dithered steps,
//               brighter on the side toward the star; now and then it turns and
//               GLINTS -- its core flares and a short cross of light grows from it
//   1 BOKEH     a near mote far out of focus: a faint smooth disc, its rim lit on
//               the star's side, its edge dithered out
//   2 SPECK     a far mote: a pixel, a faint cross round it when it is bright
//   3 FILAMENT  a thread of dust: fine grains along a slow curve, a faint body
//               between them, thickest in its middle, lit toward the star
//   4 CLUMP     a drifting knot of grains round a faint glow
// Per instance: CUSTOM (R: radius, or a filament's half length; kind; seed; the
// angle toward the star), COLOR (its light; its glint, or a filament's half
// height; its visibility; the quad's half size in px).

#include "res://shaders/local_dust_kit.gdshaderinc"

uniform int style = 0; // 0 simplified, 1 painted, 2 radiant, 3 legacy
// the light a mote gathers: its body's colour, and its core's (the star's)
uniform vec3 glow = vec3(0.3, 0.27, 0.24);
uniform vec3 core_col = vec3(0.42, 0.40, 0.36);
// what it must keep clear of, in game px (the game's own frame)
uniform vec4 keep[40];
uniform int n_keep = 0;
uniform vec2 view_px = vec2(960.0, 540.0);

varying vec4 v_cus;
varying vec4 v_col;

void vertex() {
	v_cus = INSTANCE_CUSTOM;
	v_col = COLOR;
}

void fragment() {
	vec2 g = SCREEN_UV * view_px;
	for (int k = 0; k < 40; k++) {
		if (k >= n_keep) {
			break;
		}
		vec4 r = keep[k];
		if (g.x >= r.x && g.y >= r.y && g.x < r.x + r.z && g.y < r.y + r.w) {
			discard;
		}
	}
	int kind = int(v_cus.y + 0.5);
	float R = v_cus.x;
	float seed = v_cus.z;
	vec2 to_star = vec2(cos(v_cus.w), sin(v_cus.w));
	float inten = v_col.x;
	float vis = v_col.z;
	float h = v_col.w;
	// (the quad's half size, as `LocalDust._ext` made it)
	vec2 ext = kind == 3 ? vec2(ceil(R) + 2.0, ceil(v_col.y) + 2.0) : vec2(h);
	// this pixel's whole offset from the mote's middle
	vec2 d = floor(UV * (2.0 * ext + 1.0)) - ext;
	ivec2 rel = ivec2(d) + ivec2(int(seed * 37.0), int(seed * 91.0));
	float th = dust_bayer4(rel);
	vec2 res = dust_pixel(kind, d, R, seed, to_star, inten, v_col.y, vis, th, style);
	if (res.x <= 0.0) {
		discard;
	}
	// its body's colour, its brightest steps toward the star's light
	vec3 c = mix(glow, core_col, clamp(res.y, 0.0, 1.0));
	COLOR = vec4(c * res.x, 0.0);
}
