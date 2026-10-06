shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE BLACK HOLE IN THE LEGACY CHART (`ChartLegacy`): SIMPLIFIED's hole
// (`legacy_hole.gdshaderinc`, its shape and perspective as drawn there) laid on
// the old chart's picture. One pass over the picture so far (the field and its
// stars, read back a block at a time; the field has already drawn what is
// behind the hole where the lens shows it): that is squeezed dark and a little
// cooler near the shadow and lit by the disc; the shadow is cut; the disc is
// laid over in its own bands, which
// the palette keeps (they are among every palette's colours), so they land as
// SIMPLIFIED's do. Alpha carries the field's flag on to the palette: a block of
// the disc or the shadow is a point (0.5, its nearest colour, never dithered).

#include "res://shaders/legacy_hole.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 vp_size = vec2(330.0, 220.0);
uniform vec2 vp_origin = vec2(-2.0);
// the hole's centre (the galaxy's), screen px, and its shadow's radius there
uniform vec2 cpix = vec2(327.0, 217.0);
uniform float shadow = 10.0;
uniform float t = 0.0;
// the infalling clumps (SIMPLIFIED fades them in from its zoom 2.6 to 4), the
// squeezed ring's cooling (its zoom 3 to 6), the hot spot on or off
uniform float clumps = 0.0;
uniform float cool_amt = 0.0;
uniform float hot_on = 1.0;

vec3 s2l(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 l2s(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec4 at(vec2 b) {
	ivec2 q = ivec2(clamp(b, vec2(0.0), vp_size - 1.0));
	return texelFetch(screen_tex, q, 0);
}

void fragment() {
	vec2 vp = floor(UV * vp_size);
	vec4 own = at(vp);
	COLOR = own;
	vec2 d = vp_origin + vp * 2.0 + 1.0 - cpix;
	vec2 S = lh_to_s(d, vec2(0.0), shadow);
	if (length(S) <= lh_dims.x * 0.97) {
		// what lies behind is already lensed: the field worked it out where the
		// lens shows it (`chart_l_field`'s `lens_shadow`)
		vec4 c = own;
		vec3 lin = s2l(c.rgb);
		lin *= lh_cool(S, cool_amt) * lh_squeeze(S);
		// the old bulge's bright nucleus, bent round the shadow, drew a broad
		// cream crescent under it: dimmed through the lensed ring, as
		// SIMPLIFIED's nest of dust hides its own
		lin *= mix(0.45, 1.0, smoothstep(1.4, 2.8, length(S) / LH_SHADOW));
		// the disc's light on what is round it
		lin += vec3(1.0, 0.55, 0.32) * 0.05 * lh_glow(S);
		float cap;
		vec4 dc = lh_disc(S, lh_px_rs(shadow), t, clumps, lh_hot(t, hot_on), cap);
		lin *= 1.0 - cap;
		float flag = c.a;
		if (dc.a > 0.004) {
			lin = mix(lin, dc.rgb, dc.a);
		}
		if (dc.a > 0.5 || cap > 0.5) {
			flag = 0.5;
		}
		COLOR = vec4(l2s(lin), flag);
	}
}
